import AppKit

/// Where the blob sits: a display, one of its edges, and how far along that edge (0…1, from the bottom or left).
struct Spot: Codable, Equatable {
    var display: String
    var edge: Dictation.Edge
    var t: CGFloat

    typealias Screen = (id: String, visible: CGRect)
    /// From the screen's edge to the blob's centre: the 10 pt margin plus half its 12 pt thickness.
    static let inset: CGFloat = 16
    /// The blob's centre stays this far from a corner: 24 pt clear plus half its 44 pt length.
    static let cornerGap: CGFloat = 24 + 22

    static func screens() -> [Screen] {
        NSScreen.screens.map { ($0.uuid, dockingFrame(frame: $0.frame, visible: $0.visibleFrame)) }
    }

    /// Keep the menu bar and side Dock clear, but anchor to the physical bottom edge.
    /// visibleFrame otherwise lifts the blob by the bottom Dock's entire reserved height.
    static func dockingFrame(frame: CGRect, visible: CGRect) -> CGRect {
        CGRect(x: visible.minX, y: frame.minY, width: visible.width, height: visible.maxY - frame.minY)
    }

    /// The spot's display, or the main one if it's gone.
    static func visible(for spot: Spot, in screens: [Screen]) -> CGRect? {
        (screens.first { $0.id == spot.display } ?? screens.first)?.visible
    }

    /// The nearest right, left or bottom edge, on the screen the point is on (or nearest to). Never the top,
    /// where the menu bar and notch are.
    static func snap(_ p: CGPoint, screens: [Screen]) -> Spot {
        func outside(_ r: CGRect) -> CGFloat { hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY)) }
        let r = screens.min { outside($0.visible) < outside($1.visible) } ?? ("", .zero)
        let v = r.visible
        let edge = [(Dictation.Edge.right, abs(v.maxX - p.x)), (.left, abs(p.x - v.minX)), (.bottom, abs(p.y - v.minY))]
            .min { $0.1 < $1.1 }!.0
        let (along, length) = edge == .bottom ? (p.x - v.minX, v.width) : (p.y - v.minY, v.height)
        let gap = min(0.5, cornerGap / max(1, length))
        return Spot(display: r.id, edge: edge, t: min(max(along / max(1, length), gap), 1 - gap))
    }

    static func blobCentre(_ s: Spot, _ v: CGRect) -> CGPoint {
        switch s.edge {
        case .right: CGPoint(x: v.maxX - inset, y: v.minY + s.t * v.height)
        case .left: CGPoint(x: v.minX + inset, y: v.minY + s.t * v.height)
        case .bottom: CGPoint(x: v.minX + s.t * v.width, y: v.minY + inset)
        }
    }

    /// The panel docked to the spot's edge and kept on screen. Near a corner it can't centre on the blob,
    /// so `slide` is how far along the edge the blob sits from the panel's middle.
    static func panelFrame(_ s: Spot, _ v: CGRect, size: CGSize = Dictation.panelSize) -> (frame: CGRect, slide: CGFloat) {
        let c = blobCentre(s, v)
        func clamp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(x, hi)) }
        if s.edge == .bottom {
            let x = clamp(c.x - size.width / 2, v.minX, v.maxX - size.width)
            return (CGRect(origin: CGPoint(x: x, y: v.minY), size: size), c.x - (x + size.width / 2))
        }
        let y = clamp(c.y - size.height / 2, v.minY, v.maxY - size.height)
        let x = s.edge == .right ? v.maxX - size.width : v.minX
        return (CGRect(origin: CGPoint(x: x, y: y), size: size), c.y - (y + size.height / 2))
    }

    /// The saved spot, else the old "edge" setting, else the middle of the right edge.
    static func load() -> Spot {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "spot"), let s = try? JSONDecoder().decode(Spot.self, from: data) { return s }
        return Spot(display: "", edge: Dictation.Edge(rawValue: d.string(forKey: "edge") ?? "") ?? .right, t: 0.5)
    }

    func save() { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: "spot") }

    /// Two side-by-side screens, A then B, with no menu bars.
    static func selfTest() {
        let a = CGRect(x: 0, y: 0, width: 1000, height: 800), b = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let screens: [Screen] = [("A", a), ("B", b)]
        let docked = dockingFrame(frame: a, visible: CGRect(x: 0, y: 80, width: 1000, height: 695))
        precondition(docked.minY == 0 && docked.maxY == 775)
        precondition(blobCentre(Spot(display: "A", edge: .bottom, t: 0.5), docked).y == inset)
        let sideDock = dockingFrame(frame: b, visible: CGRect(x: 1080, y: 0, width: 920, height: 775))
        precondition(sideDock.minX == 1080 && sideDock.maxY == 775)
        precondition(snap(CGPoint(x: 1995, y: 400), screens: screens) == Spot(display: "B", edge: .right, t: 0.5))
        let low = snap(CGPoint(x: 1300, y: 5), screens: screens)
        precondition(low.display == "B" && low.edge == .bottom && abs(low.t - 0.3) < 0.001)
        let corner = snap(CGPoint(x: 1999, y: 799), screens: screens)
        precondition(corner.edge == .right && abs(corner.t - (1 - cornerGap / 800)) < 0.001, "a corner should be clamped")
        let (frame, slide) = panelFrame(corner, b)
        precondition(b.contains(frame) && slide > 0, "the panel stays on screen and the blob slides to the corner")
        precondition(abs(frame.midY + slide - blobCentre(corner, b).y) < 0.001)
        precondition(panelFrame(Spot(display: "B", edge: .bottom, t: 0.5), b).slide == 0)
        let back = try! JSONDecoder().decode(Spot.self, from: JSONEncoder().encode(low))
        precondition(back == low && visible(for: back, in: screens) == b)
        precondition(visible(for: Spot(display: "gone", edge: .left, t: 0.2), in: screens) == a, "a missing display falls back")
        // Every edge and corner stays visible and preserves its along-edge coordinate.
        for v in [a, b, CGRect(x: -1600, y: -900, width: 1600, height: 900)] {
            for edge in Dictation.Edge.allCases {
                for t in [CGFloat(0.06), 0.25, 0.5, 0.75, 0.94] {
                    let spot = Spot(display: "test", edge: edge, t: t)
                    let centre = blobCentre(spot, v)
                    let placement = panelFrame(spot, v)
                    precondition(v.contains(placement.frame), "panel must stay within the visible display")
                    let actual = edge == .bottom ? placement.frame.midX + placement.slide : placement.frame.midY + placement.slide
                    let expected = edge == .bottom ? centre.x : centre.y
                    precondition(abs(actual - expected) < 0.001, "offset must preserve the selected location")
                    precondition(snap(centre, screens: [("test", v)]).edge == edge)
                }
            }
        }
        let outside = snap(CGPoint(x: 2200, y: 400), screens: screens)
        precondition(outside.display == "B" && outside.edge == .right)
        let above = snap(CGPoint(x: 300, y: 1100), screens: screens)
        precondition(above.edge == .left, "the menu bar is never a docking edge")
        print("spot self-test passed (multi-display geometry and persistence)")
    }
}

extension NSScreen {
    /// Unlike the display number, this survives reboots and plugging displays in a different order.
    var uuid: String {
        guard let n = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let u = CGDisplayCreateUUIDFromDisplayID(n)?.takeRetainedValue() else { return "" }
        return CFUUIDCreateString(nil, u) as String
    }
}
