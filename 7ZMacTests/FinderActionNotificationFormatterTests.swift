import XCTest
@testable import _ZMac

final class FinderActionNotificationFormatterTests: XCTestCase {
    func testExtractionCompletedMessage() {
        let content = FinderActionNotificationFormatter.extractionCompleted(archiveName: "archive.7z")

        XCTAssertEqual(content, AppNotificationContent(title: "7ZMac", message: "Extracted archive.7z"))
    }

    func testExtractionCompletedToFolderMessage() {
        let content = FinderActionNotificationFormatter.extractionCompleted(toFolder: "archive")

        XCTAssertEqual(content, AppNotificationContent(title: "7ZMac", message: "Extracted to archive/"))
    }

    func testArchiveTestPassedMessage() {
        let content = FinderActionNotificationFormatter.archiveTestPassed(archiveName: "archive.7z", itemCount: 4)

        XCTAssertEqual(content, AppNotificationContent(title: "7ZMac", message: "archive.7z: OK ✓ (4 items)"))
    }

    func testOperationFailedMessage() {
        let content = FinderActionNotificationFormatter.operationFailed(SevenZipError.executableNotFound)

        XCTAssertEqual(content.title, "7ZMac — Error")
        XCTAssertEqual(content.message, SevenZipError.executableNotFound.localizedDescription)
    }
}