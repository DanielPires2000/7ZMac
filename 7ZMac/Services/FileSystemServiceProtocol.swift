import Foundation

/// Protocol for filesystem operations. Enables DI and testability.
protocol FileSystemServiceProtocol {
    /// List the contents of a directory, sorted: folders first, then files alphabetically.
    func listDirectory(at url: URL) async throws -> [FileItem]

    /// Create a directory if it does not exist.
    func createDirectory(at url: URL) throws
    
    /// Open a file with the system's default application.
    func openWithDefaultApp(_ url: URL)
    
    /// Move items to trash.
    func trashItems(_ urls: [URL]) throws
    
    /// Copy items to a destination directory.
    func copyItems(_ urls: [URL], to destination: URL) throws
    
    /// Move items to a destination directory.
    func moveItems(_ urls: [URL], to destination: URL) throws
    
    /// Get the user's home directory.
    var homeDirectory: URL { get }
    
    /// Get the Desktop directory.
    var desktopDirectory: URL { get }
    
    /// Get the Downloads directory.
    var downloadsDirectory: URL { get }
    
    /// Get the Documents directory.
    var documentsDirectory: URL { get }
}
