import SwiftUI
import AppKit

enum NotebookWindowSizePolicy {
    // Logical screen points. Clamp the first frame to the usable display.
    static func initialFrame(current: CGRect, visible: CGRect) -> CGRect {
        let width = min(max(current.width, 1400), max(1, visible.width - 32))
        let height = min(max(current.height, 900), max(1, visible.height - 32))
        let x = min(max(current.minX, visible.minX + 16), visible.maxX - width - 16)
        let y = min(max(current.maxY - height, visible.minY + 16), visible.maxY - height - 16)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

@MainActor
struct InitialNotebookWindowSize: NSViewRepresentable {
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) {}
    final class Probe: NSView {
        private weak var configuredWindow: NSWindow?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let window = self.window,
                      self.configuredWindow !== window else { return }
                guard !window.styleMask.contains(.fullScreen),
                      let screen = window.screen ?? NSScreen.main else { return }
                self.configuredWindow = window
                // Also enlarge a compact frame restored from the older app.
                // Configure once: later manual resizing is left to the user.
                let frame = NotebookWindowSizePolicy.initialFrame(current: window.frame, visible: screen.visibleFrame)
                if window.frame != frame {
                    window.setFrame(frame, display: true)
                }
            }
        }
    }
}
