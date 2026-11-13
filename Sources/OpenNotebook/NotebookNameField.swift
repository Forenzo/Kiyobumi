import SwiftUI

@MainActor
struct NotebookNameField: View {
    @Binding var name: String
    @EnvironmentObject private var autosave: NotebookAutosave
    @KiyobumiState private var draft = ""
    @KiyobumiState private var busy = false
    @KiyobumiState private var errorMessage: String?
    @FocusState private var focused: Bool
    var body: some View {
        TextField("Notebook name", text: $draft)
            .font(.headline).textFieldStyle(.plain).focused($focused).disabled(busy)
            .onAppear { draft = name }
            .onChange(of: name) { value in if !focused { draft = value } }
            .onSubmit { commit() }
            .onChange(of: focused) { value in if !value { commit() } }
            .alert("Could not rename notebook", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
    }
    private func commit() {
        guard !busy else { return }
        let proposed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard proposed != name || !autosave.filenameMatches(proposed) else { draft = name; return }
        guard !proposed.isEmpty, proposed != ".", proposed != "..",
              proposed.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\:").union(.controlCharacters)) == nil,
              proposed.utf8.count <= 240 else {
            errorMessage = "Use a non-empty name without slashes, colons or control characters (up to 240 UTF-8 bytes)."
            draft = name; return
        }
        busy = true
        autosave.rename(to: proposed) { error in
            busy = false
            if let error { errorMessage = error.localizedDescription; draft = name }
            else {
                name = proposed; draft = proposed
                DispatchQueue.main.async { autosave.saveIfNeeded() }
            }
        }
    }
}

extension View {
    @ViewBuilder func withoutNotebookWindowTitle() -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { self.toolbar(removing: .title) }
        else { self }
        #else
        self
        #endif
    }
}
