import SwiftUI

/// Sidebar with quick-access navigation to common folders.
struct SidebarView: View {
    @ObservedObject var viewModel: FileManagerViewModel
    
    var body: some View {
        List {
            Section("Favorites") {
                sidebarItem(name: "Home", icon: "house.fill", color: .blue,
                           url: FileManager.default.homeDirectoryForCurrentUser)
                sidebarItem(name: "Desktop", icon: "desktopcomputer", color: .blue,
                           url: FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!)
                sidebarItem(name: "Documents", icon: "doc.fill", color: .blue,
                           url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!)
                sidebarItem(name: "Downloads", icon: "arrow.down.circle.fill", color: .blue,
                           url: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!)
            }
            
            Section("System") {
                sidebarItem(name: "Root", icon: "externaldrive.fill", color: .gray,
                           url: URL(fileURLWithPath: "/"))
                sidebarItem(name: "Applications", icon: "app.fill", color: .purple,
                           url: URL(fileURLWithPath: "/Applications"))
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
