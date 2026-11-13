import Foundation
import Darwin

struct OneNoteImportReport: Codable, Sendable {
    var pages: Int
    var sections: Int
    var elements: Int
    var attachments: Int
    var warnings: [String]
}

struct OneNoteImportResult: Sendable {
    var document: NotebookDocument
    var report: OneNoteImportReport
    var reportData: Data
}

enum OneNoteImporter {
    static func load(_ source: URL) async throws -> OneNoteImportResult {
        try await Task.detached(priority: .userInitiated) { try perform(source) }.value
    }
    private static func perform(_ source: URL) throws -> OneNoteImportResult {
            let fm = FileManager.default
            guard let tool = Bundle.main.url(forResource: "one-import", withExtension: nil),
                  fm.isExecutableFile(atPath: tool.path) else {
                throw NotebookFailure.invalid("The import helper is missing. Rebuild with scripts/build-macos.sh.")
            }
            let work = fm.temporaryDirectory.appendingPathComponent("Kiyobumi-import-" + UUID().uuidString, isDirectory: true)
            try fm.createDirectory(at: work, withIntermediateDirectories: false)
            defer { try? fm.removeItem(at: work) }
            let output = work.appendingPathComponent("Imported.onbook", isDirectory: true)
            let log = work.appendingPathComponent("helper.log")
            guard fm.createFile(atPath: log.path, contents: Data()) else {
                throw NotebookFailure.invalid("Could not create the import log.")
            }
            let handle = try FileHandle(forWritingTo: log)
            defer { try? handle.close() }
            let process = Process()
            process.executableURL = tool
            process.arguments = [source.path, output.path]
            process.standardOutput = handle
            process.standardError = handle
            try process.run()
            let deadline = Date().addingTimeInterval(90)
            while process.isRunning && Date() < deadline && !Task.isCancelled { Thread.sleep(forTimeInterval: 0.1) }
            if process.isRunning {
                process.terminate()
                let grace = Date().addingTimeInterval(2)
                while process.isRunning && Date() < grace { Thread.sleep(forTimeInterval: 0.05) }
                if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit()
                throw NotebookFailure.invalid("Import stopped after its time limit or cancellation. The source and current notebook were not changed.")
            }
            guard process.terminationStatus == 0 else {
                let reader = try FileHandle(forReadingFrom: log)
                defer { try? reader.close() }
                let message = String(data: try reader.read(upToCount: 16_384) ?? Data(), encoding: .utf8) ?? "Unknown parser error."
                throw OneNoteImportFailure(details: message)
            }
            let reportData = try Data(contentsOf: output.appendingPathComponent("import-report.json"))
            let report = try JSONDecoder().decode(OneNoteImportReport.self, from: reportData)
            let document = try NotebookDocument.read(FileWrapper(url: output, options: .immediate))
            return OneNoteImportResult(document: document, report: report, reportData: reportData)
    }
}
