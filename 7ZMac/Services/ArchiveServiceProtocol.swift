import Foundation

/// Protocol defining archive operations. Enables DI and testability.
protocol ArchiveServiceProtocol: AnyObject {
    /// List the contents of an archive file.
    func listContents(archive: URL) async throws -> [ArchiveItem]
    
    /// Extract an archive to a destination folder.
    func extract(archive: URL, to destination: URL) async throws
    
    /// Compress files into an archive.
    func compress(files: [URL], to archive: URL) async throws
    
    /// Compress files with advanced options.
    func compress(files: [URL], to archive: URL, options: CompressionOptions) async throws
    
    /// Check if the underlying tool is available.
    func checkAvailability() -> Bool
}
