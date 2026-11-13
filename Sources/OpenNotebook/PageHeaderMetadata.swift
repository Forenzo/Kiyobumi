import Foundation

// Ancillary storage preserves compatibility with existing schema-3 clients.
struct PageHeaderMetadata: Codable, Equatable, Sendable {
    static let fileName = "kiyobumi-page-headers.json"
    var format = "org.kiyobumi.page-headers"
    var version = 1
    var subheaders: [String: String] = [:]
    static func read(_ file: StoredFile?) throws -> Self {
        guard let file = file else { return Self() }
        guard let data = file.regularFileContents else {
            throw NotebookFailure.invalid("The saved subheader metadata is not a regular file. It was not changed.")
        }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              Set(object.keys).isSubset(of: ["format", "version", "subheaders"]),
              let result = try? JSONDecoder().decode(Self.self, from: data) else {
            throw NotebookFailure.invalid("The saved subheaders could not be read. Their data was not changed.")
        }
        guard result.format == "org.kiyobumi.page-headers", result.version == 1,
              result.subheaders.keys.allSatisfy({ UUID(uuidString: $0)?.uuidString.lowercased() == $0 }) else {
            throw NotebookFailure.invalid("The saved subheaders use an unsupported format. Their data was not changed.")
        }
        return result
    }
    func text(for id: UUID) -> String { subheaders[id.uuidString.lowercased()] ?? "" }
    mutating func set(_ text: String, for id: UUID) {
        let key = id.uuidString.lowercased()
        if text.isEmpty { subheaders.removeValue(forKey: key) } else { subheaders[key] = text }
    }
    mutating func remove(_ ids: [UUID]) {
        for id in ids { subheaders.removeValue(forKey: id.uuidString.lowercased()) }
    }
    func storedFile() throws -> StoredFile {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return .data(try encoder.encode(self))
    }
}
