import XCTest
@testable import _ZMac

final class SplitArchiveDetectorTests: XCTestCase {
    
    // MARK: - isFirstVolume
    
    func testIsFirstVolume001() {
        let url = URL(fileURLWithPath: "/path/archive.7z.001")
        XCTAssertTrue(SplitArchiveDetector.isFirstVolume(url))
    }
    
    func testIsNotFirstVolume002() {
        let url = URL(fileURLWithPath: "/path/archive.7z.002")
        XCTAssertFalse(SplitArchiveDetector.isFirstVolume(url))
    }
    
    func testIsFirstVolumePart1Rar() {
        let url = URL(fileURLWithPath: "/path/archive.part1.rar")
        XCTAssertTrue(SplitArchiveDetector.isFirstVolume(url))
    }
    
    func testIsNotFirstVolumePart2Rar() {
        let url = URL(fileURLWithPath: "/path/archive.part2.rar")
        XCTAssertFalse(SplitArchiveDetector.isFirstVolume(url))
    }
    
    func testIsFirstVolumeZ01() {
        let url = URL(fileURLWithPath: "/path/archive.z01")
        XCTAssertTrue(SplitArchiveDetector.isFirstVolume(url))
    }
    
    func testIsNotFirstVolumeZ05() {
        let url = URL(fileURLWithPath: "/path/archive.z05")
        XCTAssertFalse(SplitArchiveDetector.isFirstVolume(url))
    }
    
    func testIsNotFirstVolumeRegularFile() {
        let url = URL(fileURLWithPath: "/path/readme.txt")
        XCTAssertFalse(SplitArchiveDetector.isFirstVolume(url))
    }
    
    func testIsNotFirstVolumeRegular7z() {
        let url = URL(fileURLWithPath: "/path/archive.7z")
        XCTAssertFalse(SplitArchiveDetector.isFirstVolume(url))
    }
    
    // MARK: - isSplitVolumePart
    
    func testIsSplitVolumePart001() {
        let url = URL(fileURLWithPath: "/path/archive.7z.001")
        XCTAssertTrue(SplitArchiveDetector.isSplitVolumePart(url))
    }
    
    func testIsSplitVolumePart003() {
        let url = URL(fileURLWithPath: "/path/archive.zip.003")
        XCTAssertTrue(SplitArchiveDetector.isSplitVolumePart(url))
    }
    
    func testIsSplitVolumePartPart5Rar() {
        let url = URL(fileURLWithPath: "/path/archive.part5.rar")
        XCTAssertTrue(SplitArchiveDetector.isSplitVolumePart(url))
    }
    
    func testIsNotSplitVolumePartRegularFile() {
        let url = URL(fileURLWithPath: "/path/readme.txt")
        XCTAssertFalse(SplitArchiveDetector.isSplitVolumePart(url))
    }
    
    // MARK: - baseName
    
    func testBaseName7z001() {
        let url = URL(fileURLWithPath: "/path/archive.7z.001")
        XCTAssertEqual(SplitArchiveDetector.baseName(of: url), "archive.7z")
    }
    
    func testBaseNameZip003() {
        let url = URL(fileURLWithPath: "/path/backup.zip.003")
        XCTAssertEqual(SplitArchiveDetector.baseName(of: url), "backup.zip")
    }
    
    func testBaseNamePart1Rar() {
        let url = URL(fileURLWithPath: "/path/movie.part1.rar")
        XCTAssertEqual(SplitArchiveDetector.baseName(of: url), "movie")
    }
    
    func testBaseNameZ01() {
        let url = URL(fileURLWithPath: "/path/data.z01")
        XCTAssertEqual(SplitArchiveDetector.baseName(of: url), "data")
    }
    
    func testBaseNamePlain001() {
        let url = URL(fileURLWithPath: "/path/archive.001")
        XCTAssertEqual(SplitArchiveDetector.baseName(of: url), "archive")
    }
    
    func testBaseNameRegularFile() {
        let url = URL(fileURLWithPath: "/path/readme.txt")
        XCTAssertNil(SplitArchiveDetector.baseName(of: url))
    }
    
    // MARK: - group
    
    func testGroupMultipleSplitParts() {
        let files = [
            URL(fileURLWithPath: "/path/archive.7z.001"),
            URL(fileURLWithPath: "/path/archive.7z.002"),
            URL(fileURLWithPath: "/path/archive.7z.003"),
        ]
        
        let result = SplitArchiveDetector.group(files: files)
        
        XCTAssertEqual(result.splitFirstVolumes.count, 1)
        XCTAssertEqual(result.splitFirstVolumes.first?.lastPathComponent, "archive.7z.001")
        XCTAssertEqual(result.skippedParts.count, 2)
        XCTAssertTrue(result.standaloneFiles.isEmpty)
    }
    
    func testGroupMixedSplitAndStandalone() {
        let files = [
            URL(fileURLWithPath: "/path/archive.7z.001"),
            URL(fileURLWithPath: "/path/archive.7z.002"),
            URL(fileURLWithPath: "/path/other.zip"),
        ]
        
        let result = SplitArchiveDetector.group(files: files)
        
        XCTAssertEqual(result.splitFirstVolumes.count, 1)
        XCTAssertEqual(result.splitFirstVolumes.first?.lastPathComponent, "archive.7z.001")
        XCTAssertEqual(result.skippedParts.count, 1)
        XCTAssertEqual(result.standaloneFiles.count, 1)
        XCTAssertEqual(result.standaloneFiles.first?.lastPathComponent, "other.zip")
    }
    
    func testGroupOnlyStandaloneFiles() {
        let files = [
            URL(fileURLWithPath: "/path/file1.7z"),
            URL(fileURLWithPath: "/path/file2.zip"),
        ]
        
        let result = SplitArchiveDetector.group(files: files)
        
        XCTAssertTrue(result.splitFirstVolumes.isEmpty)
        XCTAssertTrue(result.skippedParts.isEmpty)
        XCTAssertEqual(result.standaloneFiles.count, 2)
    }
    
    func testGroupTwoSplitSets() {
        let files = [
            URL(fileURLWithPath: "/path/archive.7z.001"),
            URL(fileURLWithPath: "/path/archive.7z.002"),
            URL(fileURLWithPath: "/path/backup.zip.001"),
            URL(fileURLWithPath: "/path/backup.zip.002"),
            URL(fileURLWithPath: "/path/backup.zip.003"),
        ]
        
        let result = SplitArchiveDetector.group(files: files)
        
        XCTAssertEqual(result.splitFirstVolumes.count, 2)
        XCTAssertEqual(result.skippedParts.count, 3)
        XCTAssertTrue(result.standaloneFiles.isEmpty)
        
        let firstNames = Set(result.splitFirstVolumes.map { $0.lastPathComponent })
        XCTAssertTrue(firstNames.contains("archive.7z.001"))
        XCTAssertTrue(firstNames.contains("backup.zip.001"))
    }
    
    // MARK: - resolveForExtraction
    
    func testResolveForExtractionWithSplitArchive() {
        let files = [
            URL(fileURLWithPath: "/path/archive.7z.001"),
            URL(fileURLWithPath: "/path/archive.7z.002"),
            URL(fileURLWithPath: "/path/archive.7z.003"),
        ]
        
        let resolved = SplitArchiveDetector.resolveForExtraction(files: files)
        
        // Should return only the first volume
        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved.first?.lastPathComponent, "archive.7z.001")
    }
    
    func testResolveForExtractionWithStandaloneArchives() {
        let files = [
            URL(fileURLWithPath: "/path/a.7z"),
            URL(fileURLWithPath: "/path/b.zip"),
        ]
        
        let resolved = SplitArchiveDetector.resolveForExtraction(files: files)
        XCTAssertEqual(resolved.count, 2)
    }
    
    func testResolveForExtractionMixed() {
        let files = [
            URL(fileURLWithPath: "/path/split.7z.001"),
            URL(fileURLWithPath: "/path/split.7z.002"),
            URL(fileURLWithPath: "/path/standalone.zip"),
        ]
        
        let resolved = SplitArchiveDetector.resolveForExtraction(files: files)
        
        // 1 first volume + 1 standalone = 2
        XCTAssertEqual(resolved.count, 2)
        let names = Set(resolved.map { $0.lastPathComponent })
        XCTAssertTrue(names.contains("split.7z.001"))
        XCTAssertTrue(names.contains("standalone.zip"))
    }

    // MARK: - extraction targets

    func testMakeExtractionTargetsForSameDirectory() {
        let files = [
            URL(fileURLWithPath: "/path/archive.7z")
        ]

        let targets = SplitArchiveDetector.makeExtractionTargets(files: files, strategy: .sameDirectory)

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.archiveURL.path, "/path/archive.7z")
        XCTAssertEqual(targets.first?.destinationURL.path, "/path")
    }

    func testMakeExtractionTargetsForSubfolderUsesArchiveName() {
        let files = [
            URL(fileURLWithPath: "/path/archive.7z")
        ]

        let targets = SplitArchiveDetector.makeExtractionTargets(files: files, strategy: .subfolder)

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.destinationURL.path, "/path/archive")
    }

    func testMakeExtractionTargetsForSubfolderUsesSplitBaseName() {
        let files = [
            URL(fileURLWithPath: "/path/archive.7z.001"),
            URL(fileURLWithPath: "/path/archive.7z.002")
        ]

        let targets = SplitArchiveDetector.makeExtractionTargets(files: files, strategy: .subfolder)

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.archiveURL.lastPathComponent, "archive.7z.001")
        XCTAssertEqual(targets.first?.destinationURL.path, "/path/archive")
    }
}
