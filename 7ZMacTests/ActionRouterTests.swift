import XCTest
@testable import _ZMac

@MainActor
final class ActionRouterTests: XCTestCase {

    private static var retainedRouters: [ActionRouter] = []

    private var mockWindowManager: MockWindowManager!
    private var mockDialogService: MockFileDialogService!
    private var actionExecutor: FinderActionExecutor!
    private var mockArchiveService: MockArchiveService!
    private var mockFileSystemService: MockFileSystemService!
    private var mockNotificationService: MockNotificationService!
    private var activationCount: Int!

    override func setUp() {
        super.setUp()
        mockWindowManager = MockWindowManager()
        mockDialogService = MockFileDialogService()
        mockArchiveService = MockArchiveService()
        mockFileSystemService = MockFileSystemService()
        mockNotificationService = MockNotificationService()
        actionExecutor = FinderActionExecutor(
            windowManager: mockWindowManager,
            archiveService: mockArchiveService,
            fileSystemService: mockFileSystemService,
            notificationSink: { [weak mockNotificationService] title, message in
                mockNotificationService?.showNotification(title: title, message: message)
            }
        )
        activationCount = 0
    }

    override func tearDown() {
        mockWindowManager = nil
        mockDialogService = nil
        actionExecutor = nil
        mockArchiveService = nil
        mockFileSystemService = nil
        mockNotificationService = nil
        activationCount = nil
        super.tearDown()
    }

    func testShowNotificationDelegatesToNotificationService() {
        let router = makeRouter()

        router.showNotification(title: "7ZMac", message: "Done")

        XCTAssertEqual(mockNotificationService.notifications.first?.title, "7ZMac")
        XCTAssertEqual(mockNotificationService.notifications.first?.message, "Done")
    }

    func testHandleFinderActionCompress7zShowsProgressWindow() async {
        let router = makeRouter()
        let filePaths = ["/tmp/a.txt", "/tmp/b.txt"]

        router.handleFinderAction(url: makeActionURL(action: "compress7z", paths: filePaths))

        for _ in 0..<20 where mockWindowManager.progressWindows.isEmpty {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(mockWindowManager.progressWindows.first?.title, "a.7z")
        XCTAssertEqual(mockWindowManager.progressWindows.first?.arguments.prefix(3), ["a", "-t7z", "/tmp/a.7z"])
    }

    func testHandleFinderActionCompressZipShowsProgressWindow() async {
        let router = makeRouter()
        let filePaths = ["/tmp/a.txt", "/tmp/b.txt"]

        router.handleFinderAction(url: makeActionURL(action: "compressZip", paths: filePaths))

        for _ in 0..<20 where mockWindowManager.progressWindows.isEmpty {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(mockWindowManager.progressWindows.first?.title, "a.zip")
        XCTAssertEqual(mockWindowManager.progressWindows.first?.arguments.prefix(3), ["a", "-tzip", "/tmp/a.zip"])
    }

    func testHandleFinderActionExtractFilesUsesDialogServiceAndActivatesApp() async {
        let router = makeRouter()
        let archiveURL = URL(fileURLWithPath: "/tmp/archive.7z")
        let destinationURL = URL(fileURLWithPath: "/tmp/extracted")

        mockDialogService.extractionDestination = destinationURL

        router.handleFinderAction(url: makeActionURL(action: "extractFiles", paths: [archiveURL.path]))

        for _ in 0..<20 where mockArchiveService.extractedArchives.isEmpty {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(activationCount, 1)
        XCTAssertEqual(mockArchiveService.extractedArchives.first?.archive, archiveURL)
        XCTAssertEqual(mockArchiveService.extractedArchives.first?.destination, destinationURL)
    }

    func testHandleFinderActionExtractToSubfolderCreatesDestination() async {
        let router = makeRouter()
        let archiveURL = URL(fileURLWithPath: "/tmp/archive.7z")

        router.handleFinderAction(url: makeActionURL(action: "extractToSubfolder", paths: [archiveURL.path]))

        for _ in 0..<20 where mockArchiveService.extractedArchives.isEmpty {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        let expectedDestination = URL(fileURLWithPath: "/tmp/archive")
        XCTAssertEqual(mockFileSystemService.createdDirectories, [expectedDestination])
        XCTAssertEqual(mockArchiveService.extractedArchives.first?.destination, expectedDestination)
    }

    func testFinderActionRequestParsesValidURL() {
        let url = makeActionURL(action: "compressZip", paths: ["/tmp/a.txt", "/tmp/b.txt"])

        let request = FinderActionRequest(url: url)

        XCTAssertEqual(request?.action, .compressZip)
        XCTAssertEqual(request?.filePaths, ["/tmp/a.txt", "/tmp/b.txt"])
        XCTAssertEqual(request?.fileURLs.map(\.path), ["/tmp/a.txt", "/tmp/b.txt"])
    }

    func testFinderActionRequestRejectsUnknownAction() {
        let url = makeActionURL(action: "unknownAction", paths: ["/tmp/a.txt"])

        XCTAssertNil(FinderActionRequest(url: url))
    }

    func testFinderActionRequestRejectsMissingPathsParameter() {
        let url = URL(string: "sevenzma://compress7z")!

        XCTAssertNil(FinderActionRequest(url: url))
    }

    private func makeRouter() -> ActionRouter {
        let router = ActionRouter(
            windowManager: mockWindowManager,
            dialogService: mockDialogService,
            actionExecutor: actionExecutor,
            activateApp: { [self] in
                activationCount += 1
            },
            notificationSink: { [mockNotificationService] title, message in
                mockNotificationService?.showNotification(title: title, message: message)
            }
        )
        Self.retainedRouters.append(router)
        return router
    }

    private func makeActionURL(action: String, paths: [String]) -> URL {
        let jsonData = try! JSONSerialization.data(withJSONObject: paths)
        let base64 = jsonData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        return URL(string: "sevenzma://\(action)?paths=\(base64)")!
    }
}

@MainActor
private final class MockWindowManager: WindowManaging {
    var capturedAddToArchivePaths: [String]?
    var progressWindows: [(title: String, arguments: [String])] = []

    func showAddToArchiveDialog(
        filePaths: [String],
        onCompress: @escaping (String, CompressionOptions) -> Void
    ) {
        capturedAddToArchivePaths = filePaths
    }

    func showProgressWindow(title: String, arguments: [String]) {
        progressWindows.append((title, arguments))
    }
}

@MainActor
private final class MockNotificationService: NotificationServiceProtocol {
    var notifications: [(title: String, message: String)] = []

    func showNotification(title: String, message: String) {
        notifications.append((title, message))
    }
}

private final class MockFileSystemService: FileSystemServiceProtocol {
    var createdDirectories: [URL] = []

    func listDirectory(at url: URL) throws -> [FileItem] {
        []
    }

    func createDirectory(at url: URL) throws {
        createdDirectories.append(url)
    }

    func openWithDefaultApp(_ url: URL) {}

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