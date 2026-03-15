import SwiftUI

/// Table view for filesystem items (files and folders).
struct FileTableView: View {
    let items: [FileItem]
    @Binding var selection: Set<UUID>
    let onDoubleClick: (FileItem) -> Void
    
    @State private var sortOrder = [KeyPathComparator(\FileItem.name)]
    
    private var sortedItems: [FileItem] {
        // Keep folders first, then apply sort
        let folders = items.filter { $0.isDirectory }
        let files = items.filter { !$0.isDirectory }
        return folders + files
    }
    
    var body: some View {
        Table(sortedItems, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { item in
                HStack(spacing: 6) {
                    itemIcon(for: item)
                    Text(item.name)
                        .lineLimit(1)
                }
                .onTapGesture(count: 2) {
                    onDoubleClick(item)
                }
            }
            .width(min: 200)
            
            TableColumn("Size") { item in
                Text(item.formattedSize)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Modified") { item in
                Text(item.formattedDate)
                    .foregroundColor(.secondary)
            }
            .width(min: 120, ideal: 160)
            
            TableColumn("Type") { item in
                Text(fileType(for: item))
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 120)
        }
        .tableStyle(.inset)
        .alternatingRowBackgrounds()
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func itemIcon(for item: FileItem) -> some View {
        if item.isDirectory {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
        } else if item.isArchive {
            Image(systemName: "archivebox.fill")
                .foregroundColor(.orange)
        } else {
            Image(systemName: item.iconName)
                .foregroundColor(.secondary)
        }
    }
    
    private func fileType(for item: FileItem) -> String {
        if item.isDirectory { return "Folder" }
        if item.isArchive { return "Archive" }
        let ext = item.url.pathExtension.uppercased()
        return ext.isEmpty ? "File" : "\(ext) File"
    }
}

/// Table view for archive contents (when browsing inside an archive).
struct ArchiveTableView: View {
    let items: [ArchiveItem]
    @Binding var selection: Set<UUID>
    
    var body: some View {
        Table(items, selection: $selection) {
            TableColumn("Name") { item in
                HStack(spacing: 6) {
                    Image(systemName: item.isFolder ? "folder.fill" : "doc")
                        .foregroundColor(item.isFolder ? .blue : .secondary)
                    Text(item.name)
                        .lineLimit(1)
                }
            }
            .width(min: 200)
            
            TableColumn("Size") { item in
                Text(item.size)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Packed") { item in
                Text(item.packedSize)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Modified") { item in
                Text(item.modified)
                    .foregroundColor(.secondary)
            }
            .width(min: 120, ideal: 160)
        }
        .tableStyle(.inset)
        .alternatingRowBackgrounds()
    }
}

// MARK: - Previews

#Preview("File Table") {
    FileTableView(
        items: FileItem.mocks,
        selection: .constant(Set<UUID>()),
        onDoubleClick: { _ in }
    )
    .frame(width: 700, height: 400)
}

#Preview("Archive Table") {
    ArchiveTableView(
        items: ArchiveItem.mocks,
        selection: .constant(Set<UUID>())
    )
    .frame(width: 700, height: 300)
}
