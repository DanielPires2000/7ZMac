import SwiftUI

/// 7-Zip style compression/extraction progress window.
struct CompressionProgressView: View {
    @ObservedObject var tracker: CompressionProgressTracker
    let onCancel: () -> Void
    
    private let labelWidth: CGFloat = 200
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // ═══ Stats Grid ═══
            HStack(alignment: .top, spacing: 32) {
                // Left stats
                VStack(alignment: .leading, spacing: 6) {
                    statRow("Elapsed time:", formatTime(tracker.elapsedTime))
                    statRow("Remaining time:", tracker.progress > 0 ? formatTime(tracker.estimatedRemainingTime) : "—")
                    statRow("Files:", "\(tracker.filesProcessed)" + (tracker.totalFiles > 0 ? " / \(tracker.totalFiles)" : ""))
                }
                
                Spacer()
                
                // Right stats
                VStack(alignment: .leading, spacing: 6) {
                    if !tracker.totalSize.isEmpty {
                        statRow("Size:", tracker.totalSize)
                    }
                    if !tracker.compressedSize.isEmpty {
                        statRow("Compressed:", tracker.compressedSize)
                    }
                    if tracker.progress > 0 {
                        statRow("Ratio:", String(format: "%.0f%%", tracker.progress > 0 ? min(100, (1 - tracker.progress / 100) * 100 + tracker.progress) : 0))
                    }
                }
            }
            .font(.system(size: 12))
            
            Divider()
            
            // ═══ Status & Current File ═══
            VStack(alignment: .leading, spacing: 4) {
                Text(tracker.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                if !tracker.currentFileName.isEmpty {
                    Text(tracker.currentFileName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            // ═══ Progress Bar ═══
            ProgressView(value: tracker.progress, total: 100)
                .progressViewStyle(.linear)
            
            Text(String(format: "%.0f%%", tracker.progress))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // ═══ Error Message ═══
            if let error = tracker.errorMessage {
                ScrollView {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 80)
            }
            
            Spacer()
            
            Divider()
            
            // ═══ Buttons ═══
            HStack {
                Spacer()
                
                if tracker.isFinished {
                    Button("Close") { onCancel() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Cancel") {
                        tracker.cancel()
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 280)
    }
    
    // MARK: - Helpers
    
    private func statRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .fontWeight(.medium)
        }
        .frame(minWidth: 180)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Preview

#Preview("Progress - Running") {
    let tracker = CompressionProgressTracker()
    
    CompressionProgressView(
        tracker: tracker,
        onCancel: {}
    )
    .onAppear {
        tracker.progress = 35
        tracker.currentFileName = "Documents/Project/very_long_filename_example.swift"
        tracker.filesProcessed = 12
        tracker.totalFiles = 45
        tracker.totalSize = "5822 MB"
        tracker.compressedSize = "1245 MB"
        tracker.statusText = "Adding..."
        tracker.isRunning = true
        tracker.archiveName = "project_backup.7z"
    }
}

#Preview("Progress - Finished") {
    let tracker = CompressionProgressTracker()
    
    CompressionProgressView(
        tracker: tracker,
        onCancel: {}
    )
    .onAppear {
        tracker.progress = 100
        tracker.filesProcessed = 45
        tracker.totalFiles = 45
        tracker.totalSize = "5822 MB"
        tracker.compressedSize = "2100 MB"
        tracker.statusText = "Completed"
        tracker.isRunning = false
        tracker.isFinished = true
        tracker.archiveName = "project_backup.7z"
    }
}
