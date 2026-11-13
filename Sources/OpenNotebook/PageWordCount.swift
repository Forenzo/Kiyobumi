import SwiftUI
import Foundation
import NaturalLanguage

enum PageWordCount {
    static func text(page: Page?, subtitle: String) -> String {
        guard let page else { return "" }
        let body = page.elements.flatMap { $0.flowBlocks ?? [$0] }.map { element -> String in
            switch element.content {
            case .text(let markdown):
                if let parsed = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    return String(parsed.characters)
                }
                return markdown
            case .richText(let value): return value.text
            case .table(let rows): return rows.flatMap { $0 }.joined(separator: "\n")
            default: return ""
            }
        }
        return ([page.title, subtitle] + body).joined(separator: "\n")
    }

    static func count(_ text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if text[range].unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) {
                count += 1
            }
            return true
        }
        return count
    }
}

struct PageWordCountView: View {
    let page: Page?
    let subtitle: String
    @KiyobumiState private var words = 0

    var body: some View {
        let text = PageWordCount.text(page: page, subtitle: subtitle)
        Text(words == 1 ? "1 word" : "\(words) words")
            .font(.callout).monospacedDigit().foregroundStyle(.secondary)
            .accessibilityLabel("Current page: \(words) words")
            .help("Words in the page title, subtitle, text boxes and table cells. Images, printouts, handwriting and attachments are not counted.")
            .task(id: text) {
                // Coalesce keystrokes; no counter is written into the notebook.
                do { try await Task.sleep(nanoseconds: 150_000_000) }
                catch { return }
                words = PageWordCount.count(text)
            }
    }
}
