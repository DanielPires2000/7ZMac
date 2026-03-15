import XCTest
@testable import _ZMac

@MainActor
final class ArchiveViewModelTests: XCTestCase {
    
    private var mockService: MockArchiveService!
    private var container: DIContainer!
    
    override func setUp() {
        super.setUp()
        container = DIContainer.shared
        mockService = MockArchiveService()
        container.register(ArchiveServiceProtocol.self) { [unowned self] in self.mockService }
    }
    
    override func tearDown() {
        container.reset()
        mockService = nil
        container = nil
        super.tearDown()
    }
    
    // MARK: - Service via Container
    
    func testResolvedServiceReturnsMockData() async {
        let service: ArchiveServiceProtocol = container.resolve()
        let items = try? await service.listContents(archive: URL(fileURLWithPath: "/tmp/test.7z"))
        
        XCTAssertNotNil(items)
        XCTAssertEqual(items?.count, ArchiveItem.mocks.count)
    }
    
    // MARK: - Error Handling
    
    func testServiceThrowsError() async {
        mockService.shouldThrow = true
        
        do {
            let service: ArchiveServiceProtocol = container.resolve()
            _ = try await service.listContents(archive: URL(fileURLWithPath: "/tmp/test.7z"))
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is SevenZipError)
        }
    }
    
    // MARK: - Availability
    
    func testServiceAvailability() {
        let service: ArchiveServiceProtocol = container.resolve()
        XCTAssertTrue(service.checkAvailability())
    }
    
    // MARK: - Compress with Options
    
    func testCompressWithOptionsMock() async {
        let service: ArchiveServiceProtocol = container.resolve()
        let options = CompressionOptions()
        
        do {
            try await service.compress(
                files: [URL(fileURLWithPath: "/tmp/test.txt")],
                to: URL(fileURLWithPath: "/tmp/test.7z"),
                options: options
            )
        } catch {
            XCTFail("Mock compress should not throw: \(error)")
        }
    }
    
    func testCompressWithOptionsThrows() async {
        mockService.shouldThrow = true
        let service: ArchiveServiceProtocol = container.resolve()
        let options = CompressionOptions()
        
        do {
            try await service.compress(
                files: [URL(fileURLWithPath: "/tmp/test.txt")],
                to: URL(fileURLWithPath: "/tmp/test.7z"),
                options: options
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is SevenZipError)
        }
    }
}
