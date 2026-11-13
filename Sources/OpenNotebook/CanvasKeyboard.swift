import SwiftUI
import AppKit

@MainActor
struct CanvasKeyboard: NSViewRepresentable {
    let canDelete: Bool
    var selectionToken: UUID? = nil
    let onDelete: () -> Void
    func makeNSView(context: Context) -> Probe { let view = Probe(); view.start(); return view }
    func updateNSView(_ view: Probe, context: Context) {
        if let selectionToken, selectionToken != view.selectionToken {
            view.armed = true
        }
        view.selectionToken = selectionToken
        view.canDelete = canDelete; view.onDelete = onDelete
    }
    static func dismantleNSView(_ view: Probe, coordinator: ()) { view.stop() }
    final class Probe: NSView {
        var canDelete = false
        var armed = false
        var selectionToken: UUID?
        var onDelete: (() -> Void)?
        private var monitor: Any?
        func start() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
                guard let self = self, let window = self.window, event.window === window,
                      window.isKeyWindow, window.attachedSheet == nil else { return event }
                if event.type == .leftMouseDown {
                    self.armed = self.bounds.contains(self.convert(event.locationInWindow, from: nil))
                    return event
                }
                let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
                guard self.armed, self.canDelete, flags.isEmpty, [51, 117].contains(event.keyCode) else { return event }
                // A title, table cell, search field or active text editor owns its Delete key.
                if let text = window.firstResponder as? NSTextView, text.isEditable { return event }
                self.onDelete?(); return nil
            }
        }
        func stop() { if let monitor = monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
    }
}

struct ElementResizeHandles: View {
    let width: Double
    let height: Double
    var allowsHeightResize = true
    let onChange: (CGSize, Bool) -> Void
    let onEnd: () -> Void
    var body: some View {
        ZStack(alignment: .topLeading) {
            handle(corner: false).position(x: width, y: height / 2)
            if allowsHeightResize { handle(corner: true).position(x: width, y: height) }
        }.frame(width: width, height: height)
    }
    private func handle(corner: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.accentColor, lineWidth: 1.5))
            .frame(width: 12, height: corner ? 12 : 24)
            .contentShape(Rectangle())
            .help(corner ? "Drag to resize width and height" : "Drag to resize width")
            .accessibilityLabel(corner ? "Resize box" : "Resize box width")
            .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("page"))
                .onChanged { onChange($0.translation, corner) }.onEnded { _ in onEnd() })
    }
}
