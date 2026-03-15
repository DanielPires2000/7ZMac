import SwiftUI

/// Manages the creation and lifecycle of key windows
/// (Add to Archive dialog, Compression Progress).
@MainActor
final class WindowManager {
    
    private var addToArchiveWindow: NSWindow?
    private var progressWindow: NSWindow?
    
    // MARK: - Add to Archive
    
    func showAddToArchiveDialog(
        filePaths: [String],
        onCompress: @escaping (String, CompressionOptions) -> Void
    ) {
        addToArchiveWindow?.close()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Add to Archive"
        window.isReleasedWhenClosed = false
        window.center()
        self.addToArchiveWindow = window
        
        let view = AddToArchiveView(
            filePaths: filePaths,
            onCompress: { [weak self] archivePath, options in
                self?.addToArchiveWindow?.close()
                self?.addToArchiveWindow = nil
                onCompress(archivePath, options)
            },
            onCancel: { [weak self] in
                self?.addToArchiveWindow?.close()
                self?.addToArchiveWindow = nil
            }
        )
        
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Progress
    
    func showProgressWindow(title: String, arguments: [String]) {
        progressWindow?.close()
        
        let tracker = CompressionProgressTracker()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Compressing — \(title)"
        window.isReleasedWhenClosed = false
        window.center()
        self.progressWindow = window
        
        let view = CompressionProgressView(
            tracker: tracker,
            onCancel: { [weak self] in
                self?.progressWindow?.close()
                self?.progressWindow = nil
            }
        )
        
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Resolve the executable path
        let service = DIContainer.shared.resolve(ArchiveServiceProtocol.self) as? SevenZipService
        let execPath = service?.executablePathValue ?? "/opt/homebrew/bin/7zz"
        
        tracker.run(executablePath: execPath, arguments: arguments)
    }
}
