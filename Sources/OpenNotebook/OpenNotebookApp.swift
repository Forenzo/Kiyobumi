import SwiftUI

@main
@MainActor
struct KiyobumiApp: App {
    @NSApplicationDelegateAdaptor(KiyobumiAppDelegate.self) private var appDelegate
    var body: some Scene {
        DocumentGroup(newDocument: NotebookDocument()) { file in
            NotebookSessionView(document: file.$document, fileURL: file.fileURL)
        }
        .defaultSize(width: 1400, height: 900)
        .controlledNotebookLaunch()
        .commands { NotebookPrintCommands(); NotebookCollectionCommands(); NotebookShareCommands(); TextEditingCommands() }
        Settings { NotebookSettingsView() }
    }
}

private extension Scene {
    func controlledNotebookLaunch() -> some Scene {
        #if compiler(>=6.0)
        // SceneBuilder does not support if/else. Its public availability
        // helpers give both returns the same opaque scene type instead.
        if #available(macOS 15.0, *) {
            return SceneBuilder.buildOptional(SceneBuilder.buildLimitedAvailability(
                self.defaultLaunchBehavior(.suppressed)))
        }
        return SceneBuilder.buildOptional(SceneBuilder.buildLimitedAvailability(self))
        #else
        return self
        #endif
    }
}
