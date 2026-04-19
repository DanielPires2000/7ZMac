//
//  FinderSync.swift
//  7ZMacFinder
//
//  Created by Daniel Pires on 16/02/2026.
//

import Cocoa
import FinderSync
import os

class FinderSync: FIFinderSync {
    
    private static let logger = Logger(
        subsystem: "com.danielpires.SevenZMac.FinderSync",
        category: "finder"
    )
    
    // MARK: - Supported Archive Extensions
    // Shared with the main app via ArchiveTypeCatalog.
    
    private let archiveExtensions = ArchiveTypeCatalog.finderRecognizedExtensions
    
    // MARK: - App Info
    
    private let appName: String = {
        let extensionURL = Bundle.main.bundleURL
        let appURL = extensionURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        if let appBundle = Bundle(url: appURL),
           let name = appBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? appBundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        
        let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String 
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String 
            ?? "App"
        return bundleName.replacingOccurrences(of: "Finder", with: "").trimmingCharacters(in: .whitespaces)
    }()
    
    // MARK: - Init
    
    override init() {
        super.init()
        Self.logger.info("Launched from \(Bundle.main.bundlePath)")
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }
    
    // MARK: - Context Menu
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // Do not show the menu when right-clicking on empty space (like the Desktop or folder background)
        guard menuKind == .contextualMenuForItems else { return nil }
        
        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        let hasArchives = selectedItems.contains { archiveExtensions.contains($0.pathExtension.lowercased()) }
        let hasFiles = !selectedItems.isEmpty
        
        guard hasFiles else { return nil }
        
        let rootMenu = NSMenu(title: "")
        let mainItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: appName)
        
        // ── Compression Options ──
        submenu.addItem(NSMenuItem(title: "Add to Archive...", action: #selector(addToArchive(_:)), keyEquivalent: ""))
        
        if let first = selectedItems.first {
            let name = first.deletingPathExtension().lastPathComponent
            submenu.addItem(NSMenuItem(title: "Compress to \"\(name).7z\"", action: #selector(quickCompress7z(_:)), keyEquivalent: ""))
            submenu.addItem(NSMenuItem(title: "Compress to \"\(name).zip\"", action: #selector(quickCompressZip(_:)), keyEquivalent: ""))
        }
        
        // ── Extraction Options ──
        if hasArchives {
            submenu.addItem(NSMenuItem.separator())
            
            submenu.addItem(NSMenuItem(title: "Extract files...", action: #selector(extractFiles(_:)), keyEquivalent: ""))
            submenu.addItem(NSMenuItem(title: "Extract Here", action: #selector(extractHere(_:)), keyEquivalent: ""))
            
            if let firstArchive = selectedItems.first(where: { archiveExtensions.contains($0.pathExtension.lowercased()) }) {
                let folderName = firstArchive.deletingPathExtension().lastPathComponent
                submenu.addItem(NSMenuItem(title: "Extract to \"\(folderName)/\"", action: #selector(extractToSubfolder(_:)), keyEquivalent: ""))
            }
            
            submenu.addItem(NSMenuItem.separator())
            submenu.addItem(NSMenuItem(title: "Test Archive", action: #selector(testArchive(_:)), keyEquivalent: ""))
        }
        
        mainItem.submenu = submenu
        rootMenu.addItem(mainItem)
        
        return rootMenu
    }
    
    // MARK: - Compression Actions
    
    @objc func addToArchive(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs(), !items.isEmpty else { return }
        openMainApp(action: "addToArchive", paths: items.map { $0.path })
    }
    
    @objc func quickCompress7z(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs(), !items.isEmpty else { return }
        openMainApp(action: "compress7z", paths: items.map { $0.path })
    }
    
    @objc func quickCompressZip(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs(), !items.isEmpty else { return }
        openMainApp(action: "compressZip", paths: items.map { $0.path })
    }
    
    // MARK: - Extraction Actions
    
    @objc func extractFiles(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        let paths = items.filter { archiveExtensions.contains($0.pathExtension.lowercased()) }.map { $0.path }
        openMainApp(action: "extractFiles", paths: paths)
    }
    
    @objc func extractHere(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        let paths = items.filter { archiveExtensions.contains($0.pathExtension.lowercased()) }.map { $0.path }
        openMainApp(action: "extractHere", paths: paths)
    }
    
    @objc func extractToSubfolder(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        let paths = items.filter { archiveExtensions.contains($0.pathExtension.lowercased()) }.map { $0.path }
        openMainApp(action: "extractToSubfolder", paths: paths)
    }
    
    @objc func testArchive(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        let paths = items.filter { archiveExtensions.contains($0.pathExtension.lowercased()) }.map { $0.path }
        openMainApp(action: "testArchive", paths: paths)
    }
    
    // MARK: - Communication with Main App (background)
    
    private func openMainApp(action: String, paths: [String]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: paths),
              let base64 = jsonData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            Self.logger.error("Failed to encode paths")
            return
        }
        
        let urlString = "sevenzma://\(action)?paths=\(base64)"
        guard let url = URL(string: urlString) else {
            Self.logger.error("Failed to create URL")
            return
        }
        
        Self.logger.info("Sending action '\(action)' to main app")
        
        // "addToArchive" and "extractFiles" need UI, so activate the app
        let needsUI = (action == "addToArchive" || action == "extractFiles")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = needsUI
        
        NSWorkspace.shared.open(url, configuration: config) { _, error in
            if let error = error {
                Self.logger.error("Failed to open URL: \(error.localizedDescription)")
            }
        }
    }
}
