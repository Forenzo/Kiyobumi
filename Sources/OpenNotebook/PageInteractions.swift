import Foundation

enum PageZoom {
    static func clamped(_ value: CGFloat) -> CGFloat {
        value.isFinite ? min(4, max(0.1, value)) : 1
    }
    static func magnified(from start: CGFloat, by factor: CGFloat) -> CGFloat {
        guard factor.isFinite, factor > 0 else { return clamped(start) }
        return clamped(start * factor)
    }
}
enum PageHierarchy {
    static func subpageInsertionIndex(after id: UUID, in section: Section, pages: [UUID: Page]) -> Int? {
        guard let parent = pages[id], parent.level < 2,
              let index = section.pageIDs.firstIndex(of: id) else { return nil }
        var insertion = index + 1
        while insertion < section.pageIDs.count,
              let next = pages[section.pageIDs[insertion]], next.level > parent.level {
            insertion += 1
        }
        return insertion
    }
}
