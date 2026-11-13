import Foundation

// Run only for editor-driven growth, never for dragging or opening a page.
enum ContentFlow {
    static let gap: Double = 12

    static func pushBelow(in elements: inout [PageElement], changedID: UUID, previous: Frame) {
        guard let source = elements.firstIndex(where: { $0.id == changedID }),
              elements[source].isText else { return }
        let grown = elements[source].frame
        guard grown.x == previous.x, grown.y == previous.y,
              grown.height > previous.height + 0.5 || grown.width > previous.width + 0.5 else { return }

        // Original vertical order makes propagation deterministic and prevents
        // cycles. Side-by-side boxes remain independent. Ink has absolute page
        // coordinates and is deliberately left in place.
        let original = elements.map(\.frame)
        let order = elements.indices.filter { index in
            guard index != source, original[index].y > previous.y else { return false }
            if case .ink = elements[index].content { return false }
            return true
        }.sorted {
            original[$0].y == original[$1].y ? $0 < $1 : original[$0].y < original[$1].y
        }
        var movers = [source]
        for index in order {
            let candidate = original[index]
            var y = candidate.y
            for mover in movers where original[mover].y < candidate.y {
                let obstacle = elements[mover].frame
                let overlaps = candidate.x < obstacle.x + obstacle.width &&
                    candidate.x + candidate.width > obstacle.x
                if overlaps { y = max(y, obstacle.y + obstacle.height + gap) }
            }
            if y > candidate.y {
                elements[index].frame.y = y
                movers.append(index)
            }
        }
    }
}
