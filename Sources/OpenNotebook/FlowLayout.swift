import AppKit

struct FlowInsertion {
    let pageID: UUID
    let containerID: UUID
    let blockID: UUID
    let offset: Int
}

@MainActor
enum FlowLayout {
    static let spacing: Double = 8

    static func remove(_ id: UUID, from element: inout PageElement) {
        guard var blocks = element.flowBlocks, blocks.contains(where: { $0.id == id }) else { return }
        blocks.removeAll { $0.id == id }
        if !blocks.contains(where: { item in
            switch item.content { case .text, .richText: return true; default: return false }
        }) {
            blocks.append(PageElement(frame: .zero, content: .richText(RichTextContent())))
        }
        element.flowBlocks = blocks
        fit(&element)
    }

    static func arranged(_ element: PageElement) -> [PageElement] {
        guard let blocks = element.flowBlocks else { return [] }
        let width = max(80, element.frame.width - 8)
        var y: Double = 0
        return blocks.map { block in
            var copy = block
            copy.frame.x = 0; copy.frame.y = y
            switch block.content {
            case .table:
                // A table owns its width. Filling the paragraph width here
                // undid column shrinking and stretched it after text growth.
                copy.frame.width = max(ElementLayout.minimumWidth(block), min(width, block.frame.width))
                copy.frame.height = ElementLayout.height(copy)
            case .image:
                let fitted = min(width, max(40, block.frame.width))
                copy.frame.height = max(1, block.frame.height) * fitted / max(1, block.frame.width)
                copy.frame.width = fitted
            case .attachment:
                copy.frame.width = width; copy.frame.height = 58
            default:
                copy.frame.width = width
                copy.frame.height = ElementLayout.height(copy)
            }
            y += copy.frame.height + spacing
            return copy
        }
    }

    static func fit(_ element: inout PageElement) {
        guard element.flowBlocks != nil else { return }
        let blocks = arranged(element)
        element.frame.height = max(element.minimumHeight ?? 0,
            (blocks.last.map { $0.frame.y + $0.frame.height } ?? 0) + 8)
    }

    static func split(_ value: RichTextContent, at requested: Int) -> (RichTextContent, RichTextContent) {
        let string = value.text as NSString
        var offset = min(max(0, requested), string.length)
        // Do not split inside a composed character (emoji or combining marks).
        if offset < string.length {
            let cluster = string.rangeOfComposedCharacterSequence(at: offset)
            if cluster.location < offset { offset = cluster.location }
        }
        func part(_ range: NSRange) -> RichTextContent {
            let runs = value.runs.compactMap { run -> TextSpan? in
                let intersection = NSIntersectionRange(range, NSRange(location: run.location, length: run.length))
                guard intersection.length > 0 else { return nil }
                return TextSpan(location: intersection.location - range.location, length: intersection.length, format: run.format)
            }
            return RichTextContent(text: string.substring(with: range), runs: runs, defaultFormat: value.defaultFormat)
        }
        return (part(NSRange(location: 0, length: offset)), part(NSRange(location: offset, length: string.length - offset)))
    }

    @discardableResult
    static func insert(_ additions: [PageElement], into element: inout PageElement, blockID: UUID, offset: Int) -> Bool {
        var blocks = element.flowBlocks ?? [element]
        guard blocks.count + additions.count + 1 <= 10_000 else { return false }
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return false }
        let value: RichTextContent
        switch blocks[index].content {
        case .text(let source): value = RichTextCodec.fromMarkdown(source)
        case .richText(let rich): value = rich
        default: return false
        }
        let (before, after) = split(value, at: offset)
        var leading = blocks[index]
        // The root and its children must have distinct identities.
        if element.flowBlocks == nil { leading.id = UUID() }
        leading.content = .richText(before); leading.minimumHeight = nil
        let trailing = PageElement(frame: leading.frame, content: .richText(after))
        blocks.replaceSubrange(index...index, with: [leading] + additions + [trailing])
        element.content = .richText(RichTextContent())
        element.tableColumnWidths = nil
        element.flowBlocks = blocks
        let required = additions.map { $0.frame.width + 8 }.max() ?? 0
        element.frame.width = max(element.frame.width, required)
        fit(&element)
        return true
    }
}
