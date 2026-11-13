import SwiftUI
import AppKit

struct PaperDesign: Codable, Equatable, Sendable {
    var paperColor = "#FFFFFF"
    var ruleColor = "#D6E4F5"
    var spacing: Double = 28
    var marginEnabled = false
    var marginPosition: Double = 48
    var marginColor = "#DA9B9B"
}

extension PageElement {
    mutating func trimCellColors() {
        guard case .table(let rows) = content, let colors = tableCellColors else { return }
        tableCellColors = colors.filter { key, _ in
            let parts = key.split(separator: ":").compactMap { Int($0) }
            return parts.count == 2 && rows.indices.contains(parts[0]) && rows[parts[0]].indices.contains(parts[1])
        }
    }
}

// Spreadsheet TSV supports quoted tabs, newlines and doubled quotation marks.
enum TableText {
    static func parse(_ text: String) throws -> [[String]] {
        guard !text.isEmpty, text.utf8.count <= 10_000_000 else {
            throw NotebookFailure.invalid("Copy some tab-separated text first (up to 10 MB).")
        }
        let chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        var rows: [[String]] = []; var row: [String] = []; var cell = ""
        var quoted = false; var closed = false; var i = 0
        while i < chars.count {
            let ch = chars[i]
            if quoted {
                if ch == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { cell.append("\""); i += 1 }
                    else { quoted = false; closed = true }
                } else { cell.append(ch) }
            } else if ch == "\t" || ch == "\n" {
                row.append(cell); cell = ""; closed = false
                if ch == "\n" { rows.append(row); row = [] }
            } else if ch == "\"" && cell.isEmpty && !closed { quoted = true }
            else {
                guard !closed else { throw NotebookFailure.invalid("Unexpected text after a quoted table cell.") }
                cell.append(ch)
            }
            guard row.count <= 100, rows.count <= 1000 else { throw NotebookFailure.invalid("Tables support up to 1,000 rows and 100 columns.") }
            i += 1
        }
        guard !quoted else { throw NotebookFailure.invalid("A quoted table cell was not closed.") }
        if chars.last != "\n" || !row.isEmpty || !cell.isEmpty { row.append(cell); rows.append(row) }
        let columns = rows.map(\.count).max() ?? 0
        guard columns > 0, columns <= 100, rows.count <= 1000, rows.count * columns <= 20_000 else {
            throw NotebookFailure.invalid("Tables support up to 20,000 cells.")
        }
        return rows.map { $0 + Array(repeating: "", count: columns - $0.count) }
    }
}

@MainActor
struct PaperDesignSheet: View {
    @Environment(\.dismiss) private var dismiss
    @KiyobumiState var design: PaperDesign
    @KiyobumiState var background: PageBackground
    let apply: (PaperDesign, PageBackground) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Page design").font(.title2)
            Picker("Ruling", selection: $background) {
                Text("Plain").tag(PageBackground.plain)
                Text("Ruled").tag(PageBackground.ruled)
                Text("Grid").tag(PageBackground.grid)
            }.pickerStyle(.segmented)
            ColorPicker("Paper colour", selection: colour(\.paperColor), supportsOpacity: false)
            ColorPicker("Rule colour", selection: colour(\.ruleColor), supportsOpacity: false)
            HStack { Text("Rule spacing"); Slider(value: $design.spacing, in: 8...96, step: 1); Text("\(Int(design.spacing)) pt").monospacedDigit() }
            Toggle("Show margin line", isOn: $design.marginEnabled)
            HStack { Text("Margin position"); Slider(value: $design.marginPosition, in: 0...400, step: 1); Text("\(Int(design.marginPosition)) pt").monospacedDigit() }.disabled(!design.marginEnabled)
            ColorPicker("Margin colour", selection: colour(\.marginColor), supportsOpacity: false).disabled(!design.marginEnabled)
            Text("Ruling and margins are visual guides; they do not move existing content.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Reset") { design = PaperDesign(); background = .plain }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Apply") { apply(design, background); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 480)
    }
    private func colour(_ key: WritableKeyPath<PaperDesign, String>) -> Binding<Color> {
        Binding(get: { Color(hex: design[keyPath: key]) }, set: { design[keyPath: key] = $0.hex })
    }
}

@MainActor
enum CellShading {
    static let palette: [(String, String)] = [("Yellow", "#FFF3B0"), ("Green", "#D9EAD3"), ("Blue", "#D9E8FB"), ("Pink", "#F4D7E6"), ("Grey", "#E5E5E5"), ("White", "#FFFFFF")]
}

@MainActor
final class ShadedCellTextView: UndoSafeTextView {
    var onColor: ((String?) -> Void)?
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        let shading = NSMenu(title: "Cell shading")
        for (index, choice) in ([("None", "")] + CellShading.palette).enumerated() {
            let item = NSMenuItem(title: choice.0, action: #selector(setCellShading(_:)), keyEquivalent: "")
            item.target = self; item.tag = index; shading.addItem(item)
        }
        menu.addItem(.separator())
        let item = NSMenuItem(title: "Cell shading", action: nil, keyEquivalent: "")
        item.submenu = shading; menu.addItem(item)
        return menu
    }
    @objc private func setCellShading(_ sender: NSMenuItem) {
        onColor?(sender.tag == 0 ? nil : CellShading.palette[sender.tag - 1].1)
    }
}
