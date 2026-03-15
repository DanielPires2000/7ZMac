import SwiftUI

/// Breadcrumb-style address bar showing the current path.
struct AddressBarView: View {
    let pathComponents: [(name: String, url: URL)]
    let isInArchive: Bool
    let archiveName: String?
    let onNavigate: (URL) -> Void
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<pathComponents.count, id: \.self) { index in
                let component = pathComponents[index]
                
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: { onNavigate(component.url) }) {
                    Text(component.name)
                        .font(.system(.body, design: .default))
                        .foregroundColor(index == pathComponents.count - 1 ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            if isInArchive, let name = archiveName {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "archivebox.fill")
                        .foregroundColor(.orange)
                    Text(name)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

// MARK: - Previews

#Preview("File System Path") {
    AddressBarView(
        pathComponents: [
            (name: "Home", url: URL(fileURLWithPath: "/Users/test")),
            (name: "Documents", url: URL(fileURLWithPath: "/Users/test/Documents")),
            (name: "Project", url: URL(fileURLWithPath: "/Users/test/Documents/Project"))
        ],
        isInArchive: false,
        archiveName: nil,
        onNavigate: { _ in }
    )
}

#Preview("Inside Archive") {
    AddressBarView(
        pathComponents: [
            (name: "Home", url: URL(fileURLWithPath: "/Users/test")),
            (name: "Downloads", url: URL(fileURLWithPath: "/Users/test/Downloads"))
        ],
        isInArchive: true,
        archiveName: "backup.7z",
        onNavigate: { _ in }
    )
}
