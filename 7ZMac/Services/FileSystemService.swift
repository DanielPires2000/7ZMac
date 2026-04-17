import Foundation
import AppKit

/// Service for filesystem operations (listing, opening, copying, moving, deleting).
final class FileSystemService: FileSystemServiceProtocol {
    
    /// List the contents of a directory, sorted: folders first, then files alphabetically.
    func listDirectory(at url: URL) async throws -> [FileItem] {
        // Capture archive extensions locally BEFORE entering detached task
        // so we never cross actor boundaries inside the closure.
        let archiveExts = ArchiveTypeCatalog.baseExtensions
        
        return try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let resourceKeys: [URLResourceKey] = [
                .nameKey, .fileSizeKey, .contentModificationDateKey,
                .isDirectoryKey, .isHiddenKey
            ]
            
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            
            let items = contents.compactMap { itemUrl -> FileItem? in
                guard let resources = try? itemUrl.resourceValues(forKeys: Set(resourceKeys)) else {
                    return nil
                }
                
                let isDirectory = resources.isDirectory ?? false
                
                // Inline archive check using local captured set — no actor crossing
                let isArchive: Bool
                if isDirectory {
                    isArchive = false
                } else {
                    let ext = itemUrl.pathExtension.lowercased()
                    let name = itemUrl.lastPathComponent.lowercased()
                    let hasDoubleExt = name.hasSuffix(".tar.gz")
                        || name.hasSuffix(".tar.bz2")
                        || name.hasSuffix(".tar.xz")
                    isArchive = archiveExts.contains(ext) || hasDoubleExt
                }
                
                return FileItem(
                    url: itemUrl,
                    name: resources.name ?? itemUrl.lastPathComponent,
                    size: Int64(resources.fileSize ?? 0),
                    modifiedDate: resources.contentModificationDate ?? Date.distantPast,
                    isDirectory: isDirectory,
                    isArchive: isArchive
                )
            }
            
            // Sort: folders first, then alphabetically
            return items.sorted { a, b in
                if a.isDirectory != b.isDirectory {
                    return a.isDirectory
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }.value
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    /// Open a file with the system's default application.
    func openWithDefaultApp(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    /// Move items to trash.
    func trashItems(_ urls: [URL]) throws {
        for url in urls {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }
    
    /// Copy items to a destination directory.
    func copyItems(_ urls: [URL], to destination: URL) throws {
        let fileManager = FileManager.default
        // Ensure destination directory exists
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }
        for url in urls {
            let baseDest = destination.appendingPathComponent(url.lastPathComponent)
            let dest = uniqueDestinationURL(for: baseDest)
            try fileManager.copyItem(at: url, to: dest)
        }
    }
    
    /// Move items to a destination directory.
    func moveItems(_ urls: [URL], to destination: URL) throws {
        let fileManager = FileManager.default
        // Ensure destination directory exists
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }
        for url in urls {
            let baseDest = destination.appendingPathComponent(url.lastPathComponent)
            let dest = uniqueDestinationURL(for: baseDest)
            do {
                try fileManager.moveItem(at: url, to: dest)
            } catch {
                // Fallback for cross-volume moves: copy then remove
                try fileManager.copyItem(at: url, to: dest)
                try fileManager.removeItem(at: url)
            }
        }
    }
    
    /// Get the user's home directory.
    var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
    
    /// Get common user directories.
    var desktopDirectory: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }
    
    var downloadsDirectory: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }
    
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Generate a unique destination URL by appending (2), (3), ... if a file/folder already exists.
    private func uniqueDestinationURL(for url: URL) -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) { return url }
        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let candidateName: String
            if ext.isEmpty {
                candidateName = "\(base) (\(index))"
            } else {
                candidateName = "\(base) (\(index)).\(ext)"
            }
            let candidate = dir.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}
