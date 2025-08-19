import Foundation
import Combine
import SwiftUI

class TranscriptionManager: ObservableObject, Sendable {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentSession: TranscriptionSession?
    @Published var savedSessions: [TranscriptionSession] = []
    @Published var isProcessing = false
    @Published var lastError: String?
    
    // Settings
    @Published var settings = TranscriptionSettings.default
    @Published var showTranslation = false
    
    // Audio processing
    private var audioCaptureManager: AudioCaptureManager?
    private var whisperWrapper: WhisperWrapper
    private var processingQueue = DispatchQueue(label: "transcription.processing", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    // Session management
    private var sessionStartTime: Date?
    private var autoSaveTimer: Timer?
    private var audioChunks: [Data] = []
    
    init() {
        self.whisperWrapper = WhisperWrapper()
        setupBindings()
        loadSavedSessions()
    }
    
    deinit {
        stopRecording()
        autoSaveTimer?.invalidate()
    }
    
    // MARK: - Setup and Bindings
    
    private func setupBindings() {
        // Monitor settings changes
        $settings
            .sink { [weak self] newSettings in
                self?.updateWhisperSettings(newSettings)
            }
            .store(in: &cancellables)
        
        // Monitor translation preference
        $showTranslation
            .sink { [weak self] show in
                self?.settings.enableTranslation = show
            }
            .store(in: &cancellables)
    }
    
    private func updateWhisperSettings(_ settings: TranscriptionSettings) {
        whisperWrapper.selectModel(settings.modelSize)
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Create new session
        let session = TranscriptionSession()
        currentSession = session
        sessionStartTime = Date()
        
        // Setup audio capture
        setupAudioCapture()
        
        // Start recording
        audioCaptureManager?.startCapture()
        
        isRecording = true
        isPaused = false
        lastError = nil
        
        // Start auto-save timer if enabled
        if settings.autoSave {
            startAutoSaveTimer()
        }
        
        print("Started transcription session: \(session.id)")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop audio capture
        audioCaptureManager?.stopCapture()
        
        // Finalize session
        finalizeCurrentSession()
        
        isRecording = false
        isPaused = false
        
        // Stop auto-save timer
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        
        print("Stopped transcription session")
    }
    
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        
        audioCaptureManager?.pauseCapture()
        isPaused = true
        
        print("Paused transcription session")
    }
    
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        audioCaptureManager?.resumeCapture()
        isPaused = false
        
        print("Resumed transcription session")
    }
    
    // MARK: - Audio Capture Setup
    
    private func setupAudioCapture() {
        audioCaptureManager = AudioCaptureManager()
        
        // Setup callbacks
        audioCaptureManager?.onAudioChunk = { [weak self] audioData in
            self?.processAudioChunk(audioData)
        }
        
        audioCaptureManager?.onAudioLevelChange = { [weak self] level in
            // Audio level updates are handled by the UI
        }
        
        audioCaptureManager?.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.lastError = error.localizedDescription
                self?.stopRecording()
            }
        }
    }
    
    // MARK: - Audio Processing
    
    private func processAudioChunk(_ audioData: Data) {
        guard isRecording && !isPaused else { return }
        
        print("Processing audio chunk of size: \(audioData.count) bytes")
        
        // Store audio chunk
        audioChunks.append(audioData)
        
        // Process with Whisper
        Task {
            await processAudioWithWhisper(audioData)
        }
    }
    
    private func processAudioWithWhisper(_ audioData: Data) async {
        guard var session = currentSession else { 
            print("No current session available for transcription")
            return 
        }
        
        print("Starting Whisper transcription for \(audioData.count) bytes of audio")
        
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        do {
            // Transcribe audio
            let transcriptionResult = try await whisperWrapper.transcribeAudio(audioData, language: "ja")
            print("Transcription result: \(transcriptionResult)")
            
            // Add transcription to session
            if !transcriptionResult.isEmpty {
                print("Adding transcription to session: \(transcriptionResult)")
                await addTranscriptionToSession(transcriptionResult, session: &session)
            } else {
                print("Transcription result was empty")
            }
            
            // Translate if enabled
            if settings.enableTranslation && !transcriptionResult.isEmpty {
                print("Starting translation...")
                let translationResult = try await whisperWrapper.translateAudio(audioData, sourceLanguage: "ja")
                
                if !translationResult.isEmpty {
                    print("Adding translation to session: \(translationResult)")
                    await addTranslationToSession(transcriptionResult, translationResult: translationResult, session: &session)
                } else {
                    print("Translation result was empty")
                }
            }
            
            // Update the current session with the modified session
            currentSession = session
            
        } catch {
            print("Transcription error: \(error)")
            DispatchQueue.main.async {
                self.lastError = "Transcription failed: \(error.localizedDescription)"
            }
        }
        
        DispatchQueue.main.async {
            self.isProcessing = false
        }
    }
    
    private func addTranscriptionToSession(_ result: TranscriptionResult, session: inout TranscriptionSession) async {
        await MainActor.run {
            for segment in result.segments {
                session.transcriptions.append(segment)
            }
            
            // Update UI
            objectWillChange.send()
        }
    }
    
    private func addTranslationToSession(_ transcription: TranscriptionResult, translationResult: TranscriptionResult, session: inout TranscriptionSession) async {
        await MainActor.run {
            for (index, segment) in transcription.segments.enumerated() {
                if index < translationResult.segments.count {
                    let translationSegment = TranslationSegment(
                        text: translationResult.segments[index].text,
                        timestamp: segment.timestamp,
                        originalText: segment.text,
                        sourceLanguage: "ja"
                    )
                    session.translations.append(translationSegment)
                }
            }
            
            // Update UI
            objectWillChange.send()
        }
    }
    
    // MARK: - Session Management
    
    private func finalizeCurrentSession() {
        guard var session = currentSession else { return }
        
        session.endTime = Date()
        
        // Save session
        saveSession(session)
        
        // Clear current session
        currentSession = nil
        sessionStartTime = nil
        audioChunks.removeAll()
    }
    
    func saveCurrentSession() {
        guard var session = currentSession else { return }
        
        // Add metadata if not already set
        if session.metadata.contactName == nil {
            session.metadata.contactName = "Unknown Contact"
        }
        if session.metadata.topic == nil {
            session.metadata.topic = "General Conversation"
        }
        
        // Finalize and save
        finalizeCurrentSession()
    }
    
    private func saveSession(_ session: TranscriptionSession) {
        savedSessions.append(session)
        saveSessionsToDisk()
        
        print("Saved session: \(session.id) with \(session.transcriptions.count) transcriptions")
    }
    
    // MARK: - Auto-save
    
    private func startAutoSaveTimer() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: settings.saveInterval, repeats: true) { [weak self] _ in
            self?.autoSaveCurrentSession()
        }
    }
    
    private func autoSaveCurrentSession() {
        guard let session = currentSession, !session.transcriptions.isEmpty else { return }
        
        // Create a copy of the current session for auto-save
        var autoSaveSession = TranscriptionSession(id: UUID(), startTime: session.startTime)
        autoSaveSession.endTime = Date()
        autoSaveSession.transcriptions = session.transcriptions
        autoSaveSession.translations = session.translations
        autoSaveSession.metadata = session.metadata
        autoSaveSession.metadata.topic = (session.metadata.topic ?? "General Conversation") + " (Auto-save)"
        
        saveSession(autoSaveSession)
    }
    
    // MARK: - Session Persistence
    
    private func saveSessionsToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(savedSessions)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let sessionsFile = documentsPath?.appendingPathComponent("transcription_sessions.json")
            
            if let sessionsFile = sessionsFile {
                try data.write(to: sessionsFile)
            }
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSavedSessions() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let sessionsFile = documentsPath?.appendingPathComponent("transcription_sessions.json")
        
        guard let sessionsFile = sessionsFile,
              FileManager.default.fileExists(atPath: sessionsFile.path) else { return }
        
        do {
            let data = try Data(contentsOf: sessionsFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let loadedSessions = try decoder.decode([TranscriptionSession].self, from: data)
            savedSessions = loadedSessions
            
            print("Loaded \(loadedSessions.count) saved sessions")
        } catch {
            print("Failed to load saved sessions: \(error)")
        }
    }
    
    // MARK: - Session Search and Filtering
    
    func searchSessions(_ criteria: SearchCriteria) -> [TranscriptionSession] {
        return savedSessions.filter { session in
            var matches = true
            
            // Text search
            if !criteria.query.isEmpty {
                let query = criteria.query.lowercased()
                let hasMatch = session.transcriptions.contains { transcription in
                    transcription.text.lowercased().contains(query)
                } || session.translations.contains { translation in
                    translation.text.lowercased().contains(query)
                }
                matches = matches && hasMatch
            }
            
            // Date range
            if let dateRange = criteria.dateRange {
                matches = matches && dateRange.contains(session.startTime)
            }
            
            // Tags
            if !criteria.tags.isEmpty {
                let sessionTags = Set(session.metadata.tags.map { $0.lowercased() })
                let searchTags = Set(criteria.tags.map { $0.lowercased() })
                matches = matches && !sessionTags.isDisjoint(with: searchTags)
            }
            
            // Confidence threshold
            if let minConfidence = criteria.minConfidence {
                let hasConfidence = session.transcriptions.contains { transcription in
                    if let confidence = Float(transcription.confidence) {
                        return confidence >= minConfidence
                    }
                    return false
                }
                matches = matches && hasConfidence
            }
            
            // Has translation
            if let hasTranslation = criteria.hasTranslation {
                matches = matches && (hasTranslation == !session.translations.isEmpty)
            }
            
            return matches
        }
    }
    
    // MARK: - Export
    
    func exportSession(_ session: TranscriptionSession, format: ExportFormat) -> String {
        return session.export(to: format)
    }
    
    func exportAllSessions(_ format: ExportFormat) -> String {
        var exportText = "All Transcription Sessions\n"
        exportText += "========================\n\n"
        
        for (index, session) in savedSessions.enumerated() {
            exportText += "Session \(index + 1)\n"
            exportText += "-------------\n"
            exportText += session.export(to: format)
            exportText += "\n\n"
        }
        
        return exportText
    }
    
    // MARK: - Session Metadata
    
    func updateSessionMetadata(contactName: String?, topic: String?, notes: String?, tags: [String]) {
        guard var session = currentSession else { return }
        
        session.metadata.contactName = contactName
        session.metadata.topic = topic
        session.metadata.notes = notes
        session.metadata.tags = tags
    }
    
    // MARK: - Statistics
    
    var totalTranscriptions: Int {
        return savedSessions.reduce(0) { $0 + $1.transcriptions.count }
    }
    
    var totalDuration: TimeInterval {
        return savedSessions.reduce(0) { $0 + $1.duration }
    }
    
    var averageSessionLength: TimeInterval {
        guard !savedSessions.isEmpty else { return 0 }
        return totalDuration / Double(savedSessions.count)
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        lastError = nil
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: TranscriptionSettings) {
        settings = newSettings
        
        // Apply changes
        if isRecording && settings.autoSave {
            startAutoSaveTimer()
        } else if !settings.autoSave {
            autoSaveTimer?.invalidate()
            autoSaveTimer = nil
        }
    }
    
    func resetSettings() {
        settings = TranscriptionSettings.default
    }
}

// MARK: - Extensions

extension TranscriptionManager {
    func getSessionById(_ id: UUID) -> TranscriptionSession? {
        return savedSessions.first { $0.id == id }
    }
    
    func deleteSession(_ session: TranscriptionSession) {
        if let index = savedSessions.firstIndex(where: { $0.id == session.id }) {
            savedSessions.remove(at: index)
            saveSessionsToDisk()
        }
    }
    
    func duplicateSession(_ session: TranscriptionSession) -> TranscriptionSession {
        var newSession = TranscriptionSession()
        newSession.transcriptions = session.transcriptions
        newSession.translations = session.translations
        newSession.metadata = session.metadata
        newSession.metadata.topic = (session.metadata.topic ?? "General Conversation") + " (Copy)"
        
        return newSession
    }
} 