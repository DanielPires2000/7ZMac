import Foundation

nonisolated struct AppNotificationContent: Equatable {
    let title: String
    let message: String
}

nonisolated enum FinderActionNotificationFormatter {
    static func extractionCompleted(archiveName: String) -> AppNotificationContent {
        AppNotificationContent(title: "7ZMac", message: "Extracted \(archiveName)")
    }

    static func extractionCompleted(toFolder folderName: String) -> AppNotificationContent {
        AppNotificationContent(title: "7ZMac", message: "Extracted to \(folderName)/")
    }

    static func archiveTestPassed(archiveName: String, itemCount: Int) -> AppNotificationContent {
        AppNotificationContent(title: "7ZMac", message: "\(archiveName): OK ✓ (\(itemCount) items)")
    }

    static func operationFailed(_ error: Error) -> AppNotificationContent {
        AppNotificationContent(title: "7ZMac — Error", message: error.localizedDescription)
    }
}