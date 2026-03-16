import Foundation
import os

/// Utility to detect and group split/multi-volume archives.
///
/// Common split archive patterns:
/// - `archive.7z.001`, `archive.7z.002`, ...
/// - `archive.zip.001`, `archive.zip.002`, ...
/// - `archive.001`, `archive.002`, ...
/// - `archive.part1.rar`, `archive.part2.rar`, ...
/// - `archive.z01`, `archive.z02`, ..., `archive.zip`
///
/// 7zz only needs the **first volume** — it finds the rest automatically.
enum SplitArchiveDetector {

    enum ExtractionStrategy {
        case sameDirectory
        case subfolder
    }

    struct ExtractionTarget {
        let archiveURL: URL
        let destinationURL: URL
    }
    
    /// Result of grouping files into split archives and standalone files.
    struct GroupResult {
        /// First volumes of detected split archives. Pass these to 7zz.
        let splitFirstVolumes: [URL]
        /// Files that are NOT part of a split set (standalone archives or regular files).
        let standaloneFiles: [URL]
        /// Files that are secondary parts of a split set (should be skipped).
        let skippedParts: [URL]
    }
    
    // MARK: - Volume number patterns
    
    /// Regex patterns that match volume numbering in file names.
    /// Each pattern captures a "base name" (group 1) and optionally the volume number.
    private static let volumePatterns: [(regex: String, firstSuffix: String)] = [
        // archive.7z.001, archive.zip.002, archive.tar.003
        (#"^(.+\.\w+)\.(\d{3,})$"#, ".001"),
        // archive.part1.rar, archive.part01.rar
        (#"^(.+)\.part(\d+)\.rar$"#, ".part1.rar"),
        // archive.z01, archive.z02 (zip split) — the main file is archive.zip
        (#"^(.+)\.z(\d{2})$"#, ".z01"),
        // archive.001, archive.002 (plain numbered)
        (#"^(.+)\.(\d{3,})$"#, ".001"),
    ]
    
    /// Check if a single file looks like a split volume part.
    static func isSplitVolumePart(_ url: URL) -> Bool {
        let filename = url.lastPathComponent
        for (pattern, _) in volumePatterns {
            if filename.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    /// Check if a single file is the first volume of a split set.
    static func isFirstVolume(_ url: URL) -> Bool {
        let filename = url.lastPathComponent
        
        // archive.7z.001, archive.zip.001, etc.
        if let match = filename.range(of: #"\.(\d{3,})$"#, options: .regularExpression) {
            let numStr = filename[match].trimmingCharacters(in: .init(charactersIn: "."))
            return Int(numStr) == 1
        }
        
        // archive.part1.rar
        if let match = filename.range(of: #"\.part(\d+)\.rar$"#, options: .regularExpression) {
            let sub = filename[match]
            let numStr = sub.replacingOccurrences(of: ".part", with: "").replacingOccurrences(of: ".rar", with: "")
            return Int(numStr) == 1
        }
        
        // archive.z01
        if let match = filename.range(of: #"\.z(\d{2})$"#, options: .regularExpression) {
            let numStr = filename[match].trimmingCharacters(in: .init(charactersIn: ".z"))
            return Int(numStr) == 1
        }
        
        return false
    }
    
    /// Extract the base name of a split volume (without the volume suffix).
    static func baseName(of url: URL) -> String? {
        let filename = url.lastPathComponent
        
        for (pattern, _) in volumePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(filename.startIndex..., in: filename)
            if let match = regex.firstMatch(in: filename, range: range),
               let baseRange = Range(match.range(at: 1), in: filename) {
                return String(filename[baseRange])
            }
        }
        
        return nil
    }
    
    /// Group an array of file URLs into split archive sets and standalone files.
    ///
    /// - For each set of split volumes found, only the first volume URL is returned.
    /// - Files that are secondary parts are placed in `skippedParts`.
    /// - Files not matching any split pattern go to `standaloneFiles`.
    static func group(files: [URL]) -> GroupResult {
        var groups: [String: [URL]] = [:]   // baseName -> [volume URLs]
        var standalone: [URL] = []
        
        for file in files {
            if let base = baseName(of: file) {
                groups[base, default: []].append(file)
            } else {
                standalone.append(file)
            }
        }
        
        var firstVolumes: [URL] = []
        var skipped: [URL] = []
        
        for (_, volumes) in groups {
            // Sort by filename to ensure .001 comes first
            let sorted = volumes.sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            if sorted.count == 1 {
                // Only one file with a volume-like name
                // Check if other parts exist on disk
                let url = sorted[0]
                if hasOtherPartsOnDisk(url) {
                    // It's part of a split archive
                    if isFirstVolume(url) {
                        firstVolumes.append(url)
                    } else {
                        skipped.append(url)
                    }
                } else {
                    // Looks like a volume but no siblings — might be standalone
                    // Still try to pass it to 7zz, it handles this gracefully
                    standalone.append(url)
                }
            } else {
                // Multiple parts selected — find the first volume
                if let first = sorted.first(where: { isFirstVolume($0) }) {
                    firstVolumes.append(first)
                    skipped.append(contentsOf: sorted.filter { $0 != first })
                } else {
                    // No .001 found among selected — try the first sorted one
                    firstVolumes.append(sorted[0])
                    skipped.append(contentsOf: sorted.dropFirst())
                }
            }
        }
        
        return GroupResult(
            splitFirstVolumes: firstVolumes,
            standaloneFiles: standalone,
            skippedParts: skipped
        )
    }
    
    /// Check if sibling volume parts exist on disk next to the given URL.
    private static func hasOtherPartsOnDisk(_ url: URL) -> Bool {
        guard let base = baseName(of: url) else { return false }
        let directory = url.deletingLastPathComponent()
        
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return false }
        
        let siblings = contents.filter { sibling in
            sibling != url && baseName(of: sibling) == base
        }
        
        return !siblings.isEmpty
    }
    
    /// Given a list of files, resolve them for extraction:
    /// groups split volumes and returns only the URLs to pass to 7zz.
    static func resolveForExtraction(files: [URL]) -> [URL] {
        let result = group(files: files)
        let resolved = result.splitFirstVolumes + result.standaloneFiles
        
        if !result.skippedParts.isEmpty {
            let skippedNames = result.skippedParts.map { $0.lastPathComponent }.joined(separator: ", ")
            Log.archive.info("Skipping split volume parts (will be handled via first volume): \(skippedNames)")
        }
        
        if !result.splitFirstVolumes.isEmpty {
            let firstNames = result.splitFirstVolumes.map { $0.lastPathComponent }.joined(separator: ", ")
            Log.archive.info("Detected split archives, using first volumes: \(firstNames)")
        }
        
        return resolved
    }

    static func makeExtractionTargets(files: [URL], strategy: ExtractionStrategy) -> [ExtractionTarget] {
        resolveForExtraction(files: files).map { archiveURL in
            let destinationURL: URL

            switch strategy {
            case .sameDirectory:
                destinationURL = archiveURL.deletingLastPathComponent()

            case .subfolder:
                let folderName = defaultExtractionFolderName(for: archiveURL)
                destinationURL = archiveURL.deletingLastPathComponent().appendingPathComponent(folderName)
            }

            return ExtractionTarget(
                archiveURL: archiveURL,
                destinationURL: destinationURL
            )
        }
    }

    private static func defaultExtractionFolderName(for archiveURL: URL) -> String {
        if let baseName = baseName(of: archiveURL) {
            return (baseName as NSString).deletingPathExtension
        }

        return archiveURL.deletingPathExtension().lastPathComponent
    }
}
