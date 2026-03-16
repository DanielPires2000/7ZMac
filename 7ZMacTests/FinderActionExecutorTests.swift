import XCTest
@testable import _ZMac

@MainActor
final class FinderActionExecutorTests: XCTestCase {
    private var windowManager: MockExecutorWindowManager!
    private var archiveService: MockArchiveService!
    private var fileSystemService: MockExecutorFileSystemService!
    private var notifications: [AppNotificationContent]!
    private var executor: FinderActionExecutor!

    override func setUp() {
        super.setUp()
        windowManager = MockExecutorWindowManager()
        archiveService = MockArchiveService()
        fileSystemService = MockExecutorFileSystemService()
        notifications = []
        executor = FinderActionExecutor(
            windowManager: windowManager,
            archiveService: archiveService,
            fileSystemService: fileSystemService,
            notificationSink: { [weak self] title, message in
                self?.notifications.append(AppNotificationContent(title: title, message: message))
            }
        )
    }

    override func tearDown() {
        executor = nil
        notifications = nil
        fileSystemService = nil
        archiveService = nil
        windowManager = nil
        super.tearDown()
    }

    func testExecuteCompress7zShowsProgressWindow() async {
        let request = FinderActionRequest(action: .compress7z, filePaths: ["/tmp/a.txt", "/tmp/b.txt"])

        await executor.execute(request)

        XCTAssertEqual(windowManager.progressWindows.first?.title, "a.7z")
        XCTAssertEqual(windowManager.progressWindows.first?.arguments, ["a", "-t7z", "/tmp/a.7z", "/tmp/a.txt", "/tmp/b.txt"])
    }

    func testExecuteExtractHereExtractsAndNotifies() async {
        let request = FinderActionRequest(action: .extractHere, filePaths: ["/tmp/archive.7z"])

        await executor.execute(request)

        XCTAssertEqual(archiveService.extractedArchives.first?.archive.path, "/tmp/archive.7z")
        XCTAssertEqual(archiveService.extractedArchives.first?.destination.path, "/tmp")
        XCTAssertEqual(notifications.first, AppNotificationContent(title: "7ZMac", message: "Extracted archive.7z"))
    }

    func testExecuteExtractToSubfolderCreatesDirectoryAndNotifies() async {
        let request = FinderActionRequest(action: .extractToSubfolder, filePaths: ["/tmp/archive.7z"])

        await executor.execute(request)

        XCTAssertEqual(fileSystemService.createdDirectories, [URL(fileURLWithPath: "/tmp/archive")])
        XCTAssertEqual(archiveService.extractedArchives.first?.destination.path, "/tmp/archive")
        XCTAssertEqual(notifications.first, AppNotificationContent(title: "7ZMac", message: "Extracted to archive/"))
    }

    func testExecuteTestArchiveListsAndNotifies() async {
        archiveService.mockItems = [.init(path: "a", size: "1", packedSize: "1", modified: "now", attributes: "-", isFolder: false)]
        let request = FinderActionRequest(action: .testArchive, filePaths: ["/tmp/archive.7z"])

        await executor.execute(request)

        XCTAssertEqual(notifications.first, AppNotificationContent(title: "7ZMac", message: "archive.7z: OK ✓ (1 items)"))
    }

    func testExecuteFailureNotifiesError() async {
        archiveService.shouldThrow = true
        let request = FinderActionRequest(action: .extractHere, filePaths: ["/tmp/archive.7z"])

        await executor.execute(request)

        XCTAssertEqual(notifications.first?.title, "7ZMac — Error")
        XCTAssertEqual(notifications.first?.message, SevenZipError.executableNotFound.localizedDescription)
    }

    func testExtractToDestinationExtractsAndNotifies() async {
        let destination = URL(fileURLWithPath: "/tmp/out")

        await executor.extract(files: [URL(fileURLWithPath: "/tmp/archive.7z")], to: destination)

        XCTAssertEqual(archiveService.extractedArchives.first?.archive.path, "/tmp/archive.7z")
        XCTAssertEqual(archiveService.extractedArchives.first?.destination, destination)
        XCTAssertEqual(notifications.first, AppNotificationContent(title: "7ZMac", message: "Extracted archive.7z"))
    }
}

@MainActor
private final class MockExecutorWindowManager: WindowManaging {
    var progressWindows: [(title: String, arguments: [String])] = []

    func showAddToArchiveDialog(
        filePaths: [String],
        onCompress: @escaping (String, CompressionOptions) -> Void
    ) {}

    func showProgressWindow(title: String, arguments: [String]) {
        progressWindows.append((title, arguments))
    }
}

private final class MockExecutorFileSystemService: FileSystemServiceProtocol {
    var createdDirectories: [URL] = []

    func listDirectory(at url: URL) throws -> [FileItem] { [] }
    func createDirectory(at url: URL) throws { createdDirectories.append(url) }
    func openWithDefaultApp(_ url: URL) {}
    func trashItems(_ urls: [URL]) throws {}
    func copyItems(_ urls: [URL], to destination: URL) throws {}
    func moveItems(_ urls: [URL], to destination: URL) throws {}

    var homeDirectory: URL { URL(fileURLWithPath: "/Users/test") }
    var desktopDirectory: URL { URL(fileURLWithPath: "/Users/test/Desktop") }
    var downloadsDirectory: URL { URL(fileURLWithPath: "/Users/test/Downloads") }
    var documentsDirectory: URL { URL(fileURLWithPath: "/Users/test/Documents") }
}