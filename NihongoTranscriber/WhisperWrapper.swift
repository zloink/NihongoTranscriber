import Foundation
import Combine

class WhisperWrapper: ObservableObject, Sendable {
    @Published var isProcessing = false
    @Published var currentModel = "ggml-medium"
    @Published var availableModels: [String] = []
    
    private var whisperProcess: Process?
    private var whisperQueue = DispatchQueue(label: "whisper.processing", qos: .userInitiated)
    private var tempDirectory: URL?
    
    // Configuration
    private let whisperCLIPath: String
    private let modelsDirectory: String
    private let chunkDuration: TimeInterval = 3.0
    
    init() {
        // Try to find whisper.cpp in common locations
        let possiblePaths = [
            "./whisper.cpp/build/bin/whisper-cli",
            "../whisper.cpp/build/bin/whisper-cli",
            "~/whisper.cpp/build/bin/whisper-cli",
            "/usr/local/bin/whisper-cli"
        ]
        
        // Find the first existing path
        var foundPath: String?
        for path in possiblePaths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                foundPath = expandedPath
                break
            }
        }
        
        self.whisperCLIPath = foundPath ?? possiblePaths[0]
        
        // Try to find models directory
        let possibleModelPaths = [
            "./whisper.cpp/models",
            "../whisper.cpp/models",
            "~/whisper.cpp/models",
            "/usr/local/share/whisper/models"
        ]
        
        var foundModelPath: String?
        for path in possibleModelPaths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                foundModelPath = expandedPath
                break
            }
        }
        
        self.modelsDirectory = foundModelPath ?? possibleModelPaths[0]
        
        print("WhisperWrapper initialized with:")
        print("  CLI Path: \(self.whisperCLIPath)")
        print("  Models Path: \(self.modelsDirectory)")
        
        discoverAvailableModels()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Model Management
    
    private func discoverAvailableModels() {
        let fileManager = FileManager.default
        guard let modelsURL = URL(string: modelsDirectory) else { return }
        
        do {
            let modelFiles = try fileManager.contentsOfDirectory(at: modelsURL, includingPropertiesForKeys: nil)
            availableModels = modelFiles
                .filter { $0.pathExtension == "bin" }
                .map { $0.lastPathComponent }
                .sorted()
        } catch {
            print("Failed to discover models: \(error)")
        }
        
        // Set default model if available
        if availableModels.isEmpty {
            availableModels = ["ggml-small.bin", "ggml-medium.bin", "ggml-large.bin"]
        }
        
        if let mediumModel = availableModels.first(where: { $0.contains("medium") }) {
            currentModel = mediumModel
        } else if let firstModel = availableModels.first {
            currentModel = firstModel
        }
    }
    
    func selectModel(_ modelName: String) {
        guard availableModels.contains(modelName) else { return }
        currentModel = modelName
    }
    
    // MARK: - Audio Processing
    
    func transcribeAudio(_ audioData: Data, language: String = "ja") async throws -> TranscriptionResult {
        return try await withCheckedThrowingContinuation { continuation in
            whisperQueue.async {
                do {
                    let result = try self.processAudioWithWhisper(audioData, language: language, translate: false)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func translateAudio(_ audioData: Data, sourceLanguage: String = "ja") async throws -> TranscriptionResult {
        return try await withCheckedThrowingContinuation { continuation in
            whisperQueue.async {
                do {
                    let result = try self.processAudioWithWhisper(audioData, language: sourceLanguage, translate: true)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func processAudioWithWhisper(_ audioData: Data, language: String, translate: Bool) throws -> TranscriptionResult {
        // Create temporary audio file
        let tempFile = try createTemporaryAudioFile(from: audioData)
        defer { cleanupTemporaryFile(tempFile) }
        
        // Build whisper command
        var command = [whisperCLIPath, "-m", "\(modelsDirectory)/\(currentModel)", "-f", tempFile.path]
        
        // Language settings
        if !language.isEmpty {
            command.append(contentsOf: ["-l", language])
        }
        
        // Translation flag
        if translate {
            command.append("--translate")
        }
        
        // Output format
        command.append(contentsOf: ["--output-format", "json"])
        command.append("--no-timestamps")
        
        // Execute whisper
        let result = try executeWhisperCommand(command)
        
        // Parse result
        return try parseWhisperOutput(result)
    }
    
    private func createTemporaryAudioFile(from audioData: Data) throws -> URL {
        let tempDir = try createTempDirectory()
        let fileName = "audio_\(Date().timeIntervalSince1970).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Convert raw PCM to WAV format
        let wavData = try convertPCMToWAV(audioData)
        try wavData.write(to: fileURL)
        
        return fileURL
    }
    
    private func convertPCMToWAV(_ pcmData: Data) throws -> Data {
        // WAV header for 16-bit PCM, mono, 16kHz
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(pcmData.count)
        let fileSize = 36 + dataSize
        
        var wavData = Data()
        
        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wavData.append(contentsOf: "WAVE".utf8)
        
        // fmt chunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // chunk size
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // audio format (PCM)
        wavData.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // data chunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        wavData.append(pcmData)
        
        return wavData
    }
    
    private func createTempDirectory() throws -> URL {
        if let existing = tempDirectory {
            return existing
        }
        
        let tempDir = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: FileManager.default.temporaryDirectory,
            create: true
        )
        tempDirectory = tempDir
        return tempDir
    }
    
    private func cleanupTemporaryFile(_ fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    private func cleanup() {
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
            tempDirectory = nil
        }
    }
    
    // MARK: - Command Execution
    
    private func executeWhisperCommand(_ command: [String]) throws -> String {
        print("Executing Whisper command: \(command.joined(separator: " "))")
        
        // Check if whisper-cli exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: command[0]) {
            print("ERROR: whisper-cli not found at path: \(command[0])")
            throw WhisperError.executionFailed(
                status: -1,
                output: "",
                error: "whisper-cli executable not found at: \(command[0])"
            )
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command[0])
        process.arguments = Array(command.dropFirst())
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        print("Starting Whisper process...")
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        print("Whisper process completed with status: \(process.terminationStatus)")
        print("Output: \(output)")
        if !error.isEmpty {
            print("Error: \(error)")
        }
        
        if process.terminationStatus != 0 {
            throw WhisperError.executionFailed(
                status: Int(process.terminationStatus),
                output: output,
                error: error
            )
        }
        
        return output
    }
    
    // MARK: - Output Parsing
    
    private func parseWhisperOutput(_ output: String) throws -> TranscriptionResult {
        // Try to parse as JSON first
        if let jsonData = output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let segments = json["segments"] as? [[String: Any]] {
            
            return parseJSONOutput(segments)
        }
        
        // Fallback to plain text parsing
        return parsePlainTextOutput(output)
    }
    
    private func parseJSONOutput(_ segments: [[String: Any]]) -> TranscriptionResult {
        var transcriptions: [TranscriptionSegment] = []
        var fullText = ""
        
        for segment in segments {
            if let text = segment["text"] as? String,
               let start = segment["start"] as? Double {
                
                let end = segment["end"] as? Double ?? start + 3.0
                let confidence = segment["avg_logprob"] as? Double ?? 0.0
                
                let transcription = TranscriptionSegment(
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                    timestamp: Date(),
                    confidence: String(format: "%.2f", confidence),
                    audioStart: start,
                    audioEnd: end
                )
                
                transcriptions.append(transcription)
                fullText += text + " "
            }
        }
        
        return TranscriptionResult(
            text: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
            segments: transcriptions,
            language: "ja",
            confidence: calculateOverallConfidence(transcriptions)
        )
    }
    
    private func parsePlainTextOutput(_ output: String) -> TranscriptionResult {
        let lines = output.components(separatedBy: .newlines)
        let filteredLines = lines.filter { line in
            !line.isEmpty &&
            !line.hasPrefix("system_info:") &&
            !line.hasPrefix("main:") &&
            !line.hasPrefix("whisper_print_timings:") &&
            !line.hasPrefix("ggml_") &&
            !line.contains("-->")
        }
        
        let fullText = filteredLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let transcription = TranscriptionSegment(
            text: fullText,
            timestamp: Date(),
            confidence: "",
            audioStart: 0,
            audioEnd: chunkDuration
        )
        
        return TranscriptionResult(
            text: fullText,
            segments: [transcription],
            language: "ja",
            confidence: "0.0"
        )
    }
    
    private func calculateOverallConfidence(_ segments: [TranscriptionSegment]) -> String {
        guard !segments.isEmpty else { return "0.0" }
        
        let confidences = segments.compactMap { Float($0.confidence) }
        let average = confidences.reduce(0, +) / Float(confidences.count)
        
        return String(format: "%.2f", average)
    }
    
    // MARK: - Batch Processing
    
    func processAudioChunks(_ chunks: [Data], language: String = "ja", translate: Bool = false) async throws -> [TranscriptionResult] {
        var results: [TranscriptionResult] = []
        
        for chunk in chunks {
            let result: TranscriptionResult
            if translate {
                result = try await translateAudio(chunk, sourceLanguage: language)
            } else {
                result = try await transcribeAudio(chunk, language: language)
            }
            results.append(result)
        }
        
        return results
    }
    
    // MARK: - Model Information
    
    func getModelInfo(_ modelName: String) -> ModelInfo? {
        let modelPath = "\(modelsDirectory)/\(modelName)"
        
        guard FileManager.default.fileExists(atPath: modelPath) else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: modelPath)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            return ModelInfo(
                name: modelName,
                size: fileSize,
                path: modelPath,
                isAvailable: true
            )
        } catch {
            return nil
        }
    }
}

// MARK: - Supporting Types

struct TranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String
    let confidence: String
    
    var isEmpty: Bool {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ModelInfo {
    let name: String
    let size: Int64
    let path: String
    let isAvailable: Bool
    
    var sizeInMB: Double {
        return Double(size) / (1024 * 1024)
    }
    
    var sizeDescription: String {
        if sizeInMB >= 1024 {
            return String(format: "%.1f GB", sizeInMB / 1024)
        } else {
            return String(format: "%.1f MB", sizeInMB)
        }
    }
}

// MARK: - Errors

enum WhisperError: LocalizedError {
    case modelNotFound
    case audioProcessingFailed
    case outputParsingFailed
    case executionFailed(status: Int, output: String, error: String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Whisper model not found"
        case .audioProcessingFailed:
            return "Failed to process audio data"
        case .outputParsingFailed:
            return "Failed to parse Whisper output"
        case .executionFailed(let status, let output, let error):
            return "Whisper execution failed with status \(status). Output: \(output). Error: \(error)"
        }
    }
}

// MARK: - Extensions

extension WhisperWrapper {
    func validateInstallation() -> Bool {
        let fileManager = FileManager.default
        
        // Check if whisper-cli exists
        guard fileManager.fileExists(atPath: whisperCLIPath) else {
            print("Whisper CLI not found at: \(whisperCLIPath)")
            return false
        }
        
        // Check if models directory exists
        guard fileManager.fileExists(atPath: modelsDirectory) else {
            print("Models directory not found at: \(modelsDirectory)")
            return false
        }
        
        // Check if current model exists
        let modelPath = "\(modelsDirectory)/\(currentModel)"
        guard fileManager.fileExists(atPath: modelPath) else {
            print("Model not found at: \(modelPath)")
            return false
        }
        
        return true
    }
    
    func getRecommendedModel() -> String {
        // Prefer medium model for good balance of speed and accuracy
        if availableModels.contains("ggml-medium.bin") {
            return "ggml-medium.bin"
        } else if availableModels.contains("ggml-large.bin") {
            return "ggml-large.bin"
        } else if availableModels.contains("ggml-small.bin") {
            return "ggml-small.bin"
        } else if let firstModel = availableModels.first {
            return firstModel
        }
        
        return "ggml-medium.bin"
    }
} 