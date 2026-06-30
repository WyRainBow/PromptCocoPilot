import SwiftUI

/// Invoko cloud mascot, drawn with SwiftUI Shape + Path (no image).
/// Asymmetric puffy cloud: tallest bump centre-left, a gentle rightward extension
/// with a lower-right lobe, flat-rounded base. Circles are sized against the
/// height and overlap heavily so the union is one smooth, seamless silhouette.
struct CloudShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func bump(_ cx: CGFloat, _ cy: CGFloat, _ dRel: CGFloat) -> CGRect {
            let d = dRel * h
            return CGRect(x: cx * w - d / 2, y: cy * h - d / 2, width: d, height: d)
        }
        var p = Path()
        // Flat-rounded base ties the lobes together.
        p.addRoundedRect(in: CGRect(x: w * 0.05, y: h * 0.48, width: w * 0.90, height: h * 0.46),
                         cornerSize: CGSize(width: h * 0.24, height: h * 0.24))
        p.addEllipse(in: bump(0.44, 0.40, 0.86))   // center — tallest
        p.addEllipse(in: bump(0.21, 0.60, 0.54))   // left shoulder
        p.addEllipse(in: bump(0.16, 0.72, 0.40))   // left-low round-off
        p.addEllipse(in: bump(0.65, 0.51, 0.70))   // right
        p.addEllipse(in: bump(0.82, 0.64, 0.50))   // lower-right lobe (extension)
        return p
    }
}

/// The cloud: soft diagonal periwinkle gradient (matte, no sheen/stroke) + two
/// plain black round eyes, lower-centre-left, with a gentle outer shadow.
struct CloudView: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let eyeD = h * 0.175

            ZStack {
                // Matte periwinkle body (light, low saturation).
                CloudShape()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.97, blue: 1.0),    // near-white top-left
                            Color(red: 0.84, green: 0.87, blue: 0.99),
                            Color(red: 0.74, green: 0.78, blue: 0.95),   // soft periwinkle bottom-right
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: Color(red: 0.56, green: 0.61, blue: 0.88).opacity(0.32),
                            radius: h * 0.12, x: w * 0.015, y: h * 0.07)

                // Top-left volume light for a soft, three-dimensional feel.
                CloudShape()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0)],
                        center: UnitPoint(x: 0.32, y: 0.26),
                        startRadius: 0, endRadius: h * 0.95))
                    .allowsHitTesting(false)

                // Two small plain-black round eyes with a clear gap, lower-centre-left.
                HStack(spacing: eyeD * 0.85) {
                    Circle().fill(Color(red: 0.05, green: 0.06, blue: 0.08))
                        .frame(width: eyeD, height: eyeD)
                    Circle().fill(Color(red: 0.05, green: 0.06, blue: 0.08))
                        .frame(width: eyeD, height: eyeD)
                }
                .position(x: w * 0.43, y: h * 0.64)
            }
        }
    }
}
