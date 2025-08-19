import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox

class AudioCaptureManager: NSObject, ObservableObject {
    @Published var hasPermissions = false
    @Published var isCapturing = false
    @Published var audioLevel: Float = 0.0
    @Published var availableAudioSources: [AudioSourceInfo] = []
    @Published var selectedAudioSource: AudioSourceInfo?
    
    // Core Audio properties for system audio capture
    private var audioUnit: AudioUnit?
    private var audioFormat: AudioStreamBasicDescription?
    
    // Audio processing properties
    private let sampleRate: Double = 16000  // Whisper.cpp recommended sample rate
    private let chunkDuration: TimeInterval = 3.0  // 3-second chunks
    private var audioChunks: [Data] = []
    
    // Timers
    private var audioLevelTimer: Timer?
    private var chunkTimer: Timer?
    
    // Callbacks
    var onAudioChunk: ((Data) -> Void)?
    var onAudioLevelChange: ((Float) -> Void)?
    var onError: ((Error) -> Void)?
    
    override init() {
        super.init()
        setupAudioFormat()
        discoverAudioSources()
        requestPermissions()
    }
    
    deinit {
        stopCapture()
    }
    
    // MARK: - Audio Format Setup
    
    private func setupAudioFormat() {
        audioFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
    }
    
    // MARK: - Permissions
    
    func requestPermissions() {
        // For system audio capture on macOS, we need to request accessibility permissions
        // This is a simplified approach - in production you'd want more robust permission handling
        DispatchQueue.main.async {
            self.hasPermissions = true
        }
    }
    
    // MARK: - Audio Source Discovery
    
    func discoverAudioSources() {
        availableAudioSources.removeAll()
        
        // System audio output (what you hear)
        let systemAudio = AudioSourceInfo(
            id: "system",
            name: "System Audio Output",
            type: .systemOutput,
            description: "Capture audio from applications like WhatsApp, FaceTime, etc."
        )
        availableAudioSources.append(systemAudio)
        
        // Microphone input
        let microphone = AudioSourceInfo(
            id: "microphone",
            name: "Microphone",
            type: .microphone,
            description: "Capture your voice input"
        )
        availableAudioSources.append(microphone)
        
        // Set default selection
        selectedAudioSource = systemAudio
    }
    
    // MARK: - Audio Capture Control
    
    func startCapture() {
        guard hasPermissions else {
            onError?(AudioCaptureError.noPermissions)
            return
        }
        
        do {
            try setupSystemAudioCapture()
            isCapturing = true
            startAudioLevelMonitoring()
            startChunkTimer()
            
        } catch {
            print("Failed to start audio capture: \(error)")
            onError?(error)
        }
    }
    
    func stopCapture() {
        stopAudioLevelMonitoring()
        stopChunkTimer()
        
        if let audioUnit = audioUnit {
            AudioUnitUninitialize(audioUnit)
            AudioComponentInstanceDispose(audioUnit)
            self.audioUnit = nil
        }
        
        isCapturing = false
        audioLevel = 0.0
        audioChunks.removeAll()
    }
    
    func pauseCapture() {
        if let audioUnit = audioUnit {
            AudioOutputUnitStop(audioUnit)
        }
        stopAudioLevelMonitoring()
        stopChunkTimer()
    }
    
    func resumeCapture() {
        if let audioUnit = audioUnit {
            AudioOutputUnitStart(audioUnit)
            startAudioLevelMonitoring()
            startChunkTimer()
        }
    }
    
    // MARK: - System Audio Capture Setup
    
    private func setupSystemAudioCapture() throws {
        // Create an Audio Unit for system audio capture
        var audioComponentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        guard let audioComponent = AudioComponentFindNext(nil, &audioComponentDescription) else {
            throw AudioCaptureError.engineCreationFailed
        }
        
        var audioUnit: AudioUnit?
        var status = AudioComponentInstanceNew(audioComponent, &audioUnit)
        guard status == noErr, let au = audioUnit else {
            throw AudioCaptureError.engineCreationFailed
        }
        
        self.audioUnit = au
        
        // Enable input
        var enableIO: UInt32 = 1
        status = AudioUnitSetProperty(au, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, UInt32(MemoryLayout<UInt32>.size))
        guard status == noErr else {
            throw AudioCaptureError.engineCreationFailed
        }
        
        // Set audio format
        if let format = audioFormat {
            var mutableFormat = format
            status = AudioUnitSetProperty(au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &mutableFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            guard status == noErr else {
                throw AudioCaptureError.engineCreationFailed
            }
        }
        
        // Set callback
        var callbackStruct = AURenderCallbackStruct(
            inputProc: { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
                let manager = Unmanaged<AudioCaptureManager>.fromOpaque(inRefCon).takeUnretainedValue()
                return manager.processAudioData(inNumberFrames: inNumberFrames, ioData: ioData)
            },
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        
        status = AudioUnitSetProperty(au, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        guard status == noErr else {
            throw AudioCaptureError.engineCreationFailed
        }
        
        // Initialize and start
        status = AudioUnitInitialize(au)
        guard status == noErr else {
            throw AudioCaptureError.engineCreationFailed
        }
        
        status = AudioOutputUnitStart(au)
        guard status == noErr else {
            throw AudioCaptureError.engineCreationFailed
        }
    }
    
    // MARK: - Audio Processing Callback
    
    private func processAudioData(inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
        // For now, we'll simulate audio data since actual system audio capture requires more complex setup
        // In a full implementation, you'd process the actual audio data from ioData
        
        // Simulate audio level changes for testing
        let simulatedLevel = Float.random(in: 0.0...0.8)
        DispatchQueue.main.async {
            self.audioLevel = simulatedLevel
        }
        
        // Simulate audio chunks for testing
        let simulatedAudioData = Data(repeating: 0, count: Int(inNumberFrames) * 2) // 16-bit samples
        audioChunks.append(simulatedAudioData)
        
        return noErr
    }
    
    // MARK: - Chunk Management
    
    private func startChunkTimer() {
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: true) { [weak self] _ in
            self?.processAudioChunk()
        }
    }
    
    private func stopChunkTimer() {
        chunkTimer?.invalidate()
        chunkTimer = nil
    }
    
    private func processAudioChunk() {
        guard !audioChunks.isEmpty else { return }
        
        // Combine all audio data into one chunk
        let combinedData = audioChunks.reduce(Data(), +)
        audioChunks.removeAll()
        
        // Send to callback
        onAudioChunk?(combinedData)
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }
    
    private func updateAudioLevel() {
        onAudioLevelChange?(audioLevel)
    }
    
    // MARK: - Audio Source Selection
    
    func selectAudioSource(_ source: AudioSourceInfo) {
        selectedAudioSource = source
        
        // Restart capture if currently running
        if isCapturing {
            stopCapture()
            startCapture()
        }
    }
    
    // MARK: - Utility Methods
    
    func getAudioLevel() -> Float {
        return audioLevel
    }
    
    func isAudioPlaying() -> Bool {
        return audioLevel > 0.01  // Threshold for detecting audio
    }
}

// MARK: - Supporting Types

struct AudioSourceInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let type: AudioSourceType
    let description: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AudioSourceInfo, rhs: AudioSourceInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

enum AudioSourceType {
    case systemOutput
    case microphone
    case specificApp
    case allAudio
}

// MARK: - Errors

enum AudioCaptureError: LocalizedError {
    case noPermissions
    case engineCreationFailed
    case invalidAudioFormat
    case captureFailed
    
    var errorDescription: String? {
        switch self {
        case .noPermissions:
            return "Microphone permissions are required"
        case .engineCreationFailed:
            return "Failed to create audio engine"
        case .invalidAudioFormat:
            return "Invalid audio format"
        case .captureFailed:
            return "Audio capture failed"
        }
    }
}

// MARK: - Extensions

extension AudioCaptureManager {
    func exportAudioChunk(_ data: Data, format: String = "wav") -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fileName = "audio_chunk_\(Date().timeIntervalSince1970).\(format)"
        
        guard let fileURL = documentsPath?.appendingPathComponent(fileName) else { return nil }
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save audio chunk: \(error)")
            return nil
        }
    }
} 