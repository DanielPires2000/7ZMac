import XCTest
@testable import _ZMac

final class SevenZipOutputParserTests: XCTestCase {
    
    // MARK: - Real Output
    
    func testParseRealOutput() {
        let output = """
        7-Zip (z) 26.00 (arm64) : Copyright (c) 1999-2026 Igor Pavlov : 2026-02-12
         64-bit arm_v:8.5-A locale=C.UTF-8 Threads:10 OPEN_MAX:1048575, ASM

        Scanning the drive for archives:
        1 file, 138 bytes (1 KiB)

        Listing archive: test.7z

        --
        Path = test.7z
        Type = 7z
        Physical Size = 138
        Headers Size = 122
        Method = LZMA2:12
        Solid = -
        Blocks = 1

        ----------
        Path = test.txt
        Size = 12
        Packed Size = 16
        Modified = 2026-02-15 23:32:05.5192110
        Attributes = A -rw-r--r--
        CRC = B095E5E3
        Encrypted = -
        Method = LZMA2:12
        Block = 0
        """
        
        let items = SevenZipOutputParser.parse(output)
        
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "test.txt")
        XCTAssertEqual(items[0].size, "12")
        XCTAssertEqual(items[0].packedSize, "16")
        XCTAssertFalse(items[0].isFolder)
    }
    
    // MARK: - Multiple Items
    
    func testParseMultipleItems() {
        let output = """
        ----------
        Path = folder
        Size = 0
        Packed Size = 0
        Modified = 2026-01-01 10:00:00
        Attributes = D drwxr-xr-x

        ----------
        Path = folder/file1.txt
        Size = 100
        Packed Size = 50
        Modified = 2026-01-02 11:00:00
        Attributes = A -rw-r--r--

        ----------
        Path = folder/file2.pdf
        Size = 2048
        Packed Size = 1024
        Modified = 2026-01-03 12:00:00
        Attributes = A -rw-r--r--
        """
        
        let items = SevenZipOutputParser.parse(output)
        
        XCTAssertEqual(items.count, 3)
        
        // First item is a folder
        XCTAssertEqual(items[0].name, "folder")
        XCTAssertTrue(items[0].isFolder)
        
        // Second item is a file
        XCTAssertEqual(items[1].name, "file1.txt")
        XCTAssertFalse(items[1].isFolder)
        XCTAssertEqual(items[1].size, "100")
        
        // Third item
        XCTAssertEqual(items[2].name, "file2.pdf")
        XCTAssertEqual(items[2].packedSize, "1024")
    }
    
    // MARK: - Edge Cases
    
    func testParseEmptyOutput() {
        let items = SevenZipOutputParser.parse("")
        XCTAssertTrue(items.isEmpty)
    }
    
    func testParseHeaderOnlyOutput() {
        let output = """
        7-Zip (z) 26.00 (arm64) : Copyright (c) 1999-2026 Igor Pavlov

        Listing archive: empty.7z

        --
        Path = empty.7z
        Type = 7z
        Physical Size = 32
        """
        
        let items = SevenZipOutputParser.parse(output)
        XCTAssertTrue(items.isEmpty)
    }
    
    func testParseMalformedLines() {
        let output = """
        ----------
        Path = valid.txt
        Size = 100
        this line has no equals sign
        = missing key
        Modified = 2026-01-01 10:00:00
        Attributes = A -rw-r--r--
        """
        
        let items = SevenZipOutputParser.parse(output)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "valid.txt")
    }
    
    func testParseItemWithoutPath() {
        let output = """
        ----------
        Size = 100
        Packed Size = 50
        """
        
        let items = SevenZipOutputParser.parse(output)
        XCTAssertTrue(items.isEmpty, "Items without a Path should be skipped")
    }
}
