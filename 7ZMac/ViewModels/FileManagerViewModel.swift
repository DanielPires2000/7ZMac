import Foundation
import AppKit
internal import Combine
import UniformTypeIdentifiers

/// Central ViewModel for the file manager. Handles filesystem browsing,
/// archive browsing, navigation history, and user actions.
@MainActor
final class FileManagerViewModel: ObservableObject {
    
    // MARK: - Navigation Mode
    
    enum NavigationMode: Equatable {
        case fileSystem
        case archive(url: URL)
    }
    
    // MARK: - Published State
    
    @Published var currentPath: URL
    @Published var fileItems: [FileItem] = []
    @Published var archiveItems: [ArchiveItem] = []
    @Published var navigationMode: NavigationMode = .fileSystem
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var selectedFileIDs: Set<UUID> = []
    @Published var selectedArchiveIDs: Set<UUID> = []
    
    // MARK: - Navigation History
    
    private var backStack: [URL] = []
    private var forwardStack: [URL] = []
    
    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    
    var canGoUp: Bool {
        switch navigationMode {
        case .fileSystem:
            return currentPath.pathComponents.count > 1
        case .archive:
            return true // Can always go back to filesystem from archive
        }
    }
    
    // MARK: - Path Components (for address bar)
    
    var pathComponents: [(name: String, url: URL)] {
        var components: [(String, URL)] = []
        var url = currentPath
        
        while url.pathComponents.count > 1 {
            components.insert((url.lastPathComponent, url), at: 0)
            url = url.deletingLastPathComponent()
        }
        components.insert(("/", URL(fileURLWithPath: "/")), at: 0)
        
        return components
    }
    
    // MARK: - Dependencies
    
    private let fileSystemService: FileSystemServiceProtocol
    private let archiveService: ArchiveServiceProtocol
    
    // MARK: - Init

    // Designated initializer without default to avoid actor-isolation issues
    init(container: DIContainer) {
        let fs = container.resolve(FileSystemServiceProtocol.self)
        self.fileSystemService = fs
        self.archiveService = container.resolve(ArchiveServiceProtocol.self)
        self.currentPath = fs.homeDirectory
    }

    // Convenience initializer that safely accesses the shared container on the main actor
    convenience init() {
        self.init(container: DIContainer.shared)
    }
    
    // MARK: - Load Current Directory
    
    func loadCurrentDirectory() {
        guard case .fileSystem = navigationMode else { return }
        
        do {
            fileItems = try fileSystemService.listDirectory(at: currentPath)
            errorMessage = nil
        } catch {
            errorMessage = "Cannot access: \(error.localizedDescription)"
            fileItems = []
        }
    }
    
    // MARK: - Navigation
    
    func navigateTo(_ url: URL) {
        backStack.append(currentPath)
        forwardStack.removeAll()
        currentPath = url
        navigationMode = .fileSystem
        archiveItems = []
        selectedFileIDs = []
        selectedArchiveIDs = []
        loadCurrentDirectory()
    }
    
    func navigateBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentPath)
        currentPath = previous
        navigationMode = .fileSystem
        archiveItems = []
        loadCurrentDirectory()
    }
    
    func navigateForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentPath)
        currentPath = next
        navigationMode = .fileSystem
        archiveItems = []
        loadCurrentDirectory()
    }
    
    func navigateUp() {
        switch navigationMode {
        case .fileSystem:
            let parent = currentPath.deletingLastPathComponent()
            if parent != currentPath {
                navigateTo(parent)
            }
        case .archive:
            // Exit archive mode, go back to filesystem
            navigationMode = .fileSystem
            archiveItems = []
            loadCurrentDirectory()
        }
    }
    
    // MARK: - Double Click
    
    func handleDoubleClick(fileItem: FileItem) {
        if fileItem.isDirectory {
            navigateTo(fileItem.url)
        } else if fileItem.isArchive {
            openArchive(at: fileItem.url)
        } else {
            fileSystemService.openWithDefaultApp(fileItem.url)
        }
    }
    
    func handleDoubleClickArchiveItem(_ item: ArchiveItem) {
        // If it's a folder inside the archive, we could navigate deeper
        // For now, just show info
    }
    
    // MARK: - Archive Operations
    
    func openArchive(at url: URL) {
        isProcessing = true
        errorMessage = nil
        navigationMode = .archive(url: url)
        
        Task {
            do {
                let items = try await archiveService.listContents(archive: url)
                archiveItems = items
            } catch {
                errorMessage = error.localizedDescription
                archiveItems = []
            }
            isProcessing = false
        }
    }
    
    /// Extract the current archive or selected archive to a user-chosen folder.
    func extractArchive() {
        let archiveURL: URL
        
        switch navigationMode {
        case .archive(let url):
            archiveURL = url
        case .fileSystem:
            // Extract selected file if it's an archive
            guard let selected = fileItems.first(where: { selectedFileIDs.contains($0.id) && $0.isArchive }) else {
                return
            }
            archiveURL = selected.url
        }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = "Choose destination for extraction"
        
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                try await archiveService.extract(archive: archiveURL, to: destination)
                NSWorkspace.shared.open(destination) // Open the destination folder
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }
    
    /// Compress selected files into a new archive.
    func compressFiles() {
        let selectedURLs = fileItems
            .filter { selectedFileIDs.contains($0.id) }
            .map { $0.url }
        
        guard !selectedURLs.isEmpty else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "7z")!]
        panel.nameFieldStringValue = "archive.7z"
        panel.message = "Choose where to save the archive"
        
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                try await archiveService.compress(files: selectedURLs, to: destination)
                // Refresh to show the new archive
                loadCurrentDirectory()
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }
    
    /// Delete selected files (move to trash).
    func deleteSelected() {
        let selectedURLs = fileItems
            .filter { selectedFileIDs.contains($0.id) }
            .map { $0.url }
        
        guard !selectedURLs.isEmpty else { return }
        
        do {
            try fileSystemService.trashItems(selectedURLs)
            selectedFileIDs = []
            loadCurrentDirectory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Open selected file with default application.
    func openSelected() {
        guard let selected = fileItems.first(where: { selectedFileIDs.contains($0.id) }) else { return }
        handleDoubleClick(fileItem: selected)
    }
}

