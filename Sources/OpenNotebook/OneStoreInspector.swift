import Foundation
import COneStore

enum OneStoreInspector {
    static func inspect(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        try handle.seek(toOffset: 0)
        let header = try handle.read(upToCount: 1024) ?? Data()
        let status = header.withUnsafeBytes { bytes in
            onestore_probe(bytes.bindMemory(to: UInt8.self).baseAddress, header.count, size)
        }
        switch status {
        case 0: return "Recognized a modern OneNote section header. Use Import OneNote to convert its contents. The source file has not been changed."
        case 1: return "The file is too short to contain a OneNote revision-store header."
        case 2: return "This is not a supported .one section file. Notebook tables of contents and .onepkg archives need separate readers."
        case 3: return "This OneNote format or version is not supported by this header checker."
        default: return "The header could not be recognized because file lengths or references are inconsistent."
        }
    }
}
