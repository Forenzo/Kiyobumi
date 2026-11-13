import SwiftUI
import AppKit

// A fixed-width group prevents native menus from creating empty flexible gaps.
@MainActor
struct ToolbarBox<Content: View>: View {
    @ObservedObject private var appearance = AppearancePreferences.shared
    @Environment(\.colorScheme) private var colorScheme
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 5)
                .fill(appearance.theme == .classic ? Color(nsColor: .controlBackgroundColor) :
                    Color(hex: appearance.theme.controlHex(dark: colorScheme == .dark))))
            .overlay(RoundedRectangle(cornerRadius: 5)
                .stroke(appearance.theme == .classic ? Color(nsColor: .separatorColor) :
                    Color(hex: appearance.theme.highlightHex).opacity(0.65), lineWidth: 1))
            .overlay(alignment: .top) {
                if appearance.theme != .classic {
                    Rectangle().fill(Color.white.opacity(0.35)).frame(height: 1)
                        .padding(.horizontal, 5).allowsHitTesting(false)
                }
            }
            .shadow(color: appearance.theme == .classic ? Color.clear : Color.black.opacity(0.3),
                    radius: 0, x: 1, y: 1)
    }
}

// Original vector artwork: no bitmap asset or platform-specific symbol needed.
struct FloppyDiskIcon: View {
    var body: some View {
        FloppyDiskOutline()
            .stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
    }
}

private struct FloppyDiskOutline: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 24,
                    y: rect.minY + rect.height * y / 24)
        }
        var path = Path()
        path.move(to: point(3, 3))
        path.addLine(to: point(17, 3))
        path.addLine(to: point(21, 7))
        path.addLine(to: point(21, 21))
        path.addLine(to: point(3, 21))
        path.closeSubpath()
        // Metal shutter and its narrow opening.
        path.move(to: point(7, 3))
        path.addLine(to: point(7, 10))
        path.addLine(to: point(16, 10))
        path.addLine(to: point(16, 3))
        path.move(to: point(13, 5))
        path.addLine(to: point(13, 8))
        // Paper label on the lower half.
        path.move(to: point(7, 21))
        path.addLine(to: point(7, 14))
        path.addLine(to: point(17, 14))
        path.addLine(to: point(17, 21))
        return path
    }
}
