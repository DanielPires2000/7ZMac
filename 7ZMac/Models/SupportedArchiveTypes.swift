import Foundation

/// Whitelist of archive extensions that 7ZMac should open as archives.
/// Files like .docx/.xlsx are technically ZIP archives but should NOT be treated as such.
///
/// This is the canonical list. Keep FinderSync.archiveExtensions in sync.
enum SupportedArchiveTypes {
    
    /// Extensions recognized as archives.
    static let extensions = ArchiveTypeCatalog.baseExtensions
    
    /// Check if a URL points to a supported archive type.
    static func isArchive(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        
        // Handle double extensions like .tar.gz
        let name = url.lastPathComponent
        if ArchiveTypeCatalog.hasSupportedDoubleExtension(name) {
            return true
        }
        
        return extensions.contains(ext)
    }
}
