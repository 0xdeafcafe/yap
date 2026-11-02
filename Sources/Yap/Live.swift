import Darwin
import Foundation

/// ~/.config/yap/live.sock: what yap hears, as it hears it, one JSON line per change, so an app can show the
/// dictation where it'll land (rush draws it in its message box). Only your user can connect, and nothing's kept.
///
///     {"phase":"listening","settled":"words it's sure of","guessing":"and still guessing","level":42,
///      "locked":false,"app":"com.mitchellh.ghostty"}
///
/// phase is hidden, listening, finishing, done or failed; level is how loud you are, 0 to 100. done carries the text in settled and is sent just
/// before the paste, so whoever's listening knows the paste that follows is the dictation's.
///
/// A client can send yap the words it's showing, so yap hears them and fixes near misses, on connect and whenever they change:
///
///     {"context":{"app":"com.mitchellh.ghostty","words":["Redis","rushd","LangWatch"]}}
///
/// app is the bundle id of the terminal it runs in, or "" if it doesn't know; up to 200 words. yap keeps the latest per
/// connection and forgets it when the connection closes.
///
/// A client that puts a finished dictation in its own box adds "takes":true to its context, and answers each done with
/// the done's text: `{"took":"…"}` if it put it in, `{"left":"…"}` if not. While a client for the app takes them, yap
/// waits a moment after done for the answers and doesn't paste what one took, so the text never lands twice.
///
/// A client that's in front with a box taking the dictation, and shows it there itself, adds "shows":true while
/// that's so. When you start a dictation with its app in front, yap shows nothing of its own (no panel, no
/// "Pasted"), still hears, tidies, sends the dictation here and keeps it in its history; it pastes only if no
/// client took it. If that client goes mid-dictation, yap shows its own again.
///
/// After you stop a dictation (esc), lines say "cancelled":true until the next one starts.
/// Anything else, and any line over 64 KiB, is ignored.
@MainActor final class Live {
    static let shared = Live()
    nonisolated static let path = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/yap/live.sock").path

    private var listener: Int32 = -1
    private var source: DispatchSourceRead?
    /// One connection. Its read buffer is only touched on `readQueue`; everything else on the main thread.
    private final class Peer: @unchecked Sendable {
        let fd: Int32
        var source: DispatchSourceRead?
        var buffer = Data()
        var skipping = false // in a line that's too long, until its newline
        var ended = false
        init(_ fd: Int32) { self.fd = fd }
    }
    private var clients: [Peer] = []
    private var contexts: [ObjectIdentifier: Context.Client] = [:]
    /// The answers to the latest done, per connection.
    private var answers: [ObjectIdentifier: Context.Answer] = [:]
    nonisolated private static let readQueue = DispatchQueue(label: "red.forbes.yap.live.read")
    private var current: (() -> Data)?
    private var pending: Task<Void, Never>?
    /// Called when a client goes.
    var onDrop: (() -> Void)?
    private var sentAt = Date.distantPast

    /// Serves the socket, unless another yap already is (a --demo next to the real one).
    func start() {
        guard listener < 0, !Self.serving() else { return }
        try? FileManager.default.createDirectory(atPath: (Self.path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        unlink(Self.path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        guard var addr = Self.address() else { close(fd); return }
        let old = umask(0o077) // the socket's never open to anyone else, not even between bind and chmod
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        umask(old)
        guard bound == 0, listen(fd, 8) == 0 else { close(fd); return }
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        listener = fd
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        src.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.accept() } }
        src.resume()
        source = src
    }

    func stop() {
        guard listener >= 0 else { return }
        source?.cancel(); source = nil
        clients.forEach(drop)
        close(listener); listener = -1
        unlink(Self.path)
    }

    /// Sends d's state on every change, at most 30 times a second.
    func follow(_ d: Dictation) {
        followed = d
        current = { [weak d] in d?.liveLine ?? Data() }
        track()
    }

    private weak var followed: Dictation?
    private var tracking = false

    /// Watches the dictation only while someone's connected. Your voice's level changes ~50 times a second, and
    /// with no one to tell, each change would only be turned into JSON for nothing.
    private func track() {
        guard let d = followed, !clients.isEmpty, !tracking else { return }
        tracking = true
        withObservationTracking { _ = d.liveLine } onChange: {
            Task { @MainActor in
                self.tracking = false
                self.publish()
                self.track()
            }
        }
    }

    /// Says where the dictation is. now skips the wait, for the moment before a paste.
    func publish(now: Bool = false) {
        guard !clients.isEmpty else { return }
        if now {
            pending?.cancel(); pending = nil
            return flush()
        }
        guard pending == nil else { return }
        let wait = max(0, 1.0 / 30 - Date().timeIntervalSince(sentAt))
        pending = Task {
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            pending = nil
            flush()
        }
    }

    private func flush() {
        guard let line = current?(), !line.isEmpty else { return }
        sentAt = Date()
        for c in clients where !Self.send(c.fd, line) { drop(c) }
    }

    /// Every word apps have sent, whatever app they're for, for Settings to show.
    var allWords: [String] {
        var seen = Set<String>()
        return clients.compactMap { contexts[ObjectIdentifier($0)] }.flatMap(\.words).filter { seen.insert($0).inserted }
    }

    /// The words clients sent for `app`, the one a dictation will paste into, or for no app in particular.
    func words(for app: String) -> [String] {
        clients.compactMap { contexts[ObjectIdentifier($0)] }.filter { $0.app == app || $0.app.isEmpty }.flatMap(\.words)
    }

    /// Whether `app`, the one in front, shows the dictation itself: what a connected client last said, no waiting.
    func showsItself(app: String) -> Bool {
        Context.showsItself(front: app, clients: clients.compactMap { contexts[ObjectIdentifier($0)] })
    }

    /// Whether a client took the done just published with `text`, for `app`: waits up to `limit` for every client
    /// that takes dictations for app to answer. false at once when none does. Call right after publish(now: true).
    func taken(_ text: String, app: String, limit: Duration = .milliseconds(300)) async -> Bool {
        answers = [:]
        let want = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = ContinuousClock.now + limit
        while true {
            let takers = clients.map { ObjectIdentifier($0) }.filter {
                guard let c = contexts[$0] else { return false }
                return c.takes && (c.app == app || c.app.isEmpty)
            }
            if takers.isEmpty { return false }
            let said = takers.compactMap { answers[$0] }.filter { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == want }
            if said.contains(where: \.took) { return true }
            if said.count == takers.count || ContinuousClock.now >= end { return false }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    /// Closes a connection and forgets what it said. The fd is closed once its reader has stopped.
    private func drop(_ c: Peer) {
        guard let i = clients.firstIndex(where: { $0 === c }) else { return }
        clients.remove(at: i)
        contexts[ObjectIdentifier(c)] = nil
        answers[ObjectIdentifier(c)] = nil
        c.source?.cancel()
        onDrop?()
    }

    /// A reader for one connection on `readQueue`, handing what it finds to the main thread. Cancelling it closes the fd.
    nonisolated private static func reader(_ c: Peer, deliver: @escaping @MainActor ([Context.Client], [Context.Answer], Bool) -> Void) -> DispatchSourceRead {
        let src = DispatchSource.makeReadSource(fileDescriptor: c.fd, queue: readQueue)
        let fd = c.fd
        src.setEventHandler {
            let (found, answered, closed) = drain(c)
            guard !found.isEmpty || !answered.isEmpty || closed else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { deliver(found, answered, closed) } }
        }
        src.setCancelHandler { close(fd) }
        return src
    }

    /// Reads what a client sent, off the main thread: each whole line that's a context or an answer goes to the main thread.
    nonisolated private static func drain(_ c: Peer) -> (contexts: [Context.Client], answers: [Context.Answer], closed: Bool) {
        guard !c.ended else { return ([], [], false) }
        var found: [Context.Client] = [], answered: [Context.Answer] = [], closed = false
        var chunk = [UInt8](repeating: 0, count: 16 * 1024)
        while true {
            let n = chunk.withUnsafeMutableBytes { Darwin.read(c.fd, $0.baseAddress, $0.count) }
            if n == 0 || (n < 0 && errno != EAGAIN && errno != EINTR) { closed = true; break }
            if n < 0 { if errno == EINTR { continue }; break }
            c.buffer.append(contentsOf: chunk[0..<n])
            while let nl = c.buffer.firstIndex(of: 0x0A) {
                let line = c.buffer[c.buffer.startIndex..<nl]
                if !c.skipping, let ctx = Context.parseLine(Data(line)) { found.append(ctx) }
                else if !c.skipping, let a = Context.parseAnswer(Data(line)) { answered.append(a) }
                c.skipping = false
                c.buffer.removeSubrange(c.buffer.startIndex...nl)
            }
            if c.buffer.count > Context.maxLineBytes { c.buffer.removeAll(); c.skipping = true }
        }
        if closed { c.ended = true; c.buffer.removeAll() }
        return (found, answered, closed)
    }

    private func accept() {
        while true {
            let c = Darwin.accept(listener, nil, nil)
            guard c >= 0 else { return }
            var uid = uid_t(), gid = gid_t()
            guard getpeereid(c, &uid, &gid) == 0, uid == getuid() else { close(c); continue }
            var on: Int32 = 1
            setsockopt(c, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
            _ = fcntl(c, F_SETFL, O_NONBLOCK)
            // Someone who connects mid-dictation catches up at once.
            if let line = current?(), !line.isEmpty, !Self.send(c, line) { close(c); continue }
            let peer = Peer(c)
            let src = Self.reader(peer) { [weak self] found, answered, closed in
                guard let self, self.clients.contains(where: { $0 === peer }) else { return }
                if let last = found.last { self.contexts[ObjectIdentifier(peer)] = last }
                if let last = answered.last { self.answers[ObjectIdentifier(peer)] = last }
                if closed { self.drop(peer) }
            }
            peer.source = src
            clients.append(peer)
            src.resume()
            track()
        }
    }

    /// A whole line or nothing: a reader that's fallen a line behind is dropped, and can connect again.
    private static func send(_ c: Int32, _ d: Data) -> Bool {
        d.withUnsafeBytes { Darwin.write(c, $0.baseAddress, d.count) } == d.count
    }

    private static func address() -> sockaddr_un? {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &addr.sun_path) { $0.copyBytes(from: bytes) }
        return addr
    }

    /// Whether another yap answers on the socket.
    private static func serving() -> Bool {
        guard var addr = address() else { return false }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        } == 0
    }
}

extension Dictation {
    /// The state Live sends, as one line.
    var liveLine: Data {
        let name: String = switch phase {
        case .hidden: "hidden"
        case .listening: "listening"
        case .finishing: "finishing"
        case .done: "done"
        case .failed: "failed"
        }
        var e: [String: Any] = ["phase": name, "settled": settled, "guessing": guessing,
                                "level": Int((level * 100).rounded()), "locked": locked, "app": frontApp]
        if stopped { e["cancelled"] = true }
        guard var d = try? JSONSerialization.data(withJSONObject: e, options: [.sortedKeys]) else { return Data() }
        d.append(0x0A)
        return d
    }

}
