import Foundation

#if DEBUG
final class MockFileSystemService: FileSystemServiceProtocol {
    func listDirectory(at url: URL) async throws -> [FileItem] {
        return [
            FileItem(url: URL(fileURLWithPath: "/Mock/Documents"), name: "Documents", size: 0, modifiedDate: Date(), isDirectory: true, isArchive: false),
            FileItem(url: URL(fileURLWithPath: "/Mock/Downloads"), name: "Downloads", size: 0, modifiedDate: Date(), isDirectory: true, isArchive: false),
            FileItem(url: URL(fileURLWithPath: "/Mock/Photo.png"), name: "Photo.png", size: 1048576, modifiedDate: Date(), isDirectory: false, isArchive: false),
            FileItem(url: URL(fileURLWithPath: "/Mock/Backup.7z"), name: "Backup.7z", size: 50000000, modifiedDate: Date(), isDirectory: false, isArchive: true),
            FileItem(url: URL(fileURLWithPath: "/Mock/TextFile.txt"), name: "TextFile.txt", size: 1024, modifiedDate: Date(), isDirectory: false, isArchive: false)
        ]
    }
    
    func createDirectory(at url: URL) throws {}
    func openWithDefaultApp(_ url: URL) {}
    func trashItems(_ urls: [URL]) throws {}
    func copyItems(_ urls: [URL], to destination: URL) throws {}
    func moveItems(_ urls: [URL], to destination: URL) throws {}
    
    var homeDirectory: URL { URL(fileURLWithPath: "/Mock") }
    var desktopDirectory: URL { URL(fileURLWithPath: "/Mock/Desktop") }
    var downloadsDirectory: URL { URL(fileURLWithPath: "/Mock/Downloads") }
    var documentsDirectory: URL { URL(fileURLWithPath: "/Mock/Documents") }
}

@MainActor
final class MockFileDialogService: FileDialogServiceProtocol {
    func chooseExtractionDestination() -> URL? { return nil }
    func chooseArchiveDestination(defaultFileName: String) -> URL? { return nil }
}
#endif
