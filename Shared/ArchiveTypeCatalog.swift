import Foundation

/// Shared archive extension catalog used by both the main app and Finder extension.
enum ArchiveTypeCatalog {
    static let baseExtensions: Set<String> = [
        "7z", "zip", "rar", "tar", "gz", "bz2", "xz", "lzma",
        "cab", "iso", "wim", "arj", "lzh", "z",
        "tgz", "tbz2", "txz",
        "rpm", "deb", "cpio",
        "vhd", "vhdx"
    ]

    static let splitVolumeExtensions: Set<String> = {
        var extensions: Set<String> = []

        for index in 1...999 {
            extensions.insert(String(format: "%03d", index))
        }

        for index in 1...99 {
            extensions.insert(String(format: "z%02d", index))
        }

        return extensions
    }()

    static let finderRecognizedExtensions = baseExtensions.union(splitVolumeExtensions)

    static func hasSupportedDoubleExtension(_ filename: String) -> Bool {
        let lowercased = filename.lowercased()
        return lowercased.hasSuffix(".tar.gz")
            || lowercased.hasSuffix(".tar.bz2")
            || lowercased.hasSuffix(".tar.xz")
    }
}
