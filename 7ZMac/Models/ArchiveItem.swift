import Foundation

/// Represents a single entry inside an archive.
struct ArchiveItem: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let size: String
    let packedSize: String
    let modified: String
    let attributes: String
    let isFolder: Bool
    
    /// Display name (last path component).
    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
