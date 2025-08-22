import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox
import os.log

class AudioCaptureManager: NSObject, ObservableObject {
    @Published var hasPermissions = false
    @Published var isCapturing = false
    @Published var audioLevel: Float = 0.0
    @Published var availableAudioSources: [AudioSourceInfo] = []
    @Published var selectedAudioSource: AudioSourceInfo?
    
    // Logger for system console
    private let logger = Logger(subsystem: "com.yourcompany.NihongoTranscriber", category: "AudioCapture")
    
    // Audio processing properties
    private let sampleRate: Double = 16000  // Whisper.cpp recommended sample rate
    private let chunkDuration: TimeInterval = 3.0  // 3-second chunks
    private var audioChunks: [Data] = []
    
    // Core Audio properties
    private var audioUnit: AudioUnit?
    private var audioFormat: AudioStreamBasicDescription?
    
    // Callbacks
    var onAudioChunk: ((Data) -> Void)?
    var onAudioLevelChange: ((Float) -> Void)?
    var onError: ((Error) -> Void)?
    
    // Timers
    private var audioLevelTimer: Timer?
    private var chunkTimer: Timer?
    
    override init() {
        super.init()
        print("AudioCaptureManager: Initialized")
        requestPermissions()
    }
    
    deinit {
        stopCapture()
    }
    
    // MARK: - Permissions
    
    func requestPermissions() {
        print("AudioCaptureManager: Requesting permissions...")
        // For audio capture on macOS, we need microphone permissions
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            DispatchQueue.main.async {
                self.hasPermissions = true
                print("AudioCaptureManager: Audio permissions already granted")
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.hasPermissions = granted
                    if granted {
                        print("AudioCaptureManager: Audio permissions granted")
                    } else {
                        print("AudioCaptureManager: Audio permissions denied")
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.hasPermissions = false
                print("AudioCaptureManager: Audio permissions denied or restricted")
                self.onError?(AudioCaptureError.noPermissions)
            }
        @unknown default:
            DispatchQueue.main.async {
                self.hasPermissions = false
                print("AudioCaptureManager: Unknown audio permission status")
            }
        }
    }
    
    // MARK: - Audio Capture Control
    
    func startCapture() {
        logger.info("🎤 Starting audio capture...")
        logger.info("🔐 Has permissions: \(self.hasPermissions)")
        
        guard hasPermissions else {
            logger.warning("❌ No permissions, requesting...")
            requestPermissions()
            onError?(AudioCaptureError.noPermissions)
            return
        }
        
        do {
            logger.info("⚙️ Setting up audio capture...")
            try setupAudioCapture()
            logger.info("✅ Audio capture setup successful")
            
            isCapturing = true
            startAudioLevelMonitoring()
            startChunkTimer()
            
            logger.info("🎯 Capture started successfully")
            
        } catch {
            logger.error("💥 Failed to start audio capture: \(error)")
            logger.error("📝 Error details: \(error.localizedDescription)")
            onError?(error)
        }
    }
    
    func stopCapture() {
        print("AudioCaptureManager: Stopping capture...")
        stopAudioLevelMonitoring()
        stopChunkTimer()
        
        if let audioUnit = audioUnit {
            AudioUnitUninitialize(audioUnit)
            AudioComponentInstanceDispose(audioUnit)
        }
        
        Task { @MainActor in
            isCapturing = false
            audioLevel = 0.0
            audioChunks.removeAll()
        }
        print("AudioCaptureManager: Capture stopped")
    }
    
    func pauseCapture() {
        print("AudioCaptureManager: Pausing capture...")
        if let audioUnit = audioUnit {
            AudioOutputUnitStop(audioUnit)
        }
        stopAudioLevelMonitoring()
        stopChunkTimer()
        print("AudioCaptureManager: Capture paused")
    }
    
    func resumeCapture() {
        print("AudioCaptureManager: Resuming capture...")
        do {
            try startAudioUnit()
            startAudioLevelMonitoring()
            startChunkTimer()
            print("AudioCaptureManager: Capture resumed")
        } catch {
            print("AudioCaptureManager: Failed to resume audio capture: \(error)")
        }
    }
    
    // MARK: - Audio Capture Setup
    
    private func setupAudioCapture() throws {
        print("AudioCaptureManager: Setting up Core Audio...")
        
        // Create audio format
        var audioFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2, // 16-bit = 2 bytes
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        
        self.audioFormat = audioFormat
        
        // Create audio unit
        var audioComponentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        guard let audioComponent = AudioComponentFindNext(nil, &audioComponentDescription) else {
            print("AudioCaptureManager: Failed to find audio component")
            throw AudioCaptureError.engineCreationFailed
        }
        
        var audioUnit: AudioUnit?
        var status = AudioComponentInstanceNew(audioComponent, &audioUnit)
        guard status == noErr, let au = audioUnit else {
            print("AudioCaptureManager: Failed to create audio unit: \(status)")
            throw AudioCaptureError.engineCreationFailed
        }
        
        self.audioUnit = au
        
        // Enable input
        var enableIO: UInt32 = 1
        status = AudioUnitSetProperty(au, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, UInt32(MemoryLayout<UInt32>.size))
        guard status == noErr else {
            print("AudioCaptureManager: Failed to enable input: \(status)")
            throw AudioCaptureError.engineCreationFailed
        }
        
        // Disable output
        enableIO = 0
        status = AudioUnitSetProperty(au, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enableIO, UInt32(MemoryLayout<UInt32>.size))
        guard status == noErr else {
            print("AudioCaptureManager: Failed to disable output: \(status)")
            throw AudioCaptureError.engineCreationFailed
        }
        
        // Set audio format
        status = AudioUnitSetProperty(au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        guard status == noErr else {
            print("AudioCaptureManager: Failed to set audio format: \(status)")
            throw AudioCaptureError.engineCreationFailed
        }
        
        // Set callback
        var callbackStruct = AURenderCallbackStruct(
            inputProc: { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
                let audioCaptureManager = Unmanaged<AudioCaptureManager>.fromOpaque(inRefCon).takeUnretainedValue()
                return audioCaptureManager.processAudioData(inNumberFrames: inNumberFrames, ioData: ioData)
            },
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        
        status = AudioUnitSetProperty(au, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        guard status == noErr else {
            print("AudioCaptureManager: Failed to set callback: \(status)")
            throw AudioCaptureError.engineCreationFailed
        }
        
        // Initialize and start
        status = AudioUnitInitialize(au)
        guard status == noErr else {
            print("AudioCaptureManager: Failed to initialize audio unit: \(status)")
            throw AudioCaptureError.engineCreationFailed
        }
        
        try startAudioUnit()
        print("AudioCaptureManager: Core Audio setup successful")
    }
    
    private func startAudioUnit() throws {
        guard let audioUnit = audioUnit else {
            throw AudioCaptureError.engineCreationFailed
        }
        
        let status = AudioOutputUnitStart(audioUnit)
        guard status == noErr else {
            print("AudioCaptureManager: Failed to start audio unit: \(status)")
            throw AudioCaptureError.engineCreationFailed
        }
        
        print("AudioCaptureManager: Audio unit started")
    }
    
    // MARK: - Audio Processing Callback
    
    private func processAudioData(inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
        // For now, simulate audio data since we're not actually capturing system audio yet
        // In a real implementation, this would process the actual audio data
        
                            // Simulate audio level
                    let randomLevel = Float.random(in: 0.0...1.0)
                    Task { @MainActor in
                        self.audioLevel = randomLevel
                    }
        
        return noErr
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startAudioLevelMonitoring() {
        print("AudioCaptureManager: Starting audio level monitoring...")
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isCapturing else { return }
            
            // Audio level is updated in the callback
            self.onAudioLevelChange?(self.audioLevel)
        }
        print("AudioCaptureManager: Audio level monitoring started")
    }
    
    private func stopAudioLevelMonitoring() {
        print("AudioCaptureManager: Stopping audio level monitoring...")
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        Task { @MainActor in
            audioLevel = 0.0
        }
        print("AudioCaptureManager: Audio level monitoring stopped")
    }
    
    private func startChunkTimer() {
        print("AudioCaptureManager: Starting chunk timer...")
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: true) { [weak self] _ in
            guard let self = self, self.isCapturing else { return }
            
            // For now, simulate audio chunks
            // In a real implementation, you'd collect actual audio data
            let simulatedAudioData = Data(repeating: 0, count: 1024) // 1KB of silence
            self.onAudioChunk?(simulatedAudioData)
        }
        print("AudioCaptureManager: Chunk timer started")
    }
    
    private func stopChunkTimer() {
        print("AudioCaptureManager: Stopping chunk timer...")
        chunkTimer?.invalidate()
        chunkTimer = nil
        print("AudioCaptureManager: Chunk timer stopped")
    }
    
    // MARK: - Audio Source Management
    
    func refreshAudioSources() {
        // This would enumerate available audio devices
        // For now, just provide a default source
        Task { @MainActor in
            availableAudioSources = [
                AudioSourceInfo(id: "default", name: "Default Audio Input", type: .microphone, description: "Default microphone input")
            ]
            selectedAudioSource = availableAudioSources.first
        }
    }
}

// MARK: - Error Types

enum AudioCaptureError: LocalizedError {
    case noPermissions
    case engineCreationFailed
    case invalidAudioFormat
    case audioSessionError
    
    var errorDescription: String? {
        switch self {
        case .noPermissions:
            return "Microphone access is required"
        case .engineCreationFailed:
            return "Failed to create audio capture engine"
        case .invalidAudioFormat:
            return "Invalid audio format"
        case .audioSessionError:
            return "Audio session error"
        }
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