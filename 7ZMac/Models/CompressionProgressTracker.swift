import Foundation
import os
internal import Combine

/// Observable model that tracks real-time compression/extraction progress
/// by parsing `7zz` stdout output line-by-line.
@MainActor
final class CompressionProgressTracker: ObservableObject {
    
    // MARK: - Published State
    
    @Published var progress: Double = 0           // 0..100
    @Published var currentFileName: String = ""
    @Published var filesProcessed: Int = 0
    @Published var totalFiles: Int = 0
    @Published var totalSize: String = ""
    @Published var processedSize: String = ""
    @Published var compressedSize: String = ""
    @Published var speed: String = ""
    @Published var compressionRatio: String = ""
    @Published var elapsedTime: TimeInterval = 0
    @Published var estimatedRemainingTime: TimeInterval = 0
    @Published var statusText: String = "Preparing..."
    @Published var isRunning: Bool = false
    @Published var isFinished: Bool = false
    @Published var errorMessage: String?
    @Published var archiveName: String = ""
    
    private var process: Process?
    private var startTime: Date?
    private var timer: Timer?
    private var totalSizeBytes: Int64 = 0
    private var processedBytes: Int64 = 0
    
    // MARK: - Run
    
    /// Start the 7zz process with real-time progress parsing using `-bsp1`.
    func run(executablePath: String, arguments: [String]) {
        isRunning = true
        isFinished = false
        errorMessage = nil
        startTime = Date()
        progress = 0
        filesProcessed = 0
        totalFiles = 0
        totalSize = ""
        processedSize = ""
        compressedSize = ""
        speed = ""
        compressionRatio = ""
        currentFileName = ""
        statusText = "Preparing..."
        totalSizeBytes = 0
        processedBytes = 0
        
        // Extract archive name from arguments
        if let aIdx = arguments.firstIndex(of: "a"), aIdx + 1 < arguments.count {
            let path = arguments[aIdx + 1]
            archiveName = URL(fileURLWithPath: path).lastPathComponent
        }
        
        // Insert progress flag if not present
        var args = arguments
        if !args.contains("-bsp1") {
            args.insert("-bsp1", at: 1) // after "a" command
        }
        
        Log.progress.info("Running with progress: \(executablePath) \(args.joined(separator: " "))")
        
        // Start elapsed time timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
        
        let tracker = self
        Task.detached {
            do {
                try await tracker.executeProcess(path: executablePath, arguments: args)
            } catch {
                await MainActor.run {
                    tracker.errorMessage = error.localizedDescription
                    tracker.statusText = "Error"
                    tracker.isRunning = false
                    tracker.isFinished = true
                    tracker.timer?.invalidate()
                }
            }
        }
    }
    
    /// Cancel the running process.
    func cancel() {
        process?.terminate()
        timer?.invalidate()
        isRunning = false
        isFinished = true
        statusText = "Cancelled"
    }
    
    // MARK: - Process Execution
    
    nonisolated private func executeProcess(path: String, arguments: [String]) async throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw SevenZipError.executableNotFound
        }
        
        let task = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe
        
        await MainActor.run { self.process = task }
        
        try task.run()
        
        // Read stdout asynchronously line by line
        let handle = stdoutPipe.fileHandleForReading
        
        // Read in a background context
        let data = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                var allData = Data()
                var lineBuffer = Data()
                
                while true {
                    let chunk = handle.availableData
                    if chunk.isEmpty { break }
                    
                    allData.append(chunk)
                    lineBuffer.append(chunk)
                    
                    // Process complete lines (and \r for progress updates)
                    while let range = lineBuffer.firstRange(of: Data([0x0A])) ?? lineBuffer.firstRange(of: Data([0x0D])) {
                        let lineData = lineBuffer[lineBuffer.startIndex..<range.lowerBound]
                        if let line = String(data: lineData, encoding: .utf8) {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                Task { @MainActor [weak self] in
                                    self?.parseLine(trimmed)
                                }
                            }
                        }
                        lineBuffer.removeSubrange(lineBuffer.startIndex...range.lowerBound)
                    }
                }
                
                // Process remaining buffer
                if !lineBuffer.isEmpty, let line = String(data: lineBuffer, encoding: .utf8) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        Task { @MainActor [weak self] in
                            self?.parseLine(trimmed)
                        }
                    }
                }
                
                continuation.resume(returning: allData)
            }
        }
        
        task.waitUntilExit()
        
        let exitCode = task.terminationStatus
        
        await MainActor.run { [weak self] in
            self?.timer?.invalidate()
            self?.isRunning = false
            self?.isFinished = true
            
            if exitCode == 0 {
                self?.progress = 100
                self?.statusText = "Completed"
            } else if exitCode == -1 || self?.statusText == "Cancelled" {
                // Already handled by cancel()
            } else {
                let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stdout = String(data: data, encoding: .utf8) ?? ""
                self?.errorMessage = stderr.isEmpty ? stdout : stderr
                self?.statusText = "Error (exit code \(exitCode))"
            }
        }
    }
    
    // MARK: - Line Parsing
    
    /// Parse a single line of 7zz output to extract progress info.
    private func parseLine(_ line: String) {
        // Progress percentage: "  3% + filename" or " 45%" or "100%"
        if let match = line.range(of: #"^\s*(\d+)%"#, options: .regularExpression) {
            let percentStr = line[match].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
            if let pct = Double(percentStr) {
                progress = pct
                updateProcessedSize()
                updateSpeed()
                updateCompressionRatio()
                updateEstimatedTime()
            }
            
            // Extract filename after the percentage
            let afterPercent = line[match.upperBound...].trimmingCharacters(in: .whitespaces)
            if afterPercent.hasPrefix("+ ") || afterPercent.hasPrefix("U ") || afterPercent.hasPrefix("- ") {
                currentFileName = String(afterPercent.dropFirst(2))
                statusText = "Adding..."
            } else if !afterPercent.isEmpty {
                currentFileName = afterPercent
            }
            return
        }
        
        // "Add new data to archive: N files, SIZE"
        if line.contains("Add new data to archive:") {
            if let filesMatch = line.range(of: #"(\d+)\s+file"#, options: .regularExpression) {
                let numStr = line[filesMatch].components(separatedBy: " ").first ?? ""
                totalFiles = Int(numStr) ?? 0
            }
            if let sizeMatch = line.range(of: #",\s*(.+)$"#, options: .regularExpression) {
                totalSize = line[sizeMatch].trimmingCharacters(in: .init(charactersIn: ", "))
                totalSizeBytes = Self.parseByteCount(from: totalSize)
                updateProcessedSize()
            }
            statusText = "Adding..."
            return
        }
        
        // "+ filename" (file being added)
        if line.hasPrefix("+ ") {
            currentFileName = String(line.dropFirst(2))
            filesProcessed += 1
            statusText = "Adding..."
            return
        }
        
        // "Archive size: 123456 bytes"
        if line.hasPrefix("Archive size:") {
            compressedSize = line.replacingOccurrences(of: "Archive size:", with: "").trimmingCharacters(in: .whitespaces)
            updateCompressionRatio()
            return
        }
        
        // "Files read from disk: N"
        if line.hasPrefix("Files read from disk:") {
            let numStr = line.replacingOccurrences(of: "Files read from disk:", with: "").trimmingCharacters(in: .whitespaces)
            filesProcessed = Int(numStr) ?? filesProcessed
            return
        }
        
        // "Everything is Ok"
        if line.contains("Everything is Ok") {
            progress = 100
            updateProcessedSize(forceComplete: true)
            updateSpeed()
            updateCompressionRatio()
            statusText = "Completed"
            return
        }
        
        // "Scanning the drive"
        if line.contains("Scanning") {
            statusText = "Scanning..."
            return
        }
        
        // "N files, SIZE (HUMAN)" from scanning
        if line.hasSuffix(")") && line.contains("file") {
            if let sizeMatch = line.range(of: #"\((.+)\)"#, options: .regularExpression) {
                totalSize = String(line[sizeMatch]).trimmingCharacters(in: .init(charactersIn: "()"))
                totalSizeBytes = Self.parseByteCount(from: totalSize)
                updateProcessedSize()
            }
            if let filesMatch = line.range(of: #"(\d+)\s+file"#, options: .regularExpression) {
                let numStr = line[filesMatch].components(separatedBy: " ").first ?? ""
                totalFiles = Int(numStr) ?? totalFiles
            }
        }
    }
    
    private func updateEstimatedTime() {
        guard progress > 0, let start = startTime else {
            estimatedRemainingTime = 0
            return
        }
        let elapsed = Date().timeIntervalSince(start)
        let totalEstimated = elapsed / (progress / 100.0)
        estimatedRemainingTime = max(0, totalEstimated - elapsed)
    }

    private func updateProcessedSize(forceComplete: Bool = false) {
        guard totalSizeBytes > 0 else {
            processedSize = ""
            return
        }

        let effectiveProgress = forceComplete ? 100.0 : progress
        processedBytes = Int64((effectiveProgress / 100.0) * Double(totalSizeBytes))
        processedSize = ByteCountFormatter.string(fromByteCount: processedBytes, countStyle: .file)
    }

    private func updateSpeed() {
        guard let start = startTime else {
            speed = ""
            return
        }

        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0.5, processedBytes > 0 else {
            speed = ""
            return
        }

        let bytesPerSecond = Double(processedBytes) / elapsed
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file)
        speed = "\(formatted)/s"
    }

    private func updateCompressionRatio() {
        let packedBytes = Self.parseByteCount(from: compressedSize)
        guard totalSizeBytes > 0, packedBytes > 0 else {
            compressionRatio = ""
            return
        }

        let ratio = (Double(packedBytes) / Double(totalSizeBytes)) * 100
        compressionRatio = String(format: "%.1f%%", ratio)
    }

    private static func parseByteCount(from text: String) -> Int64 {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        if let value = Int64(trimmed.components(separatedBy: .whitespaces).first ?? "") {
            return value
        }

        let scanner = Scanner(string: trimmed.replacingOccurrences(of: ",", with: "."))
        guard let number = scanner.scanDouble() else { return 0 }

        let unit = trimmed
            .uppercased()
            .components(separatedBy: CharacterSet.whitespaces)
            .dropFirst()
            .joined(separator: " ")

        let multiplier: Double
        switch unit {
        case let value where value.hasPrefix("KIB") || value.hasPrefix("KB"):
            multiplier = 1_024
        case let value where value.hasPrefix("MIB") || value.hasPrefix("MB"):
            multiplier = 1_024 * 1_024
        case let value where value.hasPrefix("GIB") || value.hasPrefix("GB"):
            multiplier = 1_024 * 1_024 * 1_024
        case let value where value.hasPrefix("TIB") || value.hasPrefix("TB"):
            multiplier = 1_024 * 1_024 * 1_024 * 1_024
        default:
            multiplier = 1
        }

        return Int64(number * multiplier)
    }
}
