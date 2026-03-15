import SwiftUI
import AppKit

// MARK: - ComboBox (NSComboBox wrapper)

/// A SwiftUI wrapper around `NSComboBox` — editable text field with a dropdown of predefined values.
struct ComboBoxView: NSViewRepresentable {
    @Binding var text: String
    let items: [String]
    var font: NSFont = .systemFont(ofSize: 12)
    
    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = false
        comboBox.isEditable = true
        comboBox.completes = true
        comboBox.font = font
        comboBox.addItems(withObjectValues: items)
        comboBox.stringValue = text
        comboBox.delegate = context.coordinator
        comboBox.target = context.coordinator
        comboBox.action = #selector(Coordinator.valueChanged(_:))
        return comboBox
    }
    
    func updateNSView(_ nsView: NSComboBox, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, NSComboBoxDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        @objc func valueChanged(_ sender: NSComboBox) {
            text = sender.stringValue
        }
        
        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox,
                  comboBox.indexOfSelectedItem >= 0 else { return }
            // Extract just the size value (before " - " description)
            let selected = comboBox.itemObjectValue(at: comboBox.indexOfSelectedItem) as? String ?? ""
            let value = selected.components(separatedBy: " - ").first?.trimmingCharacters(in: .whitespaces) ?? selected
            DispatchQueue.main.async {
                self.text = value
            }
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let comboBox = obj.object as? NSComboBox else { return }
            text = comboBox.stringValue
        }
    }
}

// MARK: - Left Column

/// Left column of the Add to Archive dialog — compression settings.
struct AddToArchiveLeftColumn: View {
    @Binding var options: CompressionOptions
    var onFormatChanged: ((ArchiveFormat) -> Void)? = nil
    
    private let maxCPU = ProcessInfo.processInfo.activeProcessorCount
    private let labelWidth: CGFloat = 160
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            row("Archive format:") {
                Picker("", selection: $options.archiveFormat) {
                    ForEach(ArchiveFormat.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .onChange(of: options.archiveFormat) { _, f in
                    onFormatChanged?(f)
                    if !f.availableMethods.contains(options.compressionMethod),
                       let m = f.availableMethods.first { options.compressionMethod = m }
                }
            }
            
            row("Compression level:") {
                Picker("", selection: $options.compressionLevel) {
                    ForEach(CompressionLevel.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
            }
            
            if !options.archiveFormat.availableMethods.isEmpty {
                row("Compression method:") {
                    Picker("", selection: $options.compressionMethod) {
                        ForEach(options.archiveFormat.availableMethods) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                }
            }
            
            row("Dictionary size:") {
                Picker("", selection: $options.dictionarySize) {
                    ForEach(DictionarySize.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
            }
            
            row("Word size:") {
                Picker("", selection: $options.wordSize) {
                    ForEach(WordSize.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
            }
            
            if options.archiveFormat.supportsSolid {
                row("Solid block size:") {
                    Picker("", selection: $options.solidBlockSize) {
                        ForEach(SolidBlockSize.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                }
            }
            
            row("CPU threads:") {
                HStack(spacing: 6) {
                    Picker("", selection: $options.cpuThreads) {
                        ForEach(1...maxCPU, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 70)
                    
                    Text("/ \(maxCPU)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Memory info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("Memory usage for compression:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("\(options.estimatedCompressionMemory) MB")
                        .font(.system(size: 11, weight: .medium))
                }
                HStack(spacing: 4) {
                    Text("Memory usage for decompression:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("\(options.estimatedDecompressionMemory) MB")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .padding(.top, 2)
            
            row("Split to volumes, bytes:") {
                ComboBoxView(
                    text: $options.splitToVolumes,
                    items: [
                        "10M",
                        "100M",
                        "1000M",
                        "650M - CD",
                        "700M - CD",
                        "4092M - FAT",
                        "4480M - DVD",
                        "8128M - DVD DL",
                        "23040M - BD"
                    ]
                )
                .frame(height: 24)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Parameters:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField("", text: $options.parameters)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame( alignment: .trailing)
            Spacer()
            content()
        }
    }
}

// MARK: - Right Column

/// Right column of the Add to Archive dialog — update/path modes, options, encryption.
struct AddToArchiveRightColumn: View {
    @Binding var options: CompressionOptions
    @Binding var showPassword: Bool
    
    private let labelWidth: CGFloat = 120
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            row("Update mode:") {
                Picker("", selection: $options.updateMode) {
                    ForEach(UpdateMode.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            
            row("Path mode:") {
                Picker("", selection: $options.pathMode) {
                    ForEach(PathMode.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            
            // ── Options GroupBox ──
            GroupBox("Options") {
                VStack(alignment: .leading, spacing: 6) {
                    if options.archiveFormat.supportsSFX {
                        Toggle("Create SFX archive", isOn: $options.createSFX)
                    }
                    Toggle("Compress shared files", isOn: $options.compressSharedFiles)
                    Toggle("Delete files after compression", isOn: $options.deleteAfterCompression)
                }
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            
            // ── Encryption GroupBox ──
            if options.archiveFormat.supportsEncryption {
                GroupBox("Encryption") {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enter password:")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Group {
                                if showPassword {
                                    TextField("", text: $options.password)
                                } else {
                                    SecureField("", text: $options.password)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Re-enter password:")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Group {
                                if showPassword {
                                    TextField("", text: $options.confirmPassword)
                                } else {
                                    SecureField("", text: $options.confirmPassword)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        }
                        
                        Toggle("Show password", isOn: $showPassword)
                            .font(.system(size: 12))
                        
                        HStack(spacing: 6) {
                            Text("Encryption method:")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Picker("", selection: $options.encryptionMethod) {
                                ForEach(EncryptionMethod.allCases) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 110)
                        }
                        
                        if options.archiveFormat.supportsEncryptFileNames {
                            Toggle("Encrypt file names", isOn: $options.encryptFileNames)
                                .font(.system(size: 12))
                                .disabled(options.password.isEmpty)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
            content()
        }
    }
}

// MARK: - Main Dialog

/// Faithful reproduction of the 7-Zip "Add to Archive" dialog.
struct AddToArchiveView: View {
    
    let filePaths: [String]
    let onCompress: (String, CompressionOptions) -> Void
    let onCancel: () -> Void
    
    @State private var archiveDirectory: String = ""
    @State private var archiveName: String = ""
    @State private var options = CompressionOptions()
    @State private var showPassword: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // ═══ Archive Path ═══
            archiveSection
                .padding(16)
            
            // ═══ Two Columns ═══
            HStack(alignment: .top, spacing: 24) {
                AddToArchiveLeftColumn(
                    options: $options,
                    onFormatChanged: { updateArchiveExtension(for: $0) }
                )
                AddToArchiveRightColumn(
                    options: $options,
                    showPassword: $showPassword
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            Divider()
            
            // ═══ Buttons ═══
            HStack {
                Spacer()
                Button("OK") {
                    let path = (archiveDirectory as NSString).appendingPathComponent(archiveName)
                    onCompress(path, options)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(archiveName.isEmpty)
                .disabled(!options.password.isEmpty && options.password != options.confirmPassword)
                
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(width: 720)
        .fixedSize()
        .onAppear { setupDefaults() }
    }
    
    // MARK: - Archive Path
    
    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Archive:")
                    .font(.system(size: 12))
                
                Text(archiveDirectory.isEmpty ? "" : archiveDirectory + "/")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            
            HStack(spacing: 6) {
                TextField("", text: $archiveName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                
                Button("…") { browseForPath() }
                    .frame(width: 28, height: 22)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func setupDefaults() {
        guard let first = filePaths.first else { return }
        let url = URL(fileURLWithPath: first)
        archiveDirectory = url.deletingLastPathComponent().path
        archiveName = url.deletingPathExtension().lastPathComponent + ".\(options.archiveFormat.fileExtension)"
    }
    
    private func updateArchiveExtension(for format: ArchiveFormat) {
        let base = (archiveName as NSString).deletingPathExtension
        archiveName = "\(base).\(format.fileExtension)"
    }
    
    private func browseForPath() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = archiveName
        if !archiveDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: archiveDirectory)
        }
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            archiveDirectory = url.deletingLastPathComponent().path
            archiveName = url.lastPathComponent
        }
    }
}

// MARK: - Previews

#Preview("Add to Archive") {
    AddToArchiveView(
        filePaths: [
            "/Users/test/Documents/Project/file1.txt",
            "/Users/test/Documents/Project/file2.swift",
            "/Users/test/Documents/Project/image.png"
        ],
        onCompress: { path, options in
            print("Compress to: \(path)")
            print("Args: \(options.buildArguments(archivePath: path, filePaths: []))")
        },
        onCancel: { print("Cancelled") }
    )
    .frame(width: 720, height: 600)
}

#Preview("Left Column") {
    AddToArchiveLeftColumn(options: .constant(CompressionOptions()))
        .padding()
        .frame(width: 400)
}

#Preview("Right Column") {
    AddToArchiveRightColumn(
        options: .constant(CompressionOptions()),
        showPassword: .constant(false)
    )
    .padding()
    .frame(width: 360)
}
