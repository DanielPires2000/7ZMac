import Foundation
import os

/// Concrete implementation of `ArchiveServiceProtocol` using the bundled `7zz` binary.
final class SevenZipService: ArchiveServiceProtocol {
    
    private let executablePath: String
    
    /// Public access to the resolved executable path (for progress tracking).
    var executablePathValue: String { executablePath }
    
    /// Initialize with a specific path or auto-detect from the app bundle.
    init(executablePath: String? = nil) {
        if let executablePath {
            self.executablePath = executablePath
        } else if let bundled = Bundle.main.path(forResource: "7zz", ofType: nil) {
            self.executablePath = bundled
        } else if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/7zz") {
            self.executablePath = "/opt/homebrew/bin/7zz"
        } else {
            self.executablePath = "/usr/local/bin/7zz"
        }
    }
    
    func checkAvailability() -> Bool {
        FileManager.default.fileExists(atPath: executablePath)
    }
    
    func listContents(archive: URL) async throws -> [ArchiveItem] {
        let output = try await runProcess(arguments: ["l", "-slt", archive.path])
        return SevenZipOutputParser.parse(output)
    }
    
    func extract(archive: URL, to destination: URL) async throws {
        let outputFlag = "-o\(destination.path)"
        _ = try await runProcess(arguments: ["x", archive.path, outputFlag, "-y"])
    }
    
    func compress(files: [URL], to archive: URL) async throws {
        var arguments = ["a", archive.path]
        arguments.append(contentsOf: files.map { $0.path })
        _ = try await runProcess(arguments: arguments)
    }
    
    func compress(files: [URL], to archive: URL, options: CompressionOptions) async throws {
        let args = options.buildArguments(
            archivePath: archive.path,
            filePaths: files.map { $0.path }
        )
        _ = try await runProcess(arguments: args)
    }
    
    // MARK: - Private
    
    /// Execute 7zz with the given arguments and return stdout/stderr as a String.
    private func runProcess(arguments: [String]) async throws -> String {
        guard FileManager.default.fileExists(atPath: executablePath) else {
            throw SevenZipError.executableNotFound
        }
        
        // Log the full command for debugging
        Log.service.debug("Running: \(self.executablePath) \(arguments.joined(separator: " "))")

        return try await Task.detached(priority: .userInitiated) { [self] in
            let task = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            task.executableURL = URL(fileURLWithPath: self.executablePath)
            task.arguments = arguments
            task.standardOutput = stdoutPipe
            task.standardError = stderrPipe

            try task.run()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            let combinedData = stdoutData + stderrData

            guard let output = String(data: combinedData, encoding: .utf8) else {
                throw SevenZipError.outputDecodingFailed
            }

            guard task.terminationStatus == 0 else {
                throw SevenZipError.processFailure(
                    exitCode: task.terminationStatus,
                    output: output
                )
            }

            return output
        }.value
    }
}
