import SwiftUI
import AppKit

@MainActor
struct NotebookSettingsView: View {
    @ObservedObject private var appearance = AppearancePreferences.shared
    @ObservedObject private var preferences = StartupNotebookPreferences.shared
    @ObservedObject private var lastUsed = StartupNotebookPreferences.lastUsed
    @KiyobumiState private var errorMessage: String?
    @ObservedObject private var collection = NotebookCollection.shared
    @AppStorage("automaticallyPushContentDown") private var automaticallyPushContentDown = true
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance").font(.title2)
            Picker("Appearance", selection: $appearance.selection) {
                ForEach(NotebookAppearance.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text("Applies immediately and is remembered. Page paper, text and ink keep their chosen colors; printing is unchanged.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            RetroThemePicker()
            Divider()
            Text("Editing").font(.title2)
            Toggle("Automatically push content down", isOn: $automaticallyPushContentDown)
            Text("Growing text and tables push boxes below them down. Deleting text leaves their positions unchanged; dragging remains free. Ink stays in place.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Notebook folder").font(.title2)
            Text(collection.folderPath).font(.caption).textSelection(.enabled)
            Button("Change folder…") { collection.chooseFolder() }
            Text("New notebooks are saved here automatically. Existing notebooks stay where they are.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Startup notebook").font(.title2)
            Toggle("Reopen the last-used notebook", isOn: $preferences.reopenLastUsed)
            if preferences.reopenLastUsed {
                Text("Kiyobumi remembers the notebook you last used and opens it next time.")
                    .font(.caption).foregroundStyle(.secondary)
                if lastUsed.hasStartupNotebook {
                    Text(URL(fileURLWithPath: lastUsed.displayPath).deletingPathExtension().lastPathComponent)
                        .font(.headline).lineLimit(1).truncationMode(.middle)
                } else {
                    Text("Open a notebook to remember it. Your previous startup choice is used until then.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
            Text("Always open this specific notebook instead.")
            if preferences.hasStartupNotebook {
                Text(URL(fileURLWithPath: preferences.displayPath).lastPathComponent)
                    .font(.headline).lineLimit(1).truncationMode(.middle)
                Text(preferences.displayPath).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2).textSelection(.enabled)
            } else { Text("No startup notebook selected").foregroundStyle(.secondary) }
            HStack {
                Button(preferences.hasStartupNotebook ? "Change…" : "Choose…", action: chooseNotebook)
                Button("Clear") { preferences.clear() }.disabled(!preferences.hasStartupNotebook)
                Spacer()
                Button("Open now") { StartupNotebookController.shared.openDefault() }
                    .disabled(!preferences.hasStartupNotebook)
            }
            }
            Divider()
            Text("Changes apply to future launches. File > New still creates a new notebook.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Hold Option while launching to bypass the startup notebook.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        }
        .frame(width: 540, height: 660)
        .alert("Could not select notebook", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }
    private func chooseNotebook() {
        let panel = NSOpenPanel()
        panel.title = "Choose startup notebook"
        panel.prompt = "Choose"
        panel.allowedContentTypes = [.openNotebook]
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try preferences.choose(url) } catch { errorMessage = error.localizedDescription }
    }
}
