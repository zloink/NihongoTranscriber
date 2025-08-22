import SwiftUI

struct ContentView: View {
    @EnvironmentObject var transcriptionManager: TranscriptionManager
    @EnvironmentObject var audioCaptureManager: AudioCaptureManager
    @State private var showTranslation = false
    @State private var selectedAudioSource: AudioSource = .systemAudio
    @State private var showingAudioSourcePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 🔥 DEBUG: This is our updated code! 🔥
            VStack(spacing: 8) {
                Text("🔥 UPDATED CODE IS RUNNING! 🔥")
                    .font(.title)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.yellow)
                    .cornerRadius(10)
                
                // 🎯 LIVE DEBUG STATUS 🎯
                VStack(spacing: 4) {
                    Text("🎯 LIVE DEBUG STATUS 🎯")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("Recording: \(transcriptionManager.isRecording ? "YES" : "NO")")
                        .foregroundColor(transcriptionManager.isRecording ? .green : .red)
                    
                    Text("Permissions: \(audioCaptureManager.hasPermissions ? "YES" : "NO")")
                        .foregroundColor(audioCaptureManager.hasPermissions ? .green : .red)
                    
                    Text("Audio Level: \(String(format: "%.3f", audioCaptureManager.audioLevel))")
                        .foregroundColor(.orange)
                    
                    Text("Session Count: \(transcriptionManager.currentSession?.transcriptions.count ?? 0)")
                        .foregroundColor(.purple)
                    
                    // 🔥 WHISPER PATHS DEBUG 🔥
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🔥 WHISPER PATHS:")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        let paths = transcriptionManager.getWhisperDebugPaths()
                        Text("CLI: \(paths["whisperCLIPath"] ?? "N/A")")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("Model: \(paths["fullModelPath"] ?? "N/A")")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("CLI Exists: \(paths["cliExists"] ?? "N/A")")
                            .font(.caption2)
                            .foregroundColor(paths["cliExists"] == "true" ? .green : .red)
                        Text("Model Exists: \(paths["modelExists"] ?? "N/A")")
                            .font(.caption2)
                            .foregroundColor(paths["modelExists"] == "true" ? .green : .red)
                    }
                    .padding(4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .border(Color.blue, width: 2)
            }
            
            // Header with controls
            headerView
            
            // Main transcription area
            HStack(spacing: 0) {
                // Japanese transcription (main)
                transcriptionView
                
                // English translation (optional)
                if showTranslation {
                    Divider()
                    translationView
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingAudioSourcePicker) {
            AudioSourcePickerView(
                selectedSource: $selectedAudioSource,
                audioCaptureManager: audioCaptureManager
            )
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Nihongo Transcriber")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Audio source selector
                Button(action: { showingAudioSourcePicker = true }) {
                    HStack {
                        Image(systemName: "speaker.wave.2")
                        Text(selectedAudioSource.displayName)
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Translation toggle
                Button(action: { showTranslation.toggle() }) {
                    HStack {
                        Image(systemName: showTranslation ? "translate" : "translate")
                        Text(showTranslation ? "Hide Translation" : "Show Translation")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(showTranslation ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            HStack {
                // Recording controls
                recordingControls
                
                Spacer()
                
                // Status and info
                statusView
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color.gray.opacity(0.2), width: 1)
    }
    
    private var recordingControls: some View {
        HStack(spacing: 16) {
            // Main recording button
            Button(action: {
                if transcriptionManager.isRecording {
                    transcriptionManager.stopRecording()
                } else {
                    transcriptionManager.startRecording()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: transcriptionManager.isRecording ? "stop.circle.fill" : "record.circle.fill")
                        .font(.title2)
                    Text(transcriptionManager.isRecording ? "Stop Recording" : "Start Recording")
                        .fontWeight(.semibold)
                }
                .foregroundColor(transcriptionManager.isRecording ? .white : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(transcriptionManager.isRecording ? Color.red : Color.accentColor)
                .cornerRadius(10)
                .shadow(color: transcriptionManager.isRecording ? .red.opacity(0.3) : .accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(!audioCaptureManager.hasPermissions)
            .scaleEffect(transcriptionManager.isRecording ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: transcriptionManager.isRecording)
            
            // Pause/Resume button
            if transcriptionManager.isRecording {
                Button(action: { 
                    if transcriptionManager.isPaused {
                        transcriptionManager.resumeRecording()
                    } else {
                        transcriptionManager.pauseRecording()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: transcriptionManager.isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.title3)
                        Text(transcriptionManager.isPaused ? "Resume" : "Pause")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(transcriptionManager.isPaused ? .green : .orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(transcriptionManager.isPaused ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(transcriptionManager.isPaused ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Save Session button
            Button(action: { transcriptionManager.saveCurrentSession() }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title3)
                    Text("Save Session")
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(transcriptionManager.currentSession?.transcriptions.isEmpty ?? true)
            .opacity((transcriptionManager.currentSession?.transcriptions.isEmpty ?? true) ? 0.5 : 1.0)
        }
    }
    
    private var statusView: some View {
        HStack(spacing: 12) {
            // Audio level indicator - always visible when permissions granted
            if audioCaptureManager.hasPermissions {
                AudioLevelIndicator(level: audioCaptureManager.audioLevel)
                    .frame(width: 60, height: 20)
            }
            
            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Recording indicator
            if transcriptionManager.isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(transcriptionManager.isPaused ? 1.0 : 1.2)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: transcriptionManager.isRecording)
                    
                    Text("REC")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
            
            // Audio detection indicator
            if audioCaptureManager.isCapturing && audioCaptureManager.audioLevel > 0.01 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: audioCaptureManager.audioLevel)
                    
                    Text("AUDIO")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    private var statusText: String {
        if !audioCaptureManager.hasPermissions {
            return "Audio permissions required"
        } else if transcriptionManager.isRecording {
            if transcriptionManager.isPaused {
                return "Recording paused"
            } else {
                if audioCaptureManager.audioLevel > 0.01 {
                    return "Recording - Audio detected"
                } else {
                    return "Recording - Waiting for audio..."
                }
            }
        } else {
            if audioCaptureManager.audioLevel > 0.01 {
                return "Ready - Audio detected"
            } else {
                return "Ready to record"
            }
        }
    }
    
    private var transcriptionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Japanese Transcription")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(transcriptionManager.currentSession?.transcriptions.count ?? 0) segments")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(transcriptionManager.currentSession?.transcriptions ?? [], id: \.id) { transcription in
                            TranscriptionSegmentView(transcription: transcription)
                                .id(transcription.id)
                        }
                        
                        if transcriptionManager.isRecording && !transcriptionManager.isPaused {
                            // Live indicator
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.green)
                                Text("Listening...")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding()
                }
                .onChange(of: transcriptionManager.currentSession?.transcriptions.count) { _ in
                    // Auto-scroll to bottom when new transcriptions arrive
                    if let lastId = transcriptionManager.currentSession?.transcriptions.last?.id {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private var translationView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("English Translation")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(transcriptionManager.currentSession?.translations.count ?? 0) segments")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(transcriptionManager.currentSession?.translations ?? [], id: \.id) { translation in
                        TranslationSegmentView(translation: translation)
                    }
                    
                    if transcriptionManager.isRecording && !transcriptionManager.isPaused && showTranslation {
                        // Live indicator for translation
                        HStack {
                            Image(systemName: "translate")
                                .foregroundColor(.blue)
                            Text("Translating...")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 300)
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct TranscriptionSegmentView: View {
    let transcription: TranscriptionSegment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(transcription.text)
                    .font(.body)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Text(transcription.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !transcription.confidence.isEmpty {
                Text("Confidence: \(transcription.confidence)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct TranslationSegmentView: View {
    let translation: TranslationSegment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(translation.text)
                    .font(.body)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Text(translation.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

struct AudioLevelIndicator: View {
    let level: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { index in
                Rectangle()
                    .fill(barColor(for: index, level: level))
                    .frame(width: 3, height: CGFloat(index + 1) * 2)
                    .animation(.easeInOut(duration: 0.1), value: level)
                    .scaleEffect(index < Int(level * 10) ? 1.0 : 0.8)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.1))
        .cornerRadius(4)
    }
    
    private func barColor(for index: Int, level: Float) -> Color {
        let threshold = Float(index) / 10.0
        if level >= threshold {
            if threshold > 0.7 {
                return .red
            } else if threshold > 0.4 {
                return .orange
            } else {
                return .green
            }
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TranscriptionManager())
        .environmentObject(AudioCaptureManager())
} 