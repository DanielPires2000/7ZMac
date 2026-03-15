import Foundation

/// Represents a file or folder in the filesystem.
struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let modifiedDate: Date
    let isDirectory: Bool
    let isArchive: Bool
    
    /// Human-readable size string.
    var formattedSize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    /// Human-readable date string.
    var formattedDate: String {
        Self.dateFormatter.string(from: modifiedDate)
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// SF Symbol name for the file type.
    var iconName: String {
        if isDirectory { return "folder.fill" }
        if isArchive { return "archivebox.fill" }
        
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "txt", "md", "rtf": return "doc.text"
        case "swift", "py", "js", "html", "css", "json", "xml":
            return "chevron.left.forwardslash.chevron.right"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp":
            return "photo"
        case "mp4", "mov", "avi", "mkv": return "film"
        case "mp3", "wav", "aac", "flac", "m4a": return "music.note"
        case "app": return "app.gift"
        case "dmg": return "externaldrive"
        case "doc", "docx": return "doc.fill"
        case "xls", "xlsx": return "tablecells"
        case "ppt", "pptx": return "rectangle.stack"
        default: return "doc"
        }
    }
    
    /// Color for the icon.
    var iconColor: String {
        if isDirectory { return "blue" }
        if isArchive { return "orange" }
        return "secondary"
    }
}
