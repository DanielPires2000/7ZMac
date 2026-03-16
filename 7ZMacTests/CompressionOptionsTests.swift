import XCTest
@testable import _ZMac

/// Tests for `CompressionOptions.buildArguments()` — verifies correct 7zz CLI flag generation.
final class CompressionOptionsTests: XCTestCase {
    
    private let testArchive = "/tmp/test.7z"
    private let testFiles = ["/tmp/file1.txt", "/tmp/file2.txt"]
    
    // MARK: - Default Arguments
    
    func testDefaultOptions() {
        let options = CompressionOptions()
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        // Should contain: a -t7z -mx=5 -m0=LZMA2 -mmt=<cpuCount> <archive> <files>
        XCTAssertEqual(args.first, "a")
        XCTAssertTrue(args.contains("-t7z"))
        XCTAssertTrue(args.contains("-mx=5")) // Normal level
        XCTAssertTrue(args.contains("-m0=LZMA2"))
        XCTAssertTrue(args.contains(testArchive))
        XCTAssertTrue(args.contains(testFiles[0]))
        XCTAssertTrue(args.contains(testFiles[1]))
    }
    
    // MARK: - Archive Format
    
    func testArchiveFormatZip() {
        var options = CompressionOptions()
        options.archiveFormat = .zip
        options.compressionMethod = .deflate
        let args = options.buildArguments(archivePath: "/tmp/test.zip", filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-tzip"))
        XCTAssertTrue(args.contains("-m0=Deflate"))
    }
    
    func testArchiveFormatTar() {
        var options = CompressionOptions()
        options.archiveFormat = .tar
        let args = options.buildArguments(archivePath: "/tmp/test.tar", filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-ttar"))
        // tar does not support compression method
        XCTAssertFalse(args.contains { $0.hasPrefix("-m0=") })
    }
    
    func testArchiveFormatGzip() {
        var options = CompressionOptions()
        options.archiveFormat = .gzip
        options.compressionMethod = .deflate
        let args = options.buildArguments(archivePath: "/tmp/test.gz", filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-tgzip"))
    }
    
    func testArchiveFormatXz() {
        var options = CompressionOptions()
        options.archiveFormat = .xz
        options.compressionMethod = .lzma2
        let args = options.buildArguments(archivePath: "/tmp/test.xz", filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-txz"))
    }

    // MARK: - Quick Compression Commands

    func testQuickCompressionCommandFor7z() {
        let files = [URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")]

        let command = QuickCompressionCommand(format: .sevenZ, files: files)

        XCTAssertEqual(command?.title, "a.7z")
        XCTAssertEqual(command?.archiveURL.path, "/tmp/a.7z")
        XCTAssertEqual(command?.arguments, ["a", "-t7z", "/tmp/a.7z", "/tmp/a.txt", "/tmp/b.txt"])
    }

    func testQuickCompressionCommandForZip() {
        let files = [URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")]

        let command = QuickCompressionCommand(format: .zip, files: files)

        XCTAssertEqual(command?.title, "a.zip")
        XCTAssertEqual(command?.archiveURL.path, "/tmp/a.zip")
        XCTAssertEqual(command?.arguments, ["a", "-tzip", "/tmp/a.zip", "/tmp/a.txt", "/tmp/b.txt"])
    }

    func testQuickCompressionCommandRejectsEmptyFiles() {
        XCTAssertNil(QuickCompressionCommand(format: .sevenZ, files: []))
    }
    
    // MARK: - Compression Level
    
    func testCompressionLevelStore() {
        var options = CompressionOptions()
        options.compressionLevel = .store
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-mx=0"))
    }
    
    func testCompressionLevelUltra() {
        var options = CompressionOptions()
        options.compressionLevel = .ultra
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-mx=9"))
    }
    
    func testCompressionLevelFastest() {
        var options = CompressionOptions()
        options.compressionLevel = .fastest
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-mx=1"))
    }
    
    func testCompressionLevelMaximum() {
        var options = CompressionOptions()
        options.compressionLevel = .maximum
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-mx=7"))
    }
    
    // MARK: - Compression Method
    
    func testCompressionMethodLZMA() {
        var options = CompressionOptions()
        options.compressionMethod = .lzma
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-m0=LZMA"))
    }
    
    func testCompressionMethodPPMd() {
        var options = CompressionOptions()
        options.compressionMethod = .ppmd
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-m0=PPMd"))
    }
    
    func testCompressionMethodBZip2() {
        var options = CompressionOptions()
        options.compressionMethod = .bzip2
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-m0=BZip2"))
    }
    
    // MARK: - Dictionary Size
    
    func testDictionarySizeAuto() {
        var options = CompressionOptions()
        options.dictionarySize = .auto
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        // Auto should NOT add -md flag
        XCTAssertFalse(args.contains { $0.hasPrefix("-md=") })
    }
    
    func testDictionarySize64KB() {
        var options = CompressionOptions()
        options.dictionarySize = .kb64
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-md=64k"))
    }
    
    func testDictionarySize512MB() {
        var options = CompressionOptions()
        options.dictionarySize = .mb512
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-md=512m"))
    }
    
    // MARK: - Word Size
    
    func testWordSizeAuto() {
        var options = CompressionOptions()
        options.wordSize = .auto
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertFalse(args.contains { $0.hasPrefix("-mfb=") })
    }
    
    func testWordSize273() {
        var options = CompressionOptions()
        options.wordSize = .w273
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-mfb=273"))
    }
    
    // MARK: - Solid Block Size
    
    func testSolidBlockAutoNotAdded() {
        var options = CompressionOptions()
        options.solidBlockSize = .auto
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertFalse(args.contains { $0.hasPrefix("-ms=") })
    }
    
    func testSolidBlockNonSolid() {
        var options = CompressionOptions()
        options.solidBlockSize = .nonSolid
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-ms=off"))
    }
    
    func testSolidBlock16GB() {
        var options = CompressionOptions()
        options.solidBlockSize = .mb16384
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-ms=16g"))
    }
    
    func testSolidBlockNotAddedForZip() {
        var options = CompressionOptions()
        options.archiveFormat = .zip
        options.compressionMethod = .deflate
        options.solidBlockSize = .mb16384
        let args = options.buildArguments(archivePath: "/tmp/test.zip", filePaths: testFiles)
        
        // Solid blocks are only for 7z
        XCTAssertFalse(args.contains { $0.hasPrefix("-ms=") })
    }
    
    // MARK: - CPU Threads
    
    func testCPUThreads() {
        var options = CompressionOptions()
        options.cpuThreads = 4
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-mmt=4"))
    }
    
    func testCPUThreadsSingle() {
        var options = CompressionOptions()
        options.cpuThreads = 1
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-mmt=1"))
    }
    
    // MARK: - Password & Encryption
    
    func testPasswordAdded() {
        var options = CompressionOptions()
        options.password = "secret123"
        options.confirmPassword = "secret123"
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-psecret123"))
    }
    
    func testEmptyPasswordNotAdded() {
        let options = CompressionOptions()
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertFalse(args.contains { $0.hasPrefix("-p") })
    }
    
    func testEncryptFileNames7z() {
        var options = CompressionOptions()
        options.password = "secret"
        options.encryptFileNames = true
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-psecret"))
        XCTAssertTrue(args.contains("-mhe=on"))
    }
    
    func testEncryptFileNamesNotForZip() {
        var options = CompressionOptions()
        options.archiveFormat = .zip
        options.compressionMethod = .deflate
        options.password = "secret"
        options.encryptFileNames = true
        let args = options.buildArguments(archivePath: "/tmp/test.zip", filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-psecret"))
        // Encrypt file names is only for 7z
        XCTAssertFalse(args.contains("-mhe=on"))
    }
    
    // MARK: - SFX
    
    func testSFXEnabled() {
        var options = CompressionOptions()
        options.createSFX = true
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-sfx"))
    }
    
    func testSFXNotForZip() {
        var options = CompressionOptions()
        options.archiveFormat = .zip
        options.compressionMethod = .deflate
        options.createSFX = true
        let args = options.buildArguments(archivePath: "/tmp/test.zip", filePaths: testFiles)
        
        XCTAssertFalse(args.contains("-sfx"))
    }
    
    // MARK: - Shared Files & Delete After
    
    func testCompressSharedFiles() {
        var options = CompressionOptions()
        options.compressSharedFiles = true
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-ssw"))
    }
    
    func testDeleteAfterCompression() {
        var options = CompressionOptions()
        options.deleteAfterCompression = true
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-sdel"))
    }
    
    // MARK: - Split Volumes
    
    func testSplitVolumes() {
        var options = CompressionOptions()
        options.splitToVolumes = "700m"
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-v700m"))
    }
    
    func testEmptySplitNotAdded() {
        let options = CompressionOptions()
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertFalse(args.contains { $0.hasPrefix("-v") })
    }
    
    // MARK: - Update Mode
    
    func testUpdateModeDefault() {
        let options = CompressionOptions()
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        // Default (addAndReplace) should not add -u flags
        XCTAssertFalse(args.contains { $0.hasPrefix("-u") })
    }
    
    func testUpdateModeUpdate() {
        var options = CompressionOptions()
        options.updateMode = .update
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-u"))
    }
    
    // MARK: - Path Mode
    
    func testPathModeRelative() {
        let options = CompressionOptions()
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        // Default (relative) should not add -spf flags
        XCTAssertFalse(args.contains { $0.hasPrefix("-spf") })
    }
    
    func testPathModeFullPaths() {
        var options = CompressionOptions()
        options.pathMode = .fullPaths
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-spf2"))
    }
    
    func testPathModeAbsolute() {
        var options = CompressionOptions()
        options.pathMode = .absolutePaths
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-spf"))
    }
    
    // MARK: - Custom Parameters
    
    func testCustomParameters() {
        var options = CompressionOptions()
        options.parameters = "-bb3 -stl"
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-bb3"))
        XCTAssertTrue(args.contains("-stl"))
    }
    
    // MARK: - Memory Estimation
    
    func testMemoryEstimation() {
        var options = CompressionOptions()
        options.compressionMethod = .lzma2
        options.dictionarySize = .mb32
        
        XCTAssertGreaterThan(options.estimatedCompressionMemory, 0)
        XCTAssertGreaterThan(options.estimatedDecompressionMemory, 0)
        XCTAssertGreaterThan(options.estimatedCompressionMemory, options.estimatedDecompressionMemory)
    }
    
    func testMemoryEstimationPPMd() {
        var options = CompressionOptions()
        options.compressionMethod = .ppmd
        options.dictionarySize = .mb64
        
        XCTAssertGreaterThan(options.estimatedCompressionMemory, 0)
    }
    
    // MARK: - Full Ultra Configuration
    
    func testFullUltraConfig() {
        var options = CompressionOptions()
        options.archiveFormat = .sevenZ
        options.compressionLevel = .ultra
        options.compressionMethod = .lzma2
        options.dictionarySize = .mb512
        options.wordSize = .w273
        options.solidBlockSize = .mb16384
        options.cpuThreads = 8
        options.password = "test"
        options.encryptFileNames = true
        
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertTrue(args.contains("-t7z"))
        XCTAssertTrue(args.contains("-mx=9"))
        XCTAssertTrue(args.contains("-m0=LZMA2"))
        XCTAssertTrue(args.contains("-md=512m"))
        XCTAssertTrue(args.contains("-mfb=273"))
        XCTAssertTrue(args.contains("-ms=16g"))
        XCTAssertTrue(args.contains("-mmt=8"))
        XCTAssertTrue(args.contains("-ptest"))
        XCTAssertTrue(args.contains("-mhe=on"))
    }
    
    // MARK: - Argument Order
    
    func testArchivePathBeforeFiles() {
        let options = CompressionOptions()
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        let archiveIndex = args.firstIndex(of: testArchive)!
        let file1Index = args.firstIndex(of: testFiles[0])!
        let file2Index = args.firstIndex(of: testFiles[1])!
        
        XCTAssertLessThan(archiveIndex, file1Index)
        XCTAssertLessThan(archiveIndex, file2Index)
    }
    
    func testCommandIsFirst() {
        let options = CompressionOptions()
        let args = options.buildArguments(archivePath: testArchive, filePaths: testFiles)
        
        XCTAssertEqual(args.first, "a")
    }
    
    // MARK: - Format Capabilities
    
    func testSevenZSupportsAllFeatures() {
        let format = ArchiveFormat.sevenZ
        XCTAssertTrue(format.supportsSolid)
        XCTAssertTrue(format.supportsSFX)
        XCTAssertTrue(format.supportsEncryption)
        XCTAssertTrue(format.supportsEncryptFileNames)
    }
    
    func testZipLimitedFeatures() {
        let format = ArchiveFormat.zip
        XCTAssertFalse(format.supportsSolid)
        XCTAssertFalse(format.supportsSFX)
        XCTAssertTrue(format.supportsEncryption)
        XCTAssertFalse(format.supportsEncryptFileNames)
    }
    
    func testTarNoEncryption() {
        let format = ArchiveFormat.tar
        XCTAssertFalse(format.supportsEncryption)
        XCTAssertTrue(format.availableMethods.isEmpty)
    }
}
