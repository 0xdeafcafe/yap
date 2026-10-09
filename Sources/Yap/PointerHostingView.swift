import AppKit
import SwiftUI

/// A non-key floating panel still needs native cursor updates on every pointer event.
/// Setting a cursor once from a global monitor loses to AppKit's later cursor reset.
final class PointerHostingView: NSHostingView<Pill> {
    var pointerChanged: (() -> Void)?
    var pointerCursor: NSCursor?
    var controlRegions: [CGRect] = []
    private var pointerTracking: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerTracking { removeTrackingArea(pointerTracking) }
        // activeAlways intentionally uses entered/moved events: Apple does not send cursorUpdate
        // for this mode, and making the panel key would steal focus from the paste destination.
        let area = NSTrackingArea(rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
            owner: self, userInfo: nil)
        addTrackingArea(area)
        pointerTracking = area
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard let pointerCursor else { return }
        for region in controlRegions {
            let rect = isFlipped ? region : CGRect(x: region.minX, y: bounds.height - region.maxY,
                                                    width: region.width, height: region.height)
            addCursorRect(rect, cursor: pointerCursor)
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        pointerChanged?()
        pointerCursor?.set()
    }

    override func mouseEntered(with event: NSEvent) { cursorUpdate(with: event) }
    override func mouseMoved(with event: NSEvent) { cursorUpdate(with: event) }
    override func mouseExited(with event: NSEvent) { pointerChanged?() }
}
