import SwiftUI

@main
struct NihongoTranscriberApp: App {
    // Create shared instances
    @StateObject private var transcriptionManager = TranscriptionManager()
    @StateObject private var audioCaptureManager = AudioCaptureManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(transcriptionManager)
                .environmentObject(audioCaptureManager)
                .onAppear {
                    setupApp()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Recording") {
                    if transcriptionManager.isRecording {
                        transcriptionManager.stopRecording()
                    } else {
                        transcriptionManager.startRecording()
                    }
                }
                .keyboardShortcut("n")
            }
            
            CommandGroup(after: .newItem) {
                Button("Save Session") {
                    transcriptionManager.saveCurrentSession()
                }
                .keyboardShortcut("s")
                .disabled(transcriptionManager.currentSession?.transcriptions.isEmpty ?? true)
                
                Divider()
                
                Button("Toggle Translation") {
                    transcriptionManager.showTranslation.toggle()
                }
                .keyboardShortcut("t")
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(transcriptionManager)
        }
    }
    
    private func setupApp() {
        print("🚀 Nihongo Transcriber App Starting Up")
        
        // Validate Whisper installation
        let whisperWrapper = transcriptionManager.whisperWrapper
        let isValid = whisperWrapper.validateInstallation()
        
        print("📋 Whisper Installation Valid: \(isValid)")
        
        if !isValid {
            print("⚠️ Whisper installation issues detected")
            // You could show an alert here or in your UI
        }
        
        // Request initial permissions
        audioCaptureManager.requestPermissions()
        
        print("✅ App setup complete")
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var transcriptionManager: TranscriptionManager
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .environmentObject(transcriptionManager)
            
            AudioSettingsView()
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.2")
                }
            
            WhisperSettingsView()
                .tabItem {
                    Label("Whisper", systemImage: "text.bubble")
                }
                .environmentObject(transcriptionManager)
            
            SessionsView()
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet.rectangle")
                }
                .environmentObject(transcriptionManager)
        }
        .frame(width: 600, height: 400)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var transcriptionManager: TranscriptionManager
    
    var body: some View {
        Form {
            Section("Language Settings") {
                Picker("Source Language", selection: $transcriptionManager.settings.sourceLanguage) {
                    Text("Japanese").tag("ja")
                    Text("English").tag("en")
                    Text("Auto-detect").tag("auto")
                }
                
                Picker("Target Language", selection: $transcriptionManager.settings.targetLanguage) {
                    Text("English").tag("en")
                    Text("Japanese").tag("ja")
                }
                
                Toggle("Enable Translation", isOn: $transcriptionManager.settings.enableTranslation)
            }
            
            Section("Auto-save") {
                Toggle("Auto-save Sessions", isOn: $transcriptionManager.settings.autoSave)
                
                if transcriptionManager.settings.autoSave {
                    Stepper("Save every \(Int(transcriptionManager.settings.saveInterval / 60)) minutes",
                           value: $transcriptionManager.settings.saveInterval,
                           in: 60...1800,
                           step: 60)
                }
            }
        }
        .padding()
    }
}

struct AudioSettingsView: View {
    var body: some View {
        Form {
            Section("Audio Processing") {
                Text("Audio settings will be implemented here")
                Text("• Chunk duration")
                Text("• Sample rate")
                Text("• Audio quality settings")
            }
        }
        .padding()
    }
}

struct WhisperSettingsView: View {
    @EnvironmentObject var transcriptionManager: TranscriptionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Whisper Model Settings")
                .font(.headline)
            
            // Model selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Model Size")
                    .font(.subheadline)
                
                Picker("Model", selection: $transcriptionManager.settings.modelSize) {
                    ForEach(transcriptionManager.whisperWrapper.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Debug information
            VStack(alignment: .leading, spacing: 4) {
                Text("Installation Status")
                    .font(.subheadline)
                
                let debugPaths = transcriptionManager.getWhisperDebugPaths()
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Whisper CLI:")
                        Text(debugPaths["cliExists"] == "true" ? "✅ Found" : "❌ Missing")
                            .foregroundColor(debugPaths["cliExists"] == "true" ? .green : .red)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Current Model:")
                        Text(debugPaths["modelExists"] == "true" ? "✅ Found" : "❌ Missing")
                            .foregroundColor(debugPaths["modelExists"] == "true" ? .green : .red)
                    }
                    .font(.caption)
                    
                    Text("CLI Path: \(debugPaths["whisperCLIPath"] ?? "Unknown")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Model Path: \(debugPaths["fullModelPath"] ?? "Unknown")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            
            // Confidence threshold
            VStack(alignment: .leading, spacing: 8) {
                Text("Confidence Threshold: \(String(format: "%.1f", transcriptionManager.settings.confidenceThreshold))")
                    .font(.subheadline)
                
                Slider(value: $transcriptionManager.settings.confidenceThreshold,
                       in: 0.0...1.0,
                       step: 0.1) {
                    Text("Confidence")
                } minimumValueLabel: {
                    Text("0.0")
                } maximumValueLabel: {
                    Text("1.0")
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct SessionsView: View {
    @EnvironmentObject var transcriptionManager: TranscriptionManager
    
    var body: some View {
        VStack {
            Text("Saved Sessions: \(transcriptionManager.savedSessions.count)")
                .font(.headline)
                .padding()
            
            List(transcriptionManager.savedSessions) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.metadata.topic ?? "Untitled Session")
                        .font(.headline)
                    
                    Text("Duration: \(session.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(session.transcriptions.count) transcriptions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
}
