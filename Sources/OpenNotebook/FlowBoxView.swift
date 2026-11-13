import SwiftUI
import AppKit

@MainActor
struct FlowBoxView: View {
    @Binding var element: PageElement
    let editing: Bool
    let tools: TextTools
    let onRequestEditing: () -> Void
    let onDoneEditing: () -> Void
    let mediaLookup: (PageElement) -> Data?
    let saveAttachment: (PageElement) -> Void
    @KiyobumiState private var activeID: UUID?
    @KiyobumiState private var blockSelected = false
    @KiyobumiState private var selectionToken = UUID()

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(FlowLayout.arranged(element)) { block in
                // Type erasure breaks the recursive View type; the document
                // validator only permits one level of block containment.
                AnyView(ElementView(element: binding(block), imageData: mediaLookup(block),
                    isSelected: editing && activeID == block.id,
                    isEditing: editing && activeID == block.id && !blockSelected,
                    onDoneEditing: { selectBlock(block) },
                    onSaveAttachment: { saveAttachment(block) }, textTools: tools,
                    onMove: { _ in }, onMoveEnd: {},
                    onRequestEditing: { activeID = block.id; blockSelected = false; onRequestEditing() },
                    embedded: true))
                    .contextMenu { blockMenu(block) }
                    .overlay(alignment: .topLeading) {
                        EmbeddedBlockSelectionBorder(width: block.frame.width, height: block.frame.height,
                            includeRightEdge: !(editing && activeID == block.id && !blockSelected),
                            onSelect: { selectBlock(block) })
                    }
                    .overlay(alignment: .topTrailing) {
                        if editing {
                            Menu { blockMenu(block) } label: { Image(systemName: "ellipsis.circle") }
                                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                                .frame(width: 20, height: 20).offset(x: 22)
                                .help("Options for this block")
                        }
                    }
                    .offset(x: block.frame.x, y: block.frame.y)
            }
        }
        .frame(width: max(0, element.frame.width - 8), height: max(0, element.frame.height - 8), alignment: .topLeading)
        .background(CanvasKeyboard(canDelete: editing && blockSelected && activeID != nil,
            selectionToken: editing && blockSelected ? selectionToken : nil, onDelete: {
            if let id = activeID { removeBlock(id) }
        }))
        .onChange(of: editing) { active in
            if !active { blockSelected = false; activeID = nil }
        }
    }

    private func selectBlock(_ block: PageElement) {
        tools.finish()
        tools.canvasView?.window?.makeFirstResponder(nil)
        activeID = block.id; blockSelected = true
        selectionToken = UUID()
        onRequestEditing()
    }

    private func removeBlock(_ id: UUID) {
        tools.finish()
        tools.canvasView?.window?.makeFirstResponder(nil)
        var copy = element
        FlowLayout.remove(id, from: &copy)
        element = copy; activeID = nil; blockSelected = false
    }

    private func binding(_ block: PageElement) -> Binding<PageElement> {
        Binding(get: { FlowLayout.arranged(element).first { $0.id == block.id } ?? block }, set: { updated in
            guard var blocks = element.flowBlocks, let index = blocks.firstIndex(where: { $0.id == updated.id }) else { return }
            blocks[index] = updated
            var copy = element
            copy.flowBlocks = blocks
            copy.frame.width = max(ElementLayout.minimumWidth(copy), max(copy.frame.width, updated.frame.width + 8))
            FlowLayout.fit(&copy)
            if copy != element { element = copy }
        })
    }

    @ViewBuilder private func blockMenu(_ block: PageElement) -> some View {
        Button("Select block") { selectBlock(block) }
        if case .table(let rows) = block.content {
            Button("Add row") {
                var copy = block
                copy.content = .table(rows: rows + [Array(repeating: "", count: rows.first?.count ?? 1)])
                binding(block).wrappedValue = copy
            }.disabled(rows.count >= 1000 || (rows.count + 1) * (rows.first?.count ?? 1) > 20_000)
            Button("Add column") {
                var copy = block
                copy.content = .table(rows: rows.map { $0 + [""] })
                let widths = ElementLayout.columns(rows, width: block.frame.width - 8, saved: block.tableColumnWidths) + [160]
                copy.tableColumnWidths = widths.map { max(0.001, $0 - 48) }
                copy.frame.width = widths.reduce(0, +) + 8
                binding(block).wrappedValue = copy
            }.disabled((rows.first?.count ?? 0) >= 100 || rows.count * ((rows.first?.count ?? 0) + 1) > 20_000)
            Button("Remove last row") {
                var copy = block; copy.content = .table(rows: Array(rows.dropLast())); copy.trimCellColors()
                binding(block).wrappedValue = copy
            }.disabled(rows.count <= 1)
            Button("Remove last column") {
                var copy = block; copy.content = .table(rows: rows.map { Array($0.dropLast()) }); copy.trimCellColors()
                let widths = Array(ElementLayout.columns(rows, width: block.frame.width - 8, saved: block.tableColumnWidths).dropLast())
                copy.tableColumnWidths = widths.map { max(0.001, $0 - 48) }
                copy.frame.width = widths.reduce(0, +) + 8
                binding(block).wrappedValue = copy
            }.disabled((rows.first?.count ?? 0) <= 1)
        }
        if case .image = block.content {
            Button("Smaller image") { scaleImage(block, factor: 0.8) }
            Button("Larger image") { scaleImage(block, factor: 1.25) }
        }
        if case .attachment = block.content {
            Button("Save attachment…") { saveAttachment(block) }
        }
        Button("Remove this block", role: .destructive) {
            removeBlock(block.id)
        }
    }

    private func scaleImage(_ block: PageElement, factor: Double) {
        var copy = block
        let width = min(4000, max(40, copy.frame.width * factor))
        copy.frame.height *= width / max(1, copy.frame.width)
        copy.frame.width = width
        binding(block).wrappedValue = copy
    }
}

// Only the perimeter selects the object. The cell/text interior still starts
// editing on the first click; table dividers retain their resize hit targets.
private struct EmbeddedBlockSelectionBorder: View {
    let width: Double
    let height: Double
    let includeRightEdge: Bool
    let onSelect: () -> Void
    var body: some View {
        ZStack(alignment: .topLeading) {
            edge(width: width, height: 3)
            edge(width: width, height: 3).offset(y: max(0, height - 3))
            edge(width: 3, height: max(0, height - 6)).offset(y: 3)
            if includeRightEdge {
                edge(width: 3, height: max(0, height - 6)).offset(x: max(0, width - 3), y: 3)
            }
        }.frame(width: width, height: height, alignment: .topLeading)
    }
    private func edge(width: Double, height: Double) -> some View {
        Color.clear.frame(width: width, height: height).contentShape(Rectangle())
            .help("Click border to select block, then press Delete to remove it")
            .highPriorityGesture(TapGesture().onEnded { _ in onSelect() })
    }
}
