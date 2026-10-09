import AppKit

/// NSCursor requests from an inactive app are ignored by WindowServer by default.
/// This undocumented, process-local opt-in keeps the paste destination focused.
/// Symbols are resolved at runtime so a future OS can safely fall back to normal cursors.
enum BackgroundCursor {
    private typealias Connection = @convention(c) () -> Int32
    private typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
    private static var enabled = false

    @discardableResult
    static func allow(_ allow: Bool) -> Bool {
        guard enabled != allow else { return enabled }
        let symbols = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT on Darwin
        guard let connectionSymbol = dlsym(symbols, "CGSMainConnectionID"),
              let propertySymbol = dlsym(symbols, "CGSSetConnectionProperty") else { return false }
        let connection = unsafeBitCast(connectionSymbol, to: Connection.self)()
        let setProperty = unsafeBitCast(propertySymbol, to: SetProperty.self)
        let result = setProperty(connection, connection, "SetsCursorInBackground" as CFString,
                                 allow ? kCFBooleanTrue : kCFBooleanFalse)
        guard result == 0 else { return false }
        enabled = allow
        // A previously ignored request may be cached in AppKit. Force the next hand request to resend.
        if allow { NSCursor.arrow.set() }
        return enabled
    }
}
