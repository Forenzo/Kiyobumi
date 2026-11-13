import SwiftUI

struct NotebookPrintActions {
    var printPage: () -> Void
    var printSection: () -> Void
    var exportPage: () -> Void
    var exportSection: () -> Void
}
private struct NotebookPrintActionsKey: FocusedValueKey { typealias Value = NotebookPrintActions }
extension FocusedValues {
    var notebookPrintActions: NotebookPrintActions? {
        get { self[NotebookPrintActionsKey.self] }
        set { self[NotebookPrintActionsKey.self] = newValue }
    }
}
@MainActor
struct NotebookPrintCommands: Commands {
    @FocusedValue(\.notebookPrintActions) private var actions
    var body: some Commands {
        CommandGroup(replacing: .printItem) {
            Button("Print Page…") { actions?.printPage() }.keyboardShortcut("p", modifiers: .command).disabled(actions == nil)
            Button("Print Section…") { actions?.printSection() }.disabled(actions == nil)
            Divider()
            Button("Export Page as PDF…") { actions?.exportPage() }.disabled(actions == nil)
            Button("Export Section as PDF…") { actions?.exportSection() }.disabled(actions == nil)
        }
    }
}
