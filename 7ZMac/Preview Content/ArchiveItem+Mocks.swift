import Foundation

/// Mock data for SwiftUI Previews.
extension ArchiveItem {
    static var mocks: [ArchiveItem] {
        [
            ArchiveItem(path: "Documents/Project/Manual.pdf", size: "2.4 MB", packedSize: "1.8 MB", modified: "2024-03-10 14:30", attributes: "-rw-r--r--", isFolder: false),
            ArchiveItem(path: "Documents/Project/Images", size: "0 B", packedSize: "0 B", modified: "2024-03-10 14:28", attributes: "drwxr-xr-x", isFolder: true),
            ArchiveItem(path: "Documents/Project/Source.swift", size: "12 KB", packedSize: "4 KB", modified: "2024-03-09 09:15", attributes: "-rw-r--r--", isFolder: false),
            ArchiveItem(path: "Readme.txt", size: "450 B", packedSize: "200 B", modified: "2024-03-01 10:00", attributes: "-rw-r--r--", isFolder: false),
        ]
    }
}

/// Mock data for filesystem items.
extension FileItem {
    static var mocks: [FileItem] {
        [
            FileItem(url: URL(fileURLWithPath: "/Users/test/Documents"), name: "Documents", size: 0, modifiedDate: Date(), isDirectory: true, isArchive: false),
            FileItem(url: URL(fileURLWithPath: "/Users/test/Downloads"), name: "Downloads", size: 0, modifiedDate: Date(), isDirectory: true, isArchive: false),
            FileItem(url: URL(fileURLWithPath: "/Users/test/archive.7z"), name: "archive.7z", size: 1024 * 1024, modifiedDate: Date(), isDirectory: false, isArchive: true),
            FileItem(url: URL(fileURLWithPath: "/Users/test/report.pdf"), name: "report.pdf", size: 524288, modifiedDate: Date(), isDirectory: false, isArchive: false),
            FileItem(url: URL(fileURLWithPath: "/Users/test/photo.jpg"), name: "photo.jpg", size: 2097152, modifiedDate: Date(), isDirectory: false, isArchive: false),
            FileItem(url: URL(fileURLWithPath: "/Users/test/presentation.docx"), name: "presentation.docx", size: 348160, modifiedDate: Date(), isDirectory: false, isArchive: false),
        ]
    }
}

/// Mock service that returns predictable data for previews and tests.
final class MockArchiveService: ArchiveServiceProtocol {
    var mockItems: [ArchiveItem] = ArchiveItem.mocks
    var shouldThrow: Bool = false
    var extractedArchives: [(archive: URL, destination: URL)] = []
    var compressedArchives: [(files: [URL], archive: URL)] = []
    var onExtract: ((URL, URL) -> Void)?
    var onCompress: (([URL], URL) -> Void)?
    
    func listContents(archive: URL) async throws -> [ArchiveItem] {
        if shouldThrow { throw SevenZipError.executableNotFound }
        return mockItems
    }
    
    func extract(archive: URL, to destination: URL) async throws {
        if shouldThrow { throw SevenZipError.executableNotFound }
        extractedArchives.append((archive, destination))
        onExtract?(archive, destination)
    }
    
    func compress(files: [URL], to archive: URL) async throws {
        if shouldThrow { throw SevenZipError.executableNotFound }
        compressedArchives.append((files, archive))
        onCompress?(files, archive)
    }
    
    func compress(files: [URL], to archive: URL, options: CompressionOptions) async throws {
        if shouldThrow { throw SevenZipError.executableNotFound }
    }
    
    func checkAvailability() -> Bool { !shouldThrow }
}
