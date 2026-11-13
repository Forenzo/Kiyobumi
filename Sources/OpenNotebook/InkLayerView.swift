import SwiftUI

/// Draws all ink for the page in one Canvas (fast, non-interactive).
struct InkLayerView: View {
    let inkElements: [PageElement]
    let liveStroke: Stroke?

    var body: some View {
        Canvas { context, _ in
            for element in inkElements {
                guard case .ink(let strokes) = element.content else { continue }
                let origin = CGPoint(x: element.frame.x, y: element.frame.y)
                for stroke in strokes {
                    draw(stroke, offset: origin, into: &context)
                }
            }
            if let live = liveStroke {
                draw(live, offset: .zero, into: &context)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ stroke: Stroke, offset: CGPoint, into context: inout GraphicsContext) {
        let pts = stroke.points
        guard !pts.isEmpty else { return }

        let at = { (p: StrokePoint) in
            CGPoint(x: p.x + offset.x, y: p.y + offset.y)
        }

        var path = Path()
        if pts.count == 1 {
            let point = at(pts[0]); let radius = stroke.width / 2
            path.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius,
                                      width: stroke.width, height: stroke.width))
            context.fill(path, with: .color(Color(hex: stroke.colorHex).opacity(stroke.opacity ?? 1)))
            return
        }
        path.move(to: at(pts[0]))

        if pts.count == 2 {
            path.addLine(to: at(pts[1]))
        } else {
            // Quadratic smoothing through segment midpoints
            for i in 1..<pts.count {
                let prev = at(pts[i - 1])
                let curr = at(pts[i])
                let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
                path.addQuadCurve(to: mid, control: prev)
            }
            path.addLine(to: at(pts[pts.count - 1]))
        }

        let color = Color(hex: stroke.colorHex)
            .opacity(stroke.opacity ?? (stroke.kind == .highlighter ? 0.35 : 1))

        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: stroke.width,
                lineCap: stroke.kind == .highlighter ? .butt : .round,
                lineJoin: .round
            )
        )
    }
}
