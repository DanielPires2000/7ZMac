import SwiftUI
import os
import UserNotifications

/// Routes Finder extension URL actions to the appropriate handlers.
@MainActor
final class ActionRouter {
    
    private let windowManager: WindowManager
    
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }
    
    // MARK: - URL Routing
    
    func handleFinderAction(url: URL) {
        guard url.scheme == "sevenzma" else { return }
        
        let action = url.host ?? ""
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let base64Param = components.queryItems?.first(where: { $0.name == "paths" })?.value,
              let jsonData = Data(base64Encoded: base64Param),
              let paths = try? JSONSerialization.jsonObject(with: jsonData) as? [String] else {
            Log.app.error("Failed to parse URL: \(url.absoluteString)")
            return
        }
        
        Log.app.info("Received action '\(action)' with \(paths.count) paths")
        let fileURLs = paths.map { URL(fileURLWithPath: $0) }
        
        if action == "addToArchive" {
            handleAddToArchive(filePaths: paths, fileURLs: fileURLs)
        } else if action == "extractFiles" {
            handleExtractFiles(fileURLs: fileURLs)
        } else {
            Task { @MainActor in
                await processAction(action, files: fileURLs)
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
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose extraction destination"
        panel.prompt = "Extract"
        
        if panel.runModal() == .OK, let destination = panel.url {
            Task { @MainActor in
                await self.extractFiles(fileURLs, to: destination)
            }
        }
    }
    
    // MARK: - Background Actions
    
    private func processAction(_ action: String, files: [URL]) async {
        let service = DIContainer.shared.resolve(ArchiveServiceProtocol.self)
        
        do {
            switch action {
            case "compress7z":
                guard let first = files.first else { return }
                let name = first.deletingPathExtension().lastPathComponent + ".7z"
                let archiveURL = first.deletingLastPathComponent().appendingPathComponent(name)
                let args = ["a", "-t7z", archiveURL.path] + files.map { $0.path }
                windowManager.showProgressWindow(title: name, arguments: args)
                
            case "compressZip":
                guard let first = files.first else { return }
                let name = first.deletingPathExtension().lastPathComponent + ".zip"
                let archiveURL = first.deletingLastPathComponent().appendingPathComponent(name)
                let args = ["a", "-tzip", archiveURL.path] + files.map { $0.path }
                windowManager.showProgressWindow(title: name, arguments: args)
                
            case "extractHere":
                let resolved = SplitArchiveDetector.resolveForExtraction(files: files)
                for file in resolved {
                    try await service.extract(archive: file, to: file.deletingLastPathComponent())
                    showNotification(title: "7ZMac", message: "Extracted \(file.lastPathComponent)")
                }
                
            case "extractToSubfolder":
                let resolved = SplitArchiveDetector.resolveForExtraction(files: files)
                for file in resolved {
                    let folderName: String
                    if let baseName = SplitArchiveDetector.baseName(of: file) {
                        folderName = (baseName as NSString).deletingPathExtension
                    } else {
                        folderName = file.deletingPathExtension().lastPathComponent
                    }
                    let dest = file.deletingLastPathComponent().appendingPathComponent(folderName)
                    try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
                    try await service.extract(archive: file, to: dest)
                    showNotification(title: "7ZMac", message: "Extracted to \(folderName)/")
                }
                
            case "testArchive":
                let resolved = SplitArchiveDetector.resolveForExtraction(files: files)
                for file in resolved {
                    let items = try await service.listContents(archive: file)
                    showNotification(title: "7ZMac", message: "\(file.lastPathComponent): OK ✓ (\(items.count) items)")
                }
                
            default:
                Log.app.warning("Unknown action: \(action)")
            }
        } catch {
            showNotification(title: "7ZMac — Error", message: error.localizedDescription)
        }
    }
    
    private func extractFiles(_ files: [URL], to destination: URL) async {
        let service = DIContainer.shared.resolve(ArchiveServiceProtocol.self)
        let resolved = SplitArchiveDetector.resolveForExtraction(files: files)
        do {
            for file in resolved {
                try await service.extract(archive: file, to: destination)
                showNotification(title: "7ZMac", message: "Extracted \(file.lastPathComponent)")
            }
        } catch {
            showNotification(title: "7ZMac — Error", message: error.localizedDescription)
        }
    }
    
    // MARK: - Notifications
    
    func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
