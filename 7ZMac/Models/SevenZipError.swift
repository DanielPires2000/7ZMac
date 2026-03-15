import Foundation

/// Typed errors for 7-Zip operations.
enum SevenZipError: LocalizedError {
    case executableNotFound
    case processFailure(exitCode: Int32)
    case outputDecodingFailed
    
    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "7zz executable not found. Please ensure it is bundled with the app."
        case .processFailure(let exitCode):
            return "7zz process failed with exit code \(exitCode)."
        case .outputDecodingFailed:
            return "Failed to decode the output from 7zz."
        }
    }
}
