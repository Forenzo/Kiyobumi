import Foundation

/// Immutable value snapshots are safe to send to document serialization.
/// FileWrapper itself is mutable and is never stored in the Sendable document.
indirect enum StoredFile: Equatable, Sendable {
    case data(Data)
    case directory([String: StoredFile])

    init(snapshot wrapper: FileWrapper) throws {
        if wrapper.isRegularFile, let data = wrapper.regularFileContents { self = .data(data) }
        else if wrapper.isDirectory, let children = wrapper.fileWrappers {
            self = .directory(try children.mapValues { try StoredFile(snapshot: $0) })
        } else { throw NotebookFailure.invalid("Symbolic links and unreadable ancillary files are not supported.") }
    }
    var regularFileContents: Data? { if case .data(let bytes) = self { return bytes }; return nil }
    var isRegularFile: Bool { regularFileContents != nil }
    func wrapper() -> FileWrapper {
        switch self {
        case .data(let bytes): return FileWrapper(regularFileWithContents: bytes)
        case .directory(let children): return FileWrapper(directoryWithFileWrappers: children.mapValues { $0.wrapper() })
        }
    }
}
