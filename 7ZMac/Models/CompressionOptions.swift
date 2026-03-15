import Foundation

/// All compression options for the "Add to Archive" dialog.
struct CompressionOptions {
    // Left column
    var archiveFormat: ArchiveFormat = .sevenZ
    var compressionLevel: CompressionLevel = .normal
    var compressionMethod: CompressionMethod = .lzma2
    var dictionarySize: DictionarySize = .auto
    var wordSize: WordSize = .auto
    var solidBlockSize: SolidBlockSize = .auto
    var cpuThreads: Int = ProcessInfo.processInfo.activeProcessorCount
    var splitToVolumes: String = ""
    var parameters: String = ""
    
    // Right column
    var updateMode: UpdateMode = .addAndReplace
    var pathMode: PathMode = .relativePaths
    var createSFX: Bool = false
    var compressSharedFiles: Bool = false
    var deleteAfterCompression: Bool = false
    
    // Encryption
    var password: String = ""
    var confirmPassword: String = ""
    var encryptFileNames: Bool = false
    var encryptionMethod: EncryptionMethod = .aes256
    
    /// Build 7zz command-line arguments from these options.
    func buildArguments(archivePath: String, filePaths: [String]) -> [String] {
        var args = ["a"]
        
        // Archive type
        args.append("-t\(archiveFormat.flag)")
        
        // Compression level
        args.append("-mx=\(compressionLevel.rawValue)")
        
        // Compression method (only for 7z and zip)
        if archiveFormat == .sevenZ || archiveFormat == .zip {
            args.append("-m0=\(compressionMethod.flag)")
        }
        
        // Dictionary size
        if dictionarySize != .auto {
            args.append("-md=\(dictionarySize.flag)")
        }
        
        // Word size
        if wordSize != .auto {
            args.append("-mfb=\(wordSize.flag)")
        }
        
        // Solid block size (7z only)
        if archiveFormat == .sevenZ && solidBlockSize != .auto {
            args.append("-ms=\(solidBlockSize.flag)")
        }
        
        // CPU threads
        args.append("-mmt=\(cpuThreads)")
        
        // Password
        if !password.isEmpty {
            args.append("-p\(password)")
            if encryptFileNames && archiveFormat == .sevenZ {
                args.append("-mhe=on")
            }
        }
        
        // SFX
        if createSFX && archiveFormat == .sevenZ {
            args.append("-sfx")
        }
        
        // Shared files
        if compressSharedFiles {
            args.append("-ssw")
        }
        
        // Delete after compression
        if deleteAfterCompression {
            args.append("-sdel")
        }
        
        // Split volumes
        if !splitToVolumes.isEmpty {
            args.append("-v\(splitToVolumes)")
        }
        
        // Update mode
        args.append(contentsOf: updateMode.flags)
        
        // Path mode
        args.append(contentsOf: pathMode.flags)
        
        // Custom parameters
        if !parameters.isEmpty {
            let parts = parameters.split(separator: " ").map(String.init)
            args.append(contentsOf: parts)
        }
        
        args.append(archivePath)
        args.append(contentsOf: filePaths)
        
        return args
    }
    
    /// Estimated memory usage for compression (MB).
    var estimatedCompressionMemory: Int {
        let dictMB = dictionarySize.megabytes
        switch compressionMethod {
        case .lzma, .lzma2:
            return Int(Double(dictMB) * 11.5) + 64
        case .ppmd:
            return dictMB + 32
        case .bzip2:
            return dictMB * 7 + 32
        case .deflate:
            return 32
        }
    }
    
    /// Estimated memory usage for decompression (MB).
    var estimatedDecompressionMemory: Int {
        let dictMB = dictionarySize.megabytes
        switch compressionMethod {
        case .lzma, .lzma2:
            return dictMB + 2
        case .ppmd:
            return dictMB + 2
        case .bzip2:
            return 8
        case .deflate:
            return 2
        }
    }
}

// MARK: - Archive Format

enum ArchiveFormat: String, CaseIterable, Identifiable {
    case sevenZ = "7z"
    case zip = "zip"
    case tar = "tar"
    case gzip = "gzip"
    case bzip2 = "bzip2"
    case xz = "xz"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sevenZ: return "7z"
        case .zip:    return "zip"
        case .tar:    return "tar"
        case .gzip:   return "gzip"
        case .bzip2:  return "bzip2"
        case .xz:     return "xz"
        }
    }
    
    var flag: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .sevenZ: return "7z"
        case .zip:    return "zip"
        case .tar:    return "tar"
        case .gzip:   return "gz"
        case .bzip2:  return "bz2"
        case .xz:     return "xz"
        }
    }
    
    var availableMethods: [CompressionMethod] {
        switch self {
        case .sevenZ: return [.lzma2, .lzma, .ppmd, .bzip2, .deflate]
        case .zip:    return [.deflate, .bzip2, .lzma]
        case .gzip:   return [.deflate]
        case .bzip2:  return [.bzip2]
        case .xz:     return [.lzma2]
        case .tar:    return []
        }
    }
    
    var supportsSolid: Bool { self == .sevenZ }
    var supportsSFX: Bool { self == .sevenZ }
    var supportsEncryption: Bool { self == .sevenZ || self == .zip }
    var supportsEncryptFileNames: Bool { self == .sevenZ }
}

// MARK: - Compression Level

enum CompressionLevel: Int, CaseIterable, Identifiable {
    case store = 0
    case fastest = 1
    case fast = 3
    case normal = 5
    case maximum = 7
    case ultra = 9
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .store:   return "0 - Store"
        case .fastest: return "1 - Fastest"
        case .fast:    return "3 - Fast"
        case .normal:  return "5 - Normal"
        case .maximum: return "7 - Maximum"
        case .ultra:   return "9 - Ultra"
        }
    }
}

// MARK: - Compression Method

enum CompressionMethod: String, CaseIterable, Identifiable {
    case lzma2 = "LZMA2"
    case lzma = "LZMA"
    case ppmd = "PPMd"
    case bzip2 = "BZip2"
    case deflate = "Deflate"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    var flag: String { rawValue }
}

// MARK: - Dictionary Size

enum DictionarySize: String, CaseIterable, Identifiable {
    case auto   = "Auto"
    case kb64   = "64 KB"
    case kb256  = "256 KB"
    case mb1    = "1 MB"
    case mb2    = "2 MB"
    case mb4    = "4 MB"
    case mb8    = "8 MB"
    case mb16   = "16 MB"
    case mb32   = "32 MB"
    case mb64   = "64 MB"
    case mb128  = "128 MB"
    case mb256  = "256 MB"
    case mb512  = "512 MB"
    case mb1024 = "1 GB"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var flag: String {
        switch self {
        case .auto:   return ""
        case .kb64:   return "64k"
        case .kb256:  return "256k"
        case .mb1:    return "1m"
        case .mb2:    return "2m"
        case .mb4:    return "4m"
        case .mb8:    return "8m"
        case .mb16:   return "16m"
        case .mb32:   return "32m"
        case .mb64:   return "64m"
        case .mb128:  return "128m"
        case .mb256:  return "256m"
        case .mb512:  return "512m"
        case .mb1024: return "1024m"
        }
    }
    
    var megabytes: Int {
        switch self {
        case .auto:   return 16 // default
        case .kb64:   return 1
        case .kb256:  return 1
        case .mb1:    return 1
        case .mb2:    return 2
        case .mb4:    return 4
        case .mb8:    return 8
        case .mb16:   return 16
        case .mb32:   return 32
        case .mb64:   return 64
        case .mb128:  return 128
        case .mb256:  return 256
        case .mb512:  return 512
        case .mb1024: return 1024
        }
    }
}

// MARK: - Word Size

enum WordSize: String, CaseIterable, Identifiable {
    case auto  = "Auto"
    case w8    = "8"
    case w12   = "12"
    case w16   = "16"
    case w24   = "24"
    case w32   = "32"
    case w48   = "48"
    case w64   = "64"
    case w96   = "96"
    case w128  = "128"
    case w192  = "192"
    case w256  = "256"
    case w273  = "273"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    var flag: String { rawValue == "Auto" ? "" : rawValue }
}

// MARK: - Solid Block Size

enum SolidBlockSize: String, CaseIterable, Identifiable {
    case auto    = "Auto"
    case nonSolid = "Non-solid"
    case mb1     = "1 MB"
    case mb16    = "16 MB"
    case mb128   = "128 MB"
    case mb1024  = "1 GB"
    case mb4096  = "4 GB"
    case mb16384 = "16 GB"
    case solid   = "Solid"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var flag: String {
        switch self {
        case .auto:     return ""
        case .nonSolid: return "off"
        case .mb1:      return "1m"
        case .mb16:     return "16m"
        case .mb128:    return "128m"
        case .mb1024:   return "1g"
        case .mb4096:   return "4g"
        case .mb16384:  return "16g"
        case .solid:    return "on"
        }
    }
}

// MARK: - Update Mode

enum UpdateMode: String, CaseIterable, Identifiable {
    case addAndReplace    = "Add and replace files"
    case update           = "Update and add files"
    case freshen          = "Freshen existing files"
    case synchronize      = "Synchronize files"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var flags: [String] {
        switch self {
        case .addAndReplace: return []
        case .update:        return ["-u"]
        case .freshen:       return ["-uf"]
        case .synchronize:   return ["-us"]
        }
    }
}

// MARK: - Path Mode

enum PathMode: String, CaseIterable, Identifiable {
    case relativePaths  = "Relative pathnames"
    case fullPaths      = "Full pathnames"
    case absolutePaths  = "Absolute pathnames"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var flags: [String] {
        switch self {
        case .relativePaths: return []
        case .fullPaths:     return ["-spf2"]
        case .absolutePaths: return ["-spf"]
        }
    }
}

// MARK: - Encryption Method

enum EncryptionMethod: String, CaseIterable, Identifiable {
    case aes256 = "AES-256"
    case zipcrypto = "ZipCrypto"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}
