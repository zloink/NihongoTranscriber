import Foundation

// MARK: - Data Models

struct TranscriptionSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var transcriptions: [TranscriptionSegment]
    var translations: [TranslationSegment]
    var metadata: SessionMetadata
    
    init(id: UUID = UUID(), startTime: Date = Date()) {
        self.id = id
        self.startTime = startTime
        self.transcriptions = []
        self.translations = []
        self.metadata = SessionMetadata()
    }
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var isComplete: Bool {
        endTime != nil
    }
}

struct TranscriptionSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let confidence: String
    let audioStart: TimeInterval
    let audioEnd: TimeInterval
    
    init(id: UUID = UUID(), text: String, timestamp: Date = Date(), confidence: String = "", audioStart: TimeInterval = 0, audioEnd: TimeInterval = 0) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.confidence = confidence
        self.audioStart = audioStart
        self.audioEnd = audioEnd
    }
}

struct TranslationSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let originalText: String
    let sourceLanguage: String
    
    init(id: UUID = UUID(), text: String, timestamp: Date = Date(), originalText: String = "", sourceLanguage: String = "ja") {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.originalText = originalText
        self.sourceLanguage = sourceLanguage
    }
}

struct SessionMetadata: Codable {
    var contactName: String?
    var topic: String?
    var notes: String?
    var tags: [String]
    var audioSource: AudioSource
    var modelUsed: String
    var quality: String
    
    init() {
        self.contactName = nil
        self.topic = nil
        self.notes = nil
        self.tags = []
        self.audioSource = .systemAudio
        self.modelUsed = "ggml-medium"
        self.quality = "high"
    }
}

// MARK: - Audio Source Enum

enum AudioSource: String, CaseIterable, Codable {
    case systemAudio = "system"
    case specificApp = "app"
    case microphone = "microphone"
    case allAudio = "all"
    
    var displayName: String {
        switch self {
        case .systemAudio:
            return "System Audio"
        case .specificApp:
            return "Specific App"
        case .microphone:
            return "Microphone"
        case .allAudio:
            return "All Audio"
        }
    }
    
    var description: String {
        switch self {
        case .systemAudio:
            return "Capture system audio output (WhatsApp, FaceTime, etc.)"
        case .specificApp:
            return "Capture audio from a specific application"
        case .microphone:
            return "Capture microphone input only"
        case .allAudio:
            return "Capture all available audio sources"
        }
    }
}

// MARK: - Export Formats

enum ExportFormat: String, CaseIterable {
    case text = "txt"
    case json = "json"
    case csv = "csv"
    case markdown = "md"
    
    var displayName: String {
        switch self {
        case .text: return "Plain Text"
        case .json: return "JSON"
        case .csv: return "CSV"
        case .markdown: return "Markdown"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}

// MARK: - Transcription Settings

struct TranscriptionSettings: Codable, Equatable {
    var chunkDuration: TimeInterval
    var enableTranslation: Bool
    var targetLanguage: String
    var modelSize: String
    var confidenceThreshold: Float
    var autoSave: Bool
    var saveInterval: TimeInterval
    
    static let `default` = TranscriptionSettings(
        chunkDuration: 3.0,           // 3-second chunks for near real-time
        enableTranslation: true,
        targetLanguage: "en",
        modelSize: "ggml-medium",
        confidenceThreshold: 0.7,
        autoSave: true,
        saveInterval: 300              // Auto-save every 5 minutes
    )
}

// MARK: - Search and Filter

struct SearchCriteria {
    var query: String
    var dateRange: DateInterval?
    var tags: [String]
    var minConfidence: Float?
    var hasTranslation: Bool?
    
    init(query: String = "", dateRange: DateInterval? = nil, tags: [String] = [], minConfidence: Float? = nil, hasTranslation: Bool? = nil) {
        self.query = query
        self.dateRange = dateRange
        self.tags = tags
        self.minConfidence = minConfidence
        self.hasTranslation = hasTranslation
    }
}

// MARK: - Extensions

extension TranscriptionSession {
    func export(to format: ExportFormat) -> String {
        switch format {
        case .text:
            return exportAsText()
        case .json:
            return exportAsJSON()
        case .csv:
            return exportAsCSV()
        case .markdown:
            return exportAsMarkdown()
        }
    }
    
    private func exportAsText() -> String {
        var text = "Transcription Session\n"
        text += "====================\n\n"
        text += "Date: \(startTime.formatted(date: .complete, time: .shortened))\n"
        text += "Duration: \(formatDuration(duration))\n"
        
        if let contact = metadata.contactName {
            text += "Contact: \(contact)\n"
        }
        if let topic = metadata.topic {
            text += "Topic: \(topic)\n"
        }
        if !metadata.tags.isEmpty {
            text += "Tags: \(metadata.tags.joined(separator: ", "))\n"
        }
        
        text += "\nTranscriptions:\n"
        text += "---------------\n"
        
        for (index, segment) in transcriptions.enumerated() {
            text += "\n[\(index + 1)] \(segment.timestamp.formatted(date: .omitted, time: .standard))\n"
            text += "\(segment.text)\n"
            if !segment.confidence.isEmpty {
                text += "Confidence: \(segment.confidence)\n"
            }
        }
        
        if !translations.isEmpty {
            text += "\nTranslations:\n"
            text += "-------------\n"
            
            for (index, segment) in translations.enumerated() {
                text += "\n[\(index + 1)] \(segment.timestamp.formatted(date: .omitted, time: .standard))\n"
                text += "Original: \(segment.originalText)\n"
                text += "English: \(segment.text)\n"
            }
        }
        
        return text
    }
    
    private func exportAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        if let data = try? encoder.encode(self),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
    
    private func exportAsCSV() -> String {
        var csv = "Timestamp,Text,Confidence,AudioStart,AudioEnd\n"
        
        for segment in transcriptions {
            let row = "\(segment.timestamp.formatted(date: .omitted, time: .standard)),\"\(segment.text.replacingOccurrences(of: "\"", with: "\"\""))\",\(segment.confidence),\(segment.audioStart),\(segment.audioEnd)\n"
            csv += row
        }
        
        return csv
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
    
    private func exportAsMarkdown() -> String {
        var markdown = "# Transcription Session\n\n"
        markdown += "**Date:** \(startTime.formatted(date: .complete, time: .shortened))\n"
        markdown += "**Duration:** \(formatDuration(duration))\n"
        
        if let contact = metadata.contactName {
            markdown += "**Contact:** \(contact)\n"
        }
        if let topic = metadata.topic {
            markdown += "**Topic:** \(topic)\n"
        }
        if !metadata.tags.isEmpty {
            markdown += "**Tags:** \(metadata.tags.joined(separator: ", "))\n"
        }
        
        markdown += "\n## Transcriptions\n\n"
        
        for (index, segment) in transcriptions.enumerated() {
            markdown += "### \(index + 1). \(segment.timestamp.formatted(date: .omitted, time: .standard))\n\n"
            markdown += "\(segment.text)\n\n"
            if !segment.confidence.isEmpty {
                markdown += "*Confidence: \(segment.confidence)*\n\n"
            }
        }
        
        if !translations.isEmpty {
            markdown += "## Translations\n\n"
            
            for (index, segment) in translations.enumerated() {
                markdown += "### \(index + 1). \(segment.timestamp.formatted(date: .omitted, time: .standard))\n\n"
                markdown += "**Original:** \(segment.originalText)\n\n"
                markdown += "**English:** \(segment.text)\n\n"
            }
        }
        
        return markdown
    }
} 