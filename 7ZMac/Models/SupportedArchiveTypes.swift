import Foundation

/// Whitelist of archive extensions that 7ZMac should open as archives.
/// Files like .docx/.xlsx are technically ZIP archives but should NOT be treated as such.
///
/// This is the canonical list. Keep FinderSync.archiveExtensions in sync.
///
/// Explicitly nonisolated so it can be called freely from any actor or thread.
nonisolated enum SupportedArchiveTypes: Sendable {
    
    /// Archive extensions recognised by 7ZMac.
    static let knownExtensions: Set<String> = [
        "7z", "zip", "rar", "tar", "gz", "bz2", "xz", "lzma",
        "cab", "iso", "wim", "arj", "lzh", "z",
        "tgz", "tbz2", "txz",
        "rpm", "deb", "cpio",
        "vhd", "vhdx"
    ]
    
    /// Check if a URL points to a supported archive type.
    static func isArchive(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        
        // Handle double extensions like .tar.gz
        let name = url.lastPathComponent.lowercased()
        let hasDoubleExt = name.hasSuffix(".tar.gz")
            || name.hasSuffix(".tar.bz2")
            || name.hasSuffix(".tar.xz")
        
        return knownExtensions.contains(ext) || hasDoubleExt
    }
}
