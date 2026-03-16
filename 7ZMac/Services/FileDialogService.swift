import AppKit
import Foundation
import UniformTypeIdentifiers

/// Protocol for file and folder selection dialogs. Enables testable ViewModels.
@MainActor
protocol FileDialogServiceProtocol: AnyObject {
    /// Prompt the user to choose a destination folder for extraction.
    func chooseExtractionDestination() -> URL?

    /// Prompt the user to choose where to save a new archive.
    func chooseArchiveDestination(defaultFileName: String) -> URL?
}

/// Concrete AppKit-backed implementation of file dialogs.
@MainActor
final class FileDialogService: FileDialogServiceProtocol {
    func chooseExtractionDestination() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = "Choose destination for extraction"

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    func chooseArchiveDestination(defaultFileName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "7z")!]
        panel.nameFieldStringValue = defaultFileName
        panel.message = "Choose where to save the archive"

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}