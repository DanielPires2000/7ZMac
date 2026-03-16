import Foundation

@MainActor
protocol FinderActionExecuting: AnyObject {
    func execute(_ request: FinderActionRequest) async
    func extract(files: [URL], to destination: URL) async
}

@MainActor
final class FinderActionExecutor: FinderActionExecuting {
    private let windowManager: WindowManaging
    private let archiveService: ArchiveServiceProtocol
    private let fileSystemService: FileSystemServiceProtocol
    private let notificationSink: @MainActor (String, String) -> Void

    init(
        windowManager: WindowManaging,
        archiveService: ArchiveServiceProtocol,
        fileSystemService: FileSystemServiceProtocol,
        notificationSink: @escaping @MainActor (String, String) -> Void
    ) {
        self.windowManager = windowManager
        self.archiveService = archiveService
        self.fileSystemService = fileSystemService
        self.notificationSink = notificationSink
    }

    func execute(_ request: FinderActionRequest) async {
        let files = request.fileURLs

        do {
            switch request.action {
            case .compress7z:
                guard let command = QuickCompressionCommand(format: .sevenZ, files: files) else { return }
                windowManager.showProgressWindow(title: command.title, arguments: command.arguments)

            case .compressZip:
                guard let command = QuickCompressionCommand(format: .zip, files: files) else { return }
                windowManager.showProgressWindow(title: command.title, arguments: command.arguments)

            case .extractHere:
                let targets = SplitArchiveDetector.makeExtractionTargets(files: files, strategy: .sameDirectory)
                for target in targets {
                    try await archiveService.extract(archive: target.archiveURL, to: target.destinationURL)
                    showNotification(FinderActionNotificationFormatter.extractionCompleted(
                        archiveName: target.archiveURL.lastPathComponent
                    ))
                }

            case .extractToSubfolder:
                let targets = SplitArchiveDetector.makeExtractionTargets(files: files, strategy: .subfolder)
                for target in targets {
                    try fileSystemService.createDirectory(at: target.destinationURL)
                    try await archiveService.extract(archive: target.archiveURL, to: target.destinationURL)
                    showNotification(FinderActionNotificationFormatter.extractionCompleted(
                        toFolder: target.destinationURL.lastPathComponent
                    ))
                }

            case .testArchive:
                let resolved = SplitArchiveDetector.resolveForExtraction(files: files)
                for file in resolved {
                    let items = try await archiveService.listContents(archive: file)
                    showNotification(FinderActionNotificationFormatter.archiveTestPassed(
                        archiveName: file.lastPathComponent,
                        itemCount: items.count
                    ))
                }

            case .addToArchive, .extractFiles:
                return
            }
        } catch {
            showNotification(FinderActionNotificationFormatter.operationFailed(error))
        }
    }

    func extract(files: [URL], to destination: URL) async {
        let resolved = SplitArchiveDetector.resolveForExtraction(files: files)

        do {
            for file in resolved {
                try await archiveService.extract(archive: file, to: destination)
                showNotification(FinderActionNotificationFormatter.extractionCompleted(
                    archiveName: file.lastPathComponent
                ))
            }
        } catch {
            showNotification(FinderActionNotificationFormatter.operationFailed(error))
        }
    }

    private func showNotification(_ content: AppNotificationContent) {
        notificationSink(content.title, content.message)
    }
}