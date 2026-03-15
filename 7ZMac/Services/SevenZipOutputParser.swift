import Foundation

/// Pure parsing logic for `7zz l -slt` output.
/// Extracted for testability — no process execution, just string parsing.
enum SevenZipOutputParser {
    
    /// Parse the technical listing output from `7zz l -slt <archive>` into `ArchiveItem` objects.
    static func parse(_ output: String) -> [ArchiveItem] {
        var items: [ArchiveItem] = []
        var currentAttributes: [String: String] = [:]
        
        let lines = output.components(separatedBy: .newlines)
        var isScanningItems = false
        
        for line in lines {
            if line.hasPrefix("----------") {
                if !currentAttributes.isEmpty {
                    if let item = createArchiveItem(from: currentAttributes) {
                        items.append(item)
                    }
                    currentAttributes = [:]
                }
                isScanningItems = true
                continue
            }
            
            if !isScanningItems { continue }
            
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !currentAttributes.isEmpty {
                    if let item = createArchiveItem(from: currentAttributes) {
                        items.append(item)
                    }
                    currentAttributes = [:]
                }
                continue
            }
            
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                currentAttributes[parts[0]] = parts[1]
            }
        }
        
        // Append last item if exists
        if !currentAttributes.isEmpty {
            if let item = createArchiveItem(from: currentAttributes) {
                items.append(item)
            }
        }
        
        return items
    }
    
    // MARK: - Private
    
    private static func createArchiveItem(from attributes: [String: String]) -> ArchiveItem? {
        guard let path = attributes["Path"] else { return nil }
        
        let isFolder = attributes["Attributes"]?.contains("D") ?? false
        
        return ArchiveItem(
            path: path,
            size: attributes["Size"] ?? "",
            packedSize: attributes["Packed Size"] ?? "",
            modified: attributes["Modified"] ?? "",
            attributes: attributes["Attributes"] ?? "",
            isFolder: isFolder
        )
    }
}
