import XCTest
@testable import _ZMac

@MainActor
final class ArchiveViewModelTests: XCTestCase {
    
    private var mockService: MockArchiveService!
    private var mockFileSystemService: MockFileSystemService!
    private var mockDialogService: MockFileDialogService!
    private var container: DIContainer!
    
    override func setUp() {
        super.setUp()
        container = DIContainer.shared
        container.reset()
        mockService = MockArchiveService()
        mockFileSystemService = MockFileSystemService()
        mockDialogService = MockFileDialogService()
        container.register(ArchiveServiceProtocol.self) { [unowned self] in self.mockService }
        container.register(FileSystemServiceProtocol.self) { [unowned self] in self.mockFileSystemService }
        container.register(FileDialogServiceProtocol.self) { [unowned self] in self.mockDialogService }
    }
    
    override func tearDown() {
        container.reset()
        mockService = nil
        mockFileSystemService = nil
        mockDialogService = nil
        container = nil
        super.tearDown()
    }
    
    // MARK: - Service via Container
    
    func testResolvedServiceReturnsMockData() async {
        let service: ArchiveServiceProtocol = container.resolve()
        let items = try? await service.listContents(archive: URL(fileURLWithPath: "/tmp/test.7z"))
        
        XCTAssertNotNil(items)
        XCTAssertEqual(items?.count, ArchiveItem.mocks.count)
    }
    
    // MARK: - Error Handling
    
    func testServiceThrowsError() async {
        mockService.shouldThrow = true
        
        do {
            let service: ArchiveServiceProtocol = container.resolve()
            _ = try await service.listContents(archive: URL(fileURLWithPath: "/tmp/test.7z"))
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is SevenZipError)
        }
    }
    
    // MARK: - Availability
    
    func testServiceAvailability() {
        let service: ArchiveServiceProtocol = container.resolve()
        XCTAssertTrue(service.checkAvailability())
    }
    
    // MARK: - Compress with Options
    
    func testCompressWithOptionsMock() async {
        let service: ArchiveServiceProtocol = container.resolve()
        let options = CompressionOptions()
        
        do {
            try await service.compress(
                files: [URL(fileURLWithPath: "/tmp/test.txt")],
                to: URL(fileURLWithPath: "/tmp/test.7z"),
                options: options
            )
        } catch {
            XCTFail("Mock compress should not throw: \(error)")
        }
    }
    
    func testCompressWithOptionsThrows() async {
        mockService.shouldThrow = true
        let service: ArchiveServiceProtocol = container.resolve()
        let options = CompressionOptions()
        
        do {
            try await service.compress(
                files: [URL(fileURLWithPath: "/tmp/test.txt")],
                to: URL(fileURLWithPath: "/tmp/test.7z"),
                options: options
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is SevenZipError)
        }
    }

    // MARK: - ViewModel Dialog Integration

    func testExtractArchiveUsesDialogServiceDestination() async {
        let archiveURL = URL(fileURLWithPath: "/tmp/archive.7z")
        let destinationURL = URL(fileURLWithPath: "/tmp/extracted")
        let extractExpectation = expectation(description: "extract called")

        mockDialogService.extractionDestination = destinationURL
        mockService.onExtract = { archive, destination in
            XCTAssertEqual(archive, archiveURL)
            XCTAssertEqual(destination, destinationURL)
            extractExpectation.fulfill()
        }

        let viewModel = FileManagerViewModel(container: container)
        viewModel.navigationMode = .archive(url: archiveURL)

        viewModel.extractArchive()

        await fulfillment(of: [extractExpectation], timeout: 1.0)
        XCTAssertEqual(mockService.extractedArchives.first?.archive, archiveURL)
        XCTAssertEqual(mockService.extractedArchives.first?.destination, destinationURL)
        XCTAssertEqual(mockFileSystemService.openedURLs.last, destinationURL)
    }

    func testCompressFilesUsesDialogServiceDestination() async {
        let sourceFile = FileItem(
            url: URL(fileURLWithPath: "/tmp/document.txt"),
            name: "document.txt",
            size: 128,
            modifiedDate: Date(),
            isDirectory: false,
            isArchive: false
        )
        let destinationURL = URL(fileURLWithPath: "/tmp/archive.7z")

        mockDialogService.archiveDestination = destinationURL

        let viewModel = FileManagerViewModel(container: container)
        viewModel.fileItems = [sourceFile]
        viewModel.selectedFileIDs = [sourceFile.id]

        viewModel.compressFiles()

        for _ in 0..<20 where mockService.compressedArchives.isEmpty {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(mockService.compressedArchives.first?.files, [sourceFile.url])
        XCTAssertEqual(mockService.compressedArchives.first?.archive, destinationURL)
    }
}

private final class MockFileSystemService: FileSystemServiceProtocol {
    var directoryItems: [FileItem] = []
    var openedURLs: [URL] = []
    var createdDirectories: [URL] = []

    func listDirectory(at url: URL) throws -> [FileItem] {
        directoryItems
    }

    func createDirectory(at url: URL) throws {
        createdDirectories.append(url)
    }

    func openWithDefaultApp(_ url: URL) {
        openedURLs.append(url)
    }

    func trashItems(_ urls: [URL]) throws {}

    func copyItems(_ urls: [URL], to destination: URL) throws {}

    func moveItems(_ urls: [URL], to destination: URL) throws {}

    var homeDirectory: URL { URL(fileURLWithPath: "/Users/test") }
    var desktopDirectory: URL { URL(fileURLWithPath: "/Users/test/Desktop") }
    var downloadsDirectory: URL { URL(fileURLWithPath: "/Users/test/Downloads") }
    var documentsDirectory: URL { URL(fileURLWithPath: "/Users/test/Documents") }
}

@MainActor
private final class MockFileDialogService: FileDialogServiceProtocol {
    var extractionDestination: URL?
    var archiveDestination: URL?

    func chooseExtractionDestination() -> URL? {
        extractionDestination
    }

    func chooseArchiveDestination(defaultFileName: String) -> URL? {
        archiveDestination
    }
}
