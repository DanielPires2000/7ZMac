import os

/// Centralized logging for the 7ZMac app using `os.Logger`.
///
/// Usage:
/// ```swift
/// Log.app.info("Processing \(files.count) files")
/// Log.service.error("Failed to run 7zz: \(error)")
/// ```
enum Log {
    private static let subsystem = "com.danielpires.SevenZMac"
    
    /// General app lifecycle and UI events.
    static let app = Logger(subsystem: subsystem, category: "app")
    
    /// Archive service operations (compress, extract, list).
    static let service = Logger(subsystem: subsystem, category: "service")
    
    /// Compression/extraction progress tracking.
    static let progress = Logger(subsystem: subsystem, category: "progress")
    
    /// Split archive detection and resolution.
    static let archive = Logger(subsystem: subsystem, category: "archive")
}
