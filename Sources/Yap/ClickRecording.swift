import Foundation

/// A click latches recording; holding records until release. Independent of the fn gesture.
struct ClickRecording {
    enum Action: Equatable { case none, start, latch, finish }
    private var began: TimeInterval?
    private var stopped = false
    var pressed: Bool { began != nil }

    mutating func down(at time: TimeInterval, listening: Bool) -> Action {
        guard began == nil else { return .none }
        began = time
        stopped = listening
        return listening ? .finish : .start
    }

    mutating func up(at time: TimeInterval, listening: Bool) -> Action {
        guard let began else { return .none }
        self.began = nil
        guard !stopped, listening else { return .none }
        return time - began < 0.3 ? .latch : .finish
    }

    static func selfTest() {
        var click = Self()
        precondition(click.up(at: 0, listening: false) == .none)
        precondition(click.down(at: 1, listening: false) == .start)
        precondition(click.up(at: 1.1, listening: true) == .latch)
        precondition(click.down(at: 2, listening: true) == .finish)
        precondition(click.up(at: 2.1, listening: false) == .none)
        precondition(click.down(at: 3, listening: false) == .start)
        precondition(click.up(at: 4, listening: true) == .finish)
        precondition(click.down(at: 5, listening: false) == .start)
        precondition(click.up(at: 5.1, listening: false) == .none, "failed/cancelled recording must not latch")
        precondition(!click.pressed)
        print("click recording self-test passed")
    }
}
