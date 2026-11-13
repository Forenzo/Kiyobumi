import SwiftUI
import AppKit

struct SectionTabColor: Identifiable, Sendable {
    let name: String
    let hex: String
    var id: String { hex }
    static let palette: [SectionTabColor] = [
        .init(name: "Blue", hex: "#3B82F6"), .init(name: "Green", hex: "#10B981"),
        .init(name: "Orange", hex: "#F59E0B"), .init(name: "Purple", hex: "#8B5CF6"),
        .init(name: "Pink", hex: "#EC4899"), .init(name: "Teal", hex: "#14B8A6"),
        .init(name: "Red", hex: "#EF4444"), .init(name: "Sky blue", hex: "#06B6D4"),
        .init(name: "Yellow", hex: "#EAB308")
    ]
    static func nextColor(in sections: [Section]) -> String {
        let used = Set(sections.map { $0.colorHex.uppercased() })
        return palette.first { !used.contains($0.hex) }?.hex
            ?? palette[sections.count % palette.count].hex
    }
}

@MainActor
struct SectionTabStrip: View {
    @ObservedObject private var appearance = AppearancePreferences.shared
    @Environment(\.colorScheme) private var colorScheme
    let sections: [Section]
    let selectedSectionID: UUID?
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void
    let onRename: (UUID) -> Void
    let onColor: (UUID, String) -> Void
    let onMove: (UUID, Int) -> Void
    let onDelete: (UUID) -> Void

    private var selectedColor: Color {
        Color(hex: sections.first { $0.id == selectedSectionID }?.colorHex ?? "#3B82F6")
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(sections) { section in
                            tab(section).id(section.id)
                        }
                        if sections.isEmpty {
                            Text("Add a section to start").foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                        }
                    }
                    .padding(.horizontal, 10).padding(.top, 6)
                }
                .onAppear { revealSelection(reader) }
                .onChange(of: selectedSectionID) { _ in revealSelection(reader) }
            }
            Button(action: onAdd) { Image(systemName: "plus").frame(width: 32, height: 36) }
                .buttonStyle(.borderless).help("New section").accessibilityLabel("New section")
            Menu {
                ForEach(sections) { section in
                    Button { onSelect(section.id) } label: {
                        Label(section.name, systemImage: section.id == selectedSectionID ? "checkmark" : "folder")
                    }
                }
                Divider()
                Button("New section", action: onAdd)
            } label: { Image(systemName: "chevron.down").frame(width: 28, height: 36) }
            .menuStyle(.borderlessButton).fixedSize().frame(width: 32)
            .menuIndicator(.hidden).help("All sections").accessibilityLabel("All sections")
            .padding(.trailing, 8)
        }
        .font(.system(size: 14))
        .frame(height: 44)
        .background(appearance.theme == .classic ? Color(nsColor: .windowBackgroundColor) :
            Color(hex: appearance.theme.sidebarHex(dark: colorScheme == .dark, pages: true)))
        .overlay(alignment: .bottom) {
            Rectangle().fill(selectedColor.opacity(0.65)).frame(height: 2).allowsHitTesting(false)
        }
    }

    private func revealSelection(_ reader: ScrollViewProxy) {
        guard let id = selectedSectionID, sections.contains(where: { $0.id == id }) else { return }
        reader.scrollTo(id, anchor: .center)
    }

    private func tab(_ section: Section) -> some View {
        let selected = section.id == selectedSectionID
        let color = Color(hex: section.colorHex)
        let title = section.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled section" : section.name
        return Button { onSelect(section.id) } label: {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 7, height: 7).accessibilityHidden(true)
                Text(title).fontWeight(selected ? .semibold : .regular)
                    .lineLimit(1).truncationMode(.tail)
                    .frame(minWidth: 52, maxWidth: 160, alignment: .leading)
            }
            .padding(.leading, 12).padding(.trailing, 18)
            .frame(height: 36)
            .foregroundStyle(Color.primary)
            .background(BinderTabShape().fill(color.opacity(selected ? 0.30 : 0.12)))
            .overlay(BinderTabShape().stroke(color.opacity(selected ? 0.9 : 0.4), lineWidth: selected ? 1.5 : 0.75))
            .contentShape(BinderTabShape())
        }
        .buttonStyle(.plain).help(title).accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected section" : "Section")
        .contextMenu {
            Button("Rename…") { onRename(section.id) }
            Menu("Section color") {
                ForEach(SectionTabColor.palette) { choice in
                    Button { onColor(section.id, choice.hex) } label: {
                        Label(choice.name, systemImage: choice.hex == section.colorHex.uppercased() ? "checkmark" : "circle")
                    }
                }
            }
            Divider()
            Button("Move Left") { onMove(section.id, -1) }.disabled(sections.first?.id == section.id)
            Button("Move Right") { onMove(section.id, 1) }.disabled(sections.last?.id == section.id)
            Divider()
            Button("Delete Section") { onDelete(section.id) }
        }
    }
}

// Original binder-tab outline with a sloped outer corner.
private struct BinderTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = min(7, rect.width / 4, rect.height / 4)
        let slope: CGFloat = min(12, rect.width / 4)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - slope, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + slope))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
