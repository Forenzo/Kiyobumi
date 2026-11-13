import SwiftUI
import UniformTypeIdentifiers

struct AttachmentDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data = Data()
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else { throw NotebookFailure.invalid("Unreadable attachment.") }
        data = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
