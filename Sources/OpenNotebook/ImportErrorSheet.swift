import SwiftUI
import AppKit

struct OneNoteImportFailure: LocalizedError, Sendable {
    let details: String
    var errorDescription: String? {
        if details.contains("Unexpected node") {
            return "This section contains a OneNote record the reader could not handle."
        }
        if details.localizedCaseInsensitiveContains("encrypted") {
            return "This section is protected or encrypted."
        }
        if details.localizedCaseInsensitiveContains("timed out") {
            return "The import did not finish within its time limit."
        }
        return "The OneNote file could not be converted."
    }
}

// Keep a short explanation separate from a bounded diagnostic log.
struct ImportProblem: Identifiable {
    let id = UUID()
    let summary: String
    let details: String
    init(_ error: Error) {
        let raw = (error as? OneNoteImportFailure)?.details ?? error.localizedDescription
        let firstLine = error.localizedDescription.components(separatedBy: .newlines).first ?? "Import failed."
        summary = Self.bounded(firstLine, limit: 240)
        details = Self.bounded(raw, limit: 32_768)
    }
    static func bounded(_ text: String, limit: Int) -> String {
        let prefix = String(text.prefix(limit))
        return prefix == text ? text : prefix + "\n… Remaining diagnostic text omitted."
    }
}

struct ImportErrorSheet: View {
    let problem: ImportProblem
    let dismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Could not import OneNote", systemImage: "exclamationmark.triangle")
                .font(.title2)
            Text(problem.summary)
            Text("The source file and current notebook were not changed.")
                .foregroundStyle(.secondary)
            Text("Technical details").font(.headline)
            ScrollView([.horizontal, .vertical]) {
                Text(problem.details).font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.3)))
            HStack {
                Button("Copy details") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(problem.details, forType: .string)
                }
                Spacer()
                Button("Close", action: dismiss).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 640, height: 440)
        .onExitCommand(perform: dismiss)
    }
}
