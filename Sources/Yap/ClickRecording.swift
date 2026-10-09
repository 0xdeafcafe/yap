import Foundation

/// Clicks act on release. A deliberate hold starts after the threshold and finishes on release.
struct ClickRecording {
    enum Action: Equatable { case none, start, latch, finish }
    private var began: TimeInterval?
    private var wasListening = false
    private var holding = false
    var pressed: Bool { began != nil }

    mutating func down(at time: TimeInterval, listening: Bool) -> Action {
        guard began == nil else { return .none }
        began = time; wasListening = listening; holding = false
        return .none
    }

    mutating func hold(at time: TimeInterval) -> Action {
        guard let began, time - began >= 0.3, !wasListening, !holding else { return .none }
        holding = true
        return .start
    }

    mutating func up(at time: TimeInterval, listening: Bool, inside: Bool = true) -> Action {
        guard began != nil else { return .none }
        began = nil
        if holding { return listening ? .finish : .none }
        guard inside else { return .none }
        if wasListening { return listening ? .finish : .none }
        return listening ? .none : .latch
    }

    static func selfTest() {
        var click = Self()
        precondition(click.up(at: 0, listening: false) == .none)
        precondition(click.down(at: 1, listening: false) == .none)
        precondition(click.hold(at: 1.1) == .none)
        precondition(click.up(at: 1.1, listening: false) == .latch)
        precondition(click.down(at: 2, listening: true) == .none)
        precondition(click.hold(at: 2.5) == .none)
        precondition(click.up(at: 2.6, listening: true) == .finish)
        precondition(click.down(at: 3, listening: false) == .none)
        precondition(click.hold(at: 3.4) == .start)
        precondition(click.hold(at: 3.5) == .none)
        precondition(click.up(at: 4, listening: true, inside: false) == .finish)
        precondition(click.down(at: 5, listening: false) == .none)
        precondition(click.hold(at: 5.4) == .start)
        precondition(click.up(at: 5.5, listening: false) == .none)
        precondition(click.down(at: 6, listening: false) == .none)
        precondition(click.up(at: 6.1, listening: false, inside: false) == .none)
        precondition(click.hold(at: 7) == .none)
        precondition(!click.pressed)
        print("click recording self-test passed")
    }
}
