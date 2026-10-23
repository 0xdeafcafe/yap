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
@MainActor final class Live {
    static let shared = Live()
    nonisolated static let path = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/yap/live.sock").path

    private var listener: Int32 = -1
    private var source: DispatchSourceRead?
    private var clients: [Int32] = []
    private var current: (() -> Data)?
    private var pending: Task<Void, Never>?
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
        clients.forEach { close($0) }; clients = []
        close(listener); listener = -1
        unlink(Self.path)
    }

    /// Sends d's state on every change, at most 30 times a second.
    func follow(_ d: Dictation) {
        current = { [weak d] in d?.liveLine ?? Data() }
        withObservationTracking { _ = d.liveLine } onChange: {
            Task { @MainActor in
                self.publish()
                self.follow(d)
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
        clients.removeAll { c in
            let ok = Self.send(c, line)
            if !ok { close(c) }
            return !ok
        }
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
            clients.append(c)
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
        let e: [String: Any] = ["phase": name, "settled": settled, "guessing": guessing,
                                "level": Int((level * 100).rounded()), "locked": locked, "app": frontApp]
        guard var d = try? JSONSerialization.data(withJSONObject: e, options: [.sortedKeys]) else { return Data() }
        d.append(0x0A)
        return d
    }

}
