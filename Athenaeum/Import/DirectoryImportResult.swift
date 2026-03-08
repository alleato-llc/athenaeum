import Foundation

public struct SkippedFile: Identifiable {
    public let id = UUID()
    public let filename: String
    public let fileExtension: String
    public let path: String
}

public struct FailedImport: Identifiable {
    public let id = UUID()
    public let filename: String
    public let reason: String
}

public struct DirectoryImportResult: Identifiable {
    public let id = UUID()
    public let importedCount: Int
    public let skippedFiles: [SkippedFile]
    public let failedImports: [FailedImport]
}
