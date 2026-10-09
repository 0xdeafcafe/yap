import SwiftUI

/// Yap's wind-up teeth, as in the menu bar (icon/MenuBarIcon.svg), with a jaw that opens as wide as `open`
/// (0...1). In the panel they stand in for a mic and chatter along with your voice.
struct Teeth: View {
    var open: Double

    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 36, y: size.height / 36)
            func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
            }
            var still = Path()
            for p in [rr(6, 22.4, 4.2, 3.6, 1.3), rr(11.1, 22, 4.2, 4, 1.3), rr(16.2, 22, 4.2, 4, 1.3), rr(21.3, 22.6, 3.6, 3.4, 1.3),
                      rr(4, 26.7, 23, 5, 2.5), rr(8, 31, 5.4, 3.6, 1.8), rr(18, 31, 5.4, 3.6, 1.8),
                      rr(26.5, 25.6, 5, 2.4, 0), rr(31.2, 24, 2.4, 5.6, 0),
                      Path(ellipseIn: CGRect(x: 29.8, y: 21, width: 5.2, height: 5.2)),
                      Path(ellipseIn: CGRect(x: 29.8, y: 27.4, width: 5.2, height: 5.2))] { still.addPath(p) }
            var jaw = Path()
            for p in [rr(4, 14.6, 23, 5.5, 2.75), rr(6, 20.8, 4.2, 3.6, 1.3), rr(11.1, 20.8, 4.2, 4, 1.3),
                      rr(16.2, 20.8, 4.2, 4, 1.3), rr(21.3, 20.8, 3.6, 3.4, 1.3)] { jaw.addPath(p) }
            // The jaw hinges at the back, by the key.
            let hinge = CGAffineTransform(translationX: 27, y: 21.5)
                .rotated(by: (8 + 26 * min(max(open, 0), 1)) * .pi / 180)
                .translatedBy(x: -27, y: -21.5)
            ctx.fill(still, with: .foreground)
            ctx.fill(jaw.applying(hinge), with: .foreground)
        }
        .accessibilityLabel("Listening")
    }
}
