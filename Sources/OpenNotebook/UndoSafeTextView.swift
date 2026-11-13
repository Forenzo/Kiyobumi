import AppKit

/// Native text undo belongs to the editor, never the longer-lived window.
/// Page snapshots have their own history in PageEditorView.
@MainActor
class UndoSafeTextView: NSTextView {
    let textUndoManager = UndoManager()
    override var undoManager: UndoManager? { textUndoManager }

    func resetTextUndo() {
        breakUndoCoalescing()
        textUndoManager.removeAllActions()
    }

    func detachTextUndo() {
        resetTextUndo()
        allowsUndo = false
    }
}
