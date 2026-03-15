import Foundation

/// Whitelist of archive extensions that 7ZMac should open as archives.
/// Files like .docx/.xlsx are technically ZIP archives but should NOT be treated as such.
///
/// This is the canonical list. Keep FinderSync.archiveExtensions in sync.
enum SupportedArchiveTypes {
    
    /// Extensions recognized as archives.
    static let extensions: Set<String> = [
        "7z", "zip", "rar", "tar", "gz", "bz2", "xz", "lzma",
        "cab", "iso", "wim", "arj", "lzh", "z",
        "tgz", "tbz2", "txz",     // tar+compression combos
        "rpm", "deb", "cpio",      // package formats
        "vhd", "vhdx",             // disk images
    ]
    
    /// Check if a URL points to a supported archive type.
    static func isArchive(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        
        // Handle double extensions like .tar.gz
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".tar.gz") || name.hasSuffix(".tar.bz2") || name.hasSuffix(".tar.xz") {
            return true
        }
        
        return extensions.contains(ext)
    }
}
