import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var transcriptionManager: TranscriptionManager
    @EnvironmentObject var audioCaptureManager: AudioCaptureManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var settings: TranscriptionSettings
    @State private var selectedModel: String
    @State private var showingExportSheet = false
    @State private var exportFormat: ExportFormat = .text
    @State private var searchQuery = ""
    @State private var selectedTags: Set<String> = []
    @State private var dateRange: DateInterval?
    @StateObject private var whisperWrapper = WhisperWrapper()
    
    init() {
        self._settings = State(initialValue: TranscriptionSettings.default)
        self._selectedModel = State(initialValue: TranscriptionSettings.default.modelSize)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Settings tabs
                Picker("Settings", selection: .constant(0)) {
                    Text("General").tag(0)
                    Text("Audio").tag(1)
                    Text("Sessions").tag(2)
                    Text("Advanced").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView {
                    generalSettingsTab
                    audioSettingsTab
                    sessionsTab
                    advancedSettingsTab
                }
                .tabViewStyle(.automatic)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            settings = transcriptionManager.settings
            selectedModel = settings.modelSize
        }
        .onChange(of: settings) { newSettings in
            transcriptionManager.updateSettings(newSettings)
        }
    }
    
    // MARK: - General Settings Tab
    
    private var generalSettingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Transcription Settings") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Chunk Duration:")
                            Spacer()
                            Text("\(Int(settings.chunkDuration)) seconds")
                        }
                        
                        Slider(value: $settings.chunkDuration, in: 1...10, step: 0.5)
                            .onChange(of: settings.chunkDuration) { newValue in
                                settings.chunkDuration = newValue
                            }
                        
                        Text("Shorter chunks provide more real-time experience but may reduce accuracy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                GroupBox("Translation") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable automatic translation", isOn: $settings.enableTranslation)
                        
                        if settings.enableTranslation {
                            HStack {
                                Text("Target Language:")
                                Spacer()
                                Text(settings.targetLanguage.uppercased())
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("Translates Japanese speech to English automatically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                GroupBox("Auto-save") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Auto-save sessions", isOn: $settings.autoSave)
                        
                        if settings.autoSave {
                            HStack {
                                Text("Save interval:")
                                Spacer()
                                Text("\(Int(settings.saveInterval / 60)) minutes")
                            }
                            
                            Slider(value: $settings.saveInterval, in: 60...1800, step: 60)
                                .onChange(of: settings.saveInterval) { newValue in
                                    settings.saveInterval = newValue
                                }
                        }
                        
                        Text("Automatically saves transcription progress during long sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Audio Settings Tab
    
    private var audioSettingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Audio Capture") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Sample Rate:")
                            Spacer()
                            Text("16,000 Hz")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Channels:")
                            Spacer()
                            Text("Mono")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Format:")
                            Spacer()
                            Text("16-bit PCM")
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Optimized for Whisper.cpp transcription")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                GroupBox("Audio Sources") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(audioCaptureManager.availableAudioSources) { source in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.name)
                                        .font(.headline)
                                    Text(source.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if audioCaptureManager.selectedAudioSource?.id == source.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                GroupBox("Permissions") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: audioCaptureManager.hasPermissions ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(audioCaptureManager.hasPermissions ? .green : .red)
                            
                            Text("Microphone Access")
                            
                            Spacer()
                            
                            if !audioCaptureManager.hasPermissions {
                                Button("Request Access") {
                                    audioCaptureManager.requestPermissions()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        
                        Text("Required for audio capture and transcription")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Sessions Tab
    
    private var sessionsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Search & Filter") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Search transcriptions...", text: $searchQuery)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack {
                            Text("Tags:")
                            Spacer()
                            Button("Clear") {
                                selectedTags.removeAll()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if !availableTags.isEmpty {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(availableTags, id: \.self) { tag in
                                    TagView(
                                        tag: tag,
                                        isSelected: selectedTags.contains(tag),
                                        onToggle: {
                                            if selectedTags.contains(tag) {
                                                selectedTags.remove(tag)
                                            } else {
                                                selectedTags.insert(tag)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                
                GroupBox("Saved Sessions") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Total Sessions: \(transcriptionManager.savedSessions.count)")
                            Spacer()
                            Text("Total Transcriptions: \(transcriptionManager.totalTranscriptions)")
                        }
                        
                        HStack {
                            Text("Total Duration:")
                            Spacer()
                            Text(formatDuration(transcriptionManager.totalDuration))
                        }
                        
                        HStack {
                            Text("Average Session:")
                            Spacer()
                            Text(formatDuration(transcriptionManager.averageSessionLength))
                        }
                        
                        Button("Export All Sessions") {
                            showingExportSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                GroupBox("Recent Sessions") {
                    LazyVStack(spacing: 8) {
                        ForEach(transcriptionManager.savedSessions.prefix(5)) { session in
                            SessionRowView(session: session)
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportView(
                format: $exportFormat,
                onExport: { format in
                    let exportText = transcriptionManager.exportAllSessions(format)
                    exportToFile(exportText, format: format)
                }
            )
        }
    }
    
    // MARK: - Advanced Settings Tab
    
    private var advancedSettingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Whisper Model") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Current Model:")
                            Spacer()
                            Text(selectedModel)
                                .foregroundColor(.secondary)
                        }
                        
                        Picker("Model Size", selection: $selectedModel) {
                            ForEach(whisperWrapper.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedModel) { newModel in
                            settings.modelSize = newModel
                            whisperWrapper.selectModel(newModel)
                        }
                        
                        Text("Larger models provide better accuracy but require more processing time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                GroupBox("Quality Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Confidence Threshold:")
                            Spacer()
                            Text(String(format: "%.1f", settings.confidenceThreshold))
                        }
                        
                        Slider(value: $settings.confidenceThreshold, in: 0...1, step: 0.1)
                            .onChange(of: settings.confidenceThreshold) { newValue in
                                settings.confidenceThreshold = newValue
                            }
                        
                        Text("Higher values filter out low-confidence transcriptions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                GroupBox("Reset") {
                    VStack(alignment: .leading, spacing: 12) {
                        Button("Reset to Defaults") {
                            settings = TranscriptionSettings.default
                            selectedModel = settings.modelSize
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.orange)
                        
                        Text("Restores all settings to their default values")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    
    private var availableTags: [String] {
        let allTags = transcriptionManager.savedSessions.flatMap { $0.metadata.tags }
        return Array(Set(allTags)).sorted()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func exportToFile(_ content: String, format: ExportFormat) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "transcriptions_\(Date().timeIntervalSince1970).\(format.fileExtension)"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to export: \(error)")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct TagView: View {
    let tag: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Text(tag)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct SessionRowView: View {
    let session: TranscriptionSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.metadata.topic ?? "General Conversation")
                    .font(.headline)
                
                Spacer()
                
                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(session.transcriptions.count) transcriptions")
                Text("•")
                Text(formatDuration(session.duration))
                Text("•")
                if let contact = session.metadata.contactName {
                    Text(contact)
                }
                
                Spacer()
                
                if !session.metadata.tags.isEmpty {
                    Text(session.metadata.tags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ExportView: View {
    @Binding var format: ExportFormat
    let onExport: (ExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Format")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(ExportFormat.allCases, id: \.self) { exportFormat in
                        ExportFormatRow(
                            format: exportFormat,
                            isSelected: format == exportFormat,
                            onSelect: { format = exportFormat }
                        )
                    }
                }
                
                Spacer()
                
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Export") {
                        onExport(format)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 400, height: 300)
            .navigationTitle("Export")
        }
    }
}

struct ExportFormatRow: View {
    let format: ExportFormat
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                
                Text(format.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                
                Text(".\(format.fileExtension)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var iconName: String {
        switch format {
        case .text: return "doc.text"
        case .json: return "curlybraces"
        case .csv: return "tablecells"
        case .markdown: return "doc.richtext"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TranscriptionManager())
        .environmentObject(AudioCaptureManager())
} 