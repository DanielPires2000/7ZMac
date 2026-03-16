import SwiftUI
import os

enum FinderAction: String {
    case addToArchive
    case extractFiles
    case compress7z
    case compressZip
    case extractHere
    case extractToSubfolder
    case testArchive
}

struct FinderActionRequest {
    let action: FinderAction
    let filePaths: [String]

    init(action: FinderAction, filePaths: [String]) {
        self.action = action
        self.filePaths = filePaths
    }

    var fileURLs: [URL] {
        filePaths.map { URL(fileURLWithPath: $0) }
    }

    init?(url: URL) {
        guard url.scheme == "sevenzma",
              let action = FinderAction(rawValue: url.host ?? ""),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let base64Param = components.queryItems?.first(where: { $0.name == "paths" })?.value,
              let jsonData = Data(base64Encoded: base64Param),
              let filePaths = try? JSONSerialization.jsonObject(with: jsonData) as? [String] else {
            return nil
        }

        self.action = action
        self.filePaths = filePaths
    }
}

/// Routes Finder extension URL actions to the appropriate handlers.
@MainActor
final class ActionRouter {
    
    private let windowManager: WindowManaging
    private let dialogService: FileDialogServiceProtocol
    private let actionExecutor: FinderActionExecuting
    private let activateApp: @MainActor () -> Void
    private let notificationSink: @MainActor (String, String) -> Void
    
    init(
        windowManager: WindowManaging,
        dialogService: FileDialogServiceProtocol,
        actionExecutor: FinderActionExecuting,
        activateApp: @escaping @MainActor () -> Void,
        notificationSink: @escaping @MainActor (String, String) -> Void
    ) {
        self.windowManager = windowManager
        self.dialogService = dialogService
        self.actionExecutor = actionExecutor
        self.activateApp = activateApp
        self.notificationSink = notificationSink
    }
    
    // MARK: - URL Routing
    
    func handleFinderAction(url: URL) {
        guard let request = FinderActionRequest(url: url) else {
            Log.app.error("Failed to parse URL: \(url.absoluteString)")
            return
        }

        Log.app.info("Received action '\(request.action.rawValue)' with \(request.filePaths.count) paths")

        switch request.action {
        case .addToArchive:
            handleAddToArchive(filePaths: request.filePaths, fileURLs: request.fileURLs)

        case .extractFiles:
            handleExtractFiles(fileURLs: request.fileURLs)

        default:
            Task { @MainActor in
                await processAction(request)
            }
        }
    }
    
    // MARK: - Add to Archive
    
    private func handleAddToArchive(filePaths: [String], fileURLs: [URL]) {
        windowManager.showAddToArchiveDialog(filePaths: filePaths) { [weak self] archivePath, options in
            let archiveURL = URL(fileURLWithPath: archivePath)
            let args = options.buildArguments(
                archivePath: archiveURL.path,
                filePaths: fileURLs.map { $0.path }
            )
            self?.windowManager.showProgressWindow(
                title: archiveURL.lastPathComponent,
                arguments: args
            )
        }
    }
    
    // MARK: - Extract Files (with folder picker)
    
    private func handleExtractFiles(fileURLs: [URL]) {
        activateApp()
        if let destination = dialogService.chooseExtractionDestination() {
            Task { @MainActor in
                await self.actionExecutor.extract(files: fileURLs, to: destination)
            }
        }
    }

    // MARK: - Background Actions

    private func processAction(_ request: FinderActionRequest) async {
        await actionExecutor.execute(request)
    }
    
    // MARK: - Notifications
    
    func showNotification(title: String, message: String) {
        notificationSink(title, message)
    }
}
