import AppKit

@MainActor
enum ElementLayout {
    static let cellHorizontalPadding: Double = 8
    static let cellVerticalPadding: Double = 3
    static func columns(_ rows: [[String]], width: Double, saved: [Double]?) -> [Double] {
        let count = max(1, rows.first?.count ?? 1)
        let weights = saved.flatMap { $0.count == count && $0.allSatisfy({ $0.isFinite && $0 > 0 }) ? $0 : nil }
            ?? Array(repeating: 1, count: count)
        let available = max(Double(count) * 48, width)
        let extra = max(0, available - Double(count) * 48)
        let total = weights.reduce(0, +)
        return weights.map { 48 + extra * $0 / total }
    }
    // Preserve all other widths; the table grows or shrinks with this column.
    static func resizedColumn(_ widths: [Double], index: Int, translation: Double) -> [Double] {
        guard widths.indices.contains(index), translation.isFinite else { return widths }
        var result = widths
        let otherWidths = widths.reduce(0, +) - widths[index]
        let maximum = max(48.001, 100_000 - otherWidths - 8)
        result[index] = max(48.001, min(maximum, widths[index] + translation))
        return result
    }
    static func cell(_ text: String) -> NSAttributedString {
        RichTextCodec.attributed(RichTextCodec.fromMarkdown(text.isEmpty ? " " : text))
    }
    static func rows(_ rows: [[String]], columns: [Double], minimum: Double) -> [Double] {
        var heights = rows.map { row in
            row.enumerated().map { index, text in
                let width = max(1, columns[index] - 2 * cellHorizontalPadding)
                // A trailing newline creates an empty editing line too.
                let measuredText = text.hasSuffix("\n") || text.hasSuffix("\r") ? text + " " : text
                let rect = cell(measuredText).boundingRect(with: NSSize(width: width, height: 1_000_000),
                    options: [.usesLineFragmentOrigin, .usesFontLeading])
                let plain = NSAttributedString(string: measuredText.isEmpty ? " " : measuredText, attributes: [.font: NSFont.systemFont(ofSize: 14)])
                    .boundingRect(with: NSSize(width: width, height: 1_000_000), options: [.usesLineFragmentOrigin, .usesFontLeading])
                return ceil(Double(max(rect.height, plain.height))) + 2 * cellVerticalPadding
            }.max() ?? 23
        }
        let extra = max(0, minimum - heights.reduce(0, +)) / Double(max(1, heights.count))
        for i in heights.indices { heights[i] += extra }
        return heights
    }
    static func height(_ element: PageElement, editing: Bool = false) -> Double {
        if element.flowBlocks != nil {
            var copy = element
            FlowLayout.fit(&copy)
            return copy.frame.height
        }
        let minimum = element.minimumHeight ?? 0
        switch element.content {
        case .text(let text): return max(minimum, RichTextCodec.height(RichTextCodec.fromMarkdown(text), width: element.frame.width))
        case .richText(let text): return max(minimum, RichTextCodec.height(text, width: element.frame.width))
        case .table(let data):
            let widths = columns(data, width: element.frame.width - 8, saved: element.tableColumnWidths)
            return rows(data, columns: widths, minimum: 0).reduce(0, +) + 8
        default: return max(minimum, element.frame.height)
        }
    }
    static func minimumWidth(_ element: PageElement) -> Double {
        if let blocks = element.flowBlocks {
            return max(88, (blocks.map { minimumWidth($0) }.max() ?? 80) + 8)
        }
        if case .table(let rows) = element.content { return Double(rows.first?.count ?? 1) * 48 + 8 }
        return 80
    }
}

@MainActor
enum PageHeaderLayout {
    static func height(title: String, width: Double) -> Double {
        let text = NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: 28)])
        let measured = text.boundingRect(with: NSSize(width: max(1, width - 96), height: 68),
            options: [.usesLineFragmentOrigin, .usesFontLeading]).height
        let titleHeight = min(68, max(34, ceil(Double(measured))))
        // One 28-point ruled line less beneath the subtitle; reserve extra
        // space when a long title occupies its permitted second line.
        return 116 + titleHeight - 34
    }
}
