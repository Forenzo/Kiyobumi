import SwiftUI
import AppKit
import UniformTypeIdentifiers

// Sharing is invoked from the application Share menu.
@MainActor
final class NotebookMenuShare: NSObject {
    static let shared = NotebookMenuShare()
    private var picker: NSSharingServicePicker?
    private var busy = false

    func share() {
        guard !busy else { return }
        guard let window = NSApp.mainWindow,
              let document = NSDocumentController.shared.documents.first(where: { doc in
                  doc.windowControllers.contains { $0.window === window }
              }), let url = document.fileURL else {
            let alert = NSAlert()
            alert.messageText = "Open a saved notebook to share"
            alert.informativeText = "Select a notebook in Kiyobumi first. New unsaved documents need to be saved once."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal(); return
        }
        window.makeFirstResponder(nil)
        busy = true
        DispatchQueue.main.async { [self, weak window] in
            guard !NotebookAutosave.renamesInProgress.contains(ObjectIdentifier(document)) else {
                busy = false
                let alert = NSAlert()
                alert.messageText = "Notebook rename is finishing"
                alert.informativeText = "Please click Share again after the rename completes."
                alert.runModal(); return
            }
            document.save(to: document.fileURL ?? url, ofType: document.fileType ?? UTType.openNotebook.identifier,
                          for: .saveOperation) { [self, weak window] error in
                DispatchQueue.main.async { [self, weak window] in
                    busy = false
                    if let error {
                        let alert = NSAlert()
                        alert.messageText = "Could not prepare notebook for sharing"
                        alert.informativeText = String(error.localizedDescription.prefix(800))
                        alert.runModal(); return
                    }
                    guard let view = window?.contentView, window?.isVisible == true else { return }
                    let sharing = NSSharingServicePicker(items: [document.fileURL ?? url])
                    picker = sharing
                    sharing.show(relativeTo: NSRect(x: 16, y: view.isFlipped ? 0 : view.bounds.maxY - 1, width: 1, height: 1),
                                 of: view, preferredEdge: .minY)
                }
            }
        }
    }
}

@MainActor
struct NotebookShareCommands: Commands {
    var body: some Commands {
        CommandMenu("Share") {
            Button("Share Notebook…") { NotebookMenuShare.shared.share() }
        }
    }
}
