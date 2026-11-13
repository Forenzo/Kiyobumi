import SwiftUI
import AppKit

/// A native secondary-click target on blank paper. All other hits pass through.
@MainActor
struct CanvasMiddleClick: NSViewRepresentable {
    let canvasSize: CGSize
    let enabled: Bool
    let canCreateAt: (CGPoint) -> Bool
    let onCreate: (CGPoint) -> Void

    func makeNSView(context: Context) -> Probe {
        let view = Probe(frame: CGRect(origin: .zero, size: canvasSize))
        configure(view)
        return view
    }
    func updateNSView(_ view: Probe, context: Context) { configure(view) }
    private func configure(_ view: Probe) {
        view.enabled = enabled
        view.canCreateAt = canCreateAt
        view.onCreate = onCreate
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Probe, context: Context) -> CGSize? {
        canvasSize
    }
    static func dismantleNSView(_ view: Probe, coordinator: ()) { view.stopDiagnostics() }

    final class Probe: NSView {
        var enabled = false
        var canCreateAt: ((CGPoint) -> Bool)?
        var onCreate: ((CGPoint) -> Void)?
        private var handlingClick = false
        private var diagnosticMonitor: Any?
        private let diagnostics = ProcessInfo.processInfo.environment["KIYOBUMI_CLICK_DEBUG"] == "1"
        override var isFlipped: Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        static func isCreationClick(_ event: NSEvent) -> Bool {
            event.type == .rightMouseDown ||
                (event.type == .otherMouseDown && event.buttonNumber == 2) ||
                (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
        }

        func acceptsCreation(at point: CGPoint) -> Bool {
            enabled && bounds.contains(point) && canCreateAt?(point) == true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard !isHiddenOrHasHiddenAncestor, window?.attachedSheet == nil,
                  let event = NSApp.currentEvent else { return nil }
            // AppKit supplies this point in the superview's coordinates.
            let local = convert(point, from: superview)
            if handlingClick && [.rightMouseUp, .otherMouseUp, .leftMouseUp].contains(event.type) {
                return self
            }
            guard Self.isCreationClick(event), acceptsCreation(at: local) else { return nil }
            log("native hit accepted at \(local)")
            return self
        }

        override func rightMouseDown(with event: NSEvent) { createBox(with: event) }
        override func otherMouseDown(with event: NSEvent) { createBox(with: event) }
        override func mouseDown(with event: NSEvent) { createBox(with: event) }
        override func rightMouseUp(with event: NSEvent) { handlingClick = false }
        override func otherMouseUp(with event: NSEvent) { handlingClick = false }
        override func mouseUp(with event: NSEvent) { handlingClick = false }

        private func createBox(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            guard Self.isCreationClick(event), acceptsCreation(at: point),
                  window?.attachedSheet == nil, let create = onCreate else { return }
            handlingClick = true
            log("creating text box at \(point)")
            create(point)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopDiagnostics()
            guard diagnostics, window != nil else { return }
            log("attached; bounds=\(bounds)")
            // Observe only for diagnosis; event routing belongs to hitTest and
            // the native mouse methods, not to this monitor.
            diagnosticMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .otherMouseDown, .leftMouseDown]) { [weak self] event in
                guard let self, event.window === self.window else { return event }
                let point = self.convert(event.locationInWindow, from: nil)
                self.log("event=\(event.type.rawValue) button=\(event.buttonNumber) control=\(event.modifierFlags.contains(.control)) bounds=\(self.bounds) point=\(point) enabled=\(self.enabled) blank=\(self.canCreateAt?(point) == true)")
                return event
            }
        }
        func stopDiagnostics() {
            if let diagnosticMonitor { NSEvent.removeMonitor(diagnosticMonitor) }
            diagnosticMonitor = nil
        }
        private func log(_ message: String) {
            if diagnostics { NSLog("KiyobumiClick: %@", message) }
        }
    }
}
