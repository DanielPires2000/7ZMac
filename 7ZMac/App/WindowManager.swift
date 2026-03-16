import SwiftUI

@MainActor
protocol WindowManaging: AnyObject {
    func showAddToArchiveDialog(
        filePaths: [String],
        onCompress: @escaping (String, CompressionOptions) -> Void
    )

    func showProgressWindow(title: String, arguments: [String])
}

/// Manages the creation and lifecycle of key windows
/// (Add to Archive dialog, Compression Progress).
@MainActor
final class WindowManager: WindowManaging {
    private let executablePath: String
    
    private var addToArchiveWindow: NSWindow?
    private var progressWindow: NSWindow?

    init(executablePath: String) {
        self.executablePath = executablePath
    }
    
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
        
        tracker.run(executablePath: executablePath, arguments: arguments)
    }
}
