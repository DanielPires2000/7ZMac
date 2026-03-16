import SwiftUI
import UniformTypeIdentifiers

/// Main application view — file manager layout with sidebar, address bar, toolbar, and content table.
struct ContentView: View {
    @StateObject private var viewModel = FileManagerViewModel()
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            VStack(spacing: 0) {
                // Address bar
                addressBar
                
                Divider()
                
                // Content area
                contentArea
            }
            .navigationTitle("")
            .toolbar { toolbarContent }
        }
        .onAppear {
            viewModel.loadCurrentDirectory()
        }
    }
    
    // MARK: - Address Bar
    
    private var addressBar: some View {
        AddressBarView(
            pathComponents: viewModel.pathComponents,
            isInArchive: viewModel.navigationMode != .fileSystem,
            archiveName: archiveName,
            onNavigate: { url in
                viewModel.navigateTo(url)
            }
        )
    }
    
    private var archiveName: String? {
        if case .archive(let url) = viewModel.navigationMode {
            return url.lastPathComponent
        }
        return nil
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isProcessing {
            VStack {
                Spacer()
                ProgressView("Processing...")
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text(error)
                    .foregroundColor(.secondary)
                Button("Go Home") {
                    viewModel.navigateHome()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch viewModel.navigationMode {
            case .fileSystem:
                FileTableView(
                    items: viewModel.fileItems,
                    selection: $viewModel.selectedFileIDs,
                    onDoubleClick: { item in
                        viewModel.handleDoubleClick(fileItem: item)
                    }
                )
            case .archive:
                ArchiveTableView(
                    items: viewModel.archiveItems,
                    selection: $viewModel.selectedArchiveIDs
                )
            }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: { viewModel.navigateBack() }) {
                Label("Back", systemImage: "chevron.left")
            }
            .disabled(!viewModel.canGoBack)
            
            Button(action: { viewModel.navigateForward() }) {
                Label("Forward", systemImage: "chevron.right")
            }
            .disabled(!viewModel.canGoForward)
            
            Button(action: { viewModel.navigateUp() }) {
                Label("Up", systemImage: "arrow.up")
            }
            .disabled(!viewModel.canGoUp)
        }
        
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: { viewModel.compressFiles() }) {
                Label("Add to Archive", systemImage: "plus.rectangle.on.folder")
            }
            .disabled(viewModel.selectedFileIDs.isEmpty || viewModel.navigationMode != .fileSystem)
            
            Button(action: { viewModel.extractArchive() }) {
                Label("Extract", systemImage: "arrow.up.doc")
            }
            .disabled(!canExtract)
            
            Button(action: { viewModel.deleteSelected() }) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(viewModel.selectedFileIDs.isEmpty || viewModel.navigationMode != .fileSystem)
        }
    }
    
    private var canExtract: Bool {
        switch viewModel.navigationMode {
        case .archive:
            return true
        case .fileSystem:
            return viewModel.fileItems.contains { viewModel.selectedFileIDs.contains($0.id) && $0.isArchive }
        }
    }
}
