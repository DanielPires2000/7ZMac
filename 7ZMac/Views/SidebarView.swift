import SwiftUI

/// Sidebar with quick-access navigation to common folders.
struct SidebarView: View {
    @ObservedObject var viewModel: FileManagerViewModel

    private func color(for name: String) -> Color {
        switch name {
        case "blue":
            return .blue
        case "gray":
            return .gray
        case "purple":
            return .purple
        default:
            return .accentColor
        }
    }
    
    var body: some View {
        List {
            Section("Favorites") {
                ForEach(Array(viewModel.favoriteLocations.prefix(4)), id: \.url) { location in
                    sidebarItem(
                        name: location.name,
                        icon: location.icon,
                        color: color(for: location.colorName),
                        url: location.url
                    )
                }
            }

            Section("System") {
                ForEach(Array(viewModel.favoriteLocations.dropFirst(4)), id: \.url) { location in
                    sidebarItem(
                        name: location.name,
                        icon: location.icon,
                        color: color(for: location.colorName),
                        url: location.url
                    )
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    private func sidebarItem(name: String, icon: String, color: Color, url: URL) -> some View {
        Button(action: { viewModel.navigateTo(url) }) {
            Label {
                Text(name)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(color)
            }
        }
        .buttonStyle(.plain)
    }
}
