import SwiftUI
import UserNotifications

/// App entry point. No main window — operates entirely via URL scheme from Finder extension.
@main
struct _ZMacApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        Self.registerDependencies()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    var body: some Scene {
        // We provide a dummy WindowGroup to satisfy SwiftUI's requirement for a regular app.
        // However, we don't actually use it to show our dialogs (those are manual NSWindows).
        WindowGroup {
            Color.clear
                .frame(width: 0, height: 0)
        }
        Settings { EmptyView() }
    }
    
    private static func registerDependencies() {
        let container = DIContainer.shared
        container.registerSingleton(ArchiveServiceProtocol.self) { SevenZipService() }
        container.registerSingleton(FileSystemServiceProtocol.self) { FileSystemService() }
        container.registerSingleton(FileDialogServiceProtocol.self) { FileDialogService() }
        container.registerSingleton(NotificationServiceProtocol.self) { NotificationService() }
    }
}

// MARK: - AppDelegate

/// The AppDelegate owns the `WindowManager` and `ActionRouter` directly, which is the most
/// reliable pattern for a macOS agent app with no persistent main window.
/// We use `NSAppleEventManager` to intercept URL scheme events BEFORE the app is fully launched,
/// queuing them to be processed once the app finishes launching.
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var windowManager: WindowManager?
    private var actionRouter: ActionRouter?
    
    private var pendingURLs: [URL] = []
    private var isAppReady = false
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Force the app to be a regular app to ensure windows appear
        NSApp.setActivationPolicy(.regular)
        
        // Register early to ensure we don't miss any Finder URLs
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleAppleEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
    
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let container = DIContainer.shared
        let archiveService = container.resolve(ArchiveServiceProtocol.self)
        let fileSystemService = container.resolve(FileSystemServiceProtocol.self)
        let dialogService = container.resolve(FileDialogServiceProtocol.self)
        let notificationService = container.resolve(NotificationServiceProtocol.self)

        let executablePath = (archiveService as? SevenZipService)?.executablePathValue ?? "/opt/homebrew/bin/7zz"
        let wm = WindowManager(executablePath: executablePath)
        let actionExecutor = FinderActionExecutor(
            windowManager: wm,
            archiveService: archiveService,
            fileSystemService: fileSystemService,
            notificationSink: { title, message in
                notificationService.showNotification(title: title, message: message)
            }
        )
        self.windowManager = wm
        self.actionRouter = ActionRouter(
            windowManager: wm,
            dialogService: dialogService,
            actionExecutor: actionExecutor,
            activateApp: {
                NSApp.activate(ignoringOtherApps: true)
            },
            notificationSink: { title, message in
                notificationService.showNotification(title: title, message: message)
            }
        )
        
        print("7ZMac: [AppDelegate] applicationDidFinishLaunching - App Ready")
        self.isAppReady = true
        
        // Process any queued URLs
        if !pendingURLs.isEmpty {
            print("7ZMac: [AppDelegate] Processing \(pendingURLs.count) pending URLs.")
            for url in pendingURLs {
                self.actionRouter?.handleFinderAction(url: url)
            }
            pendingURLs.removeAll()
        }
    }
    
    @objc func handleAppleEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { 
            print("7ZMac: [AppDelegate] handleAppleEvent - Failed to get URL string")
            return 
        }
        
        print("7ZMac: [AppDelegate] handleAppleEvent - Received URL: \(urlString)")
        
        // We must switch to main thread for UI operations, but we can queue immediately.
        if Thread.isMainThread {
            self.processReceivedURL(url)
        } else {
            DispatchQueue.main.async {
                self.processReceivedURL(url)
            }
        }
    }
    
    private func processReceivedURL(_ url: URL) {
        // Crucial: When launched from Finder, the app must activate!
        NSApp.activate(ignoringOtherApps: true)
        
        if self.isAppReady, let router = self.actionRouter {
            print("7ZMac: [AppDelegate] Routing action: \(url.host ?? "none")")
            router.handleFinderAction(url: url)
        } else {
            print("7ZMac: [AppDelegate] App not ready, queuing URL: \(url.host ?? "none")")
            self.pendingURLs.append(url)
        }
    }
    
    /// Prevent re-opening any window when clicking the dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
    
    /// Automatically quit the app when the last window (Add to Archive / Progress) is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
