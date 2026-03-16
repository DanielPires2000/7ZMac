import Foundation

/// Typed errors for 7-Zip operations.
enum SevenZipError: LocalizedError {
    case executableNotFound
    case processFailure(exitCode: Int32, output: String)
    case outputDecodingFailed
    
    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "7zz executable not found. Please ensure it is bundled with the app."
        case .processFailure(let exitCode, let output):
            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedOutput.isEmpty else {
                return "7zz process failed with exit code \(exitCode)."
            }
            return "7zz process failed with exit code \(exitCode): \(trimmedOutput)"
        case .outputDecodingFailed:
            return "Failed to decode the output from 7zz."
        }
    }
}
