import Foundation

// MARK: - Transcription Session

struct TranscriptionSession: Identifiable, Codable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var transcriptions: [TranscriptionSegment]
    var translations: [TranslationSegment]
    var metadata: SessionMetadata
    
    init(id: UUID = UUID(), startTime: Date = Date()) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.transcriptions = []
        self.translations = []
        self.metadata = SessionMetadata()
    }
    
    var duration: TimeInterval {
        let endTime = self.endTime ?? Date()
        return endTime.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let duration = self.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
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
        var output = "Transcription Session\n"
        output += "===================\n\n"
        output += "Session ID: \(id.uuidString)\n"
        output += "Start Time: \(startTime.formatted())\n"
        if let endTime = endTime {
            output += "End Time: \(endTime.formatted())\n"
        }
        output += "Duration: \(formattedDuration)\n\n"
        
        if let contactName = metadata.contactName {
            output += "Contact: \(contactName)\n"
        }
        if let topic = metadata.topic {
            output += "Topic: \(topic)\n"
        }
        if !metadata.tags.isEmpty {
            output += "Tags: \(metadata.tags.joined(separator: ", "))\n"
        }
        output += "\n"
        
        output += "Transcriptions:\n"
        output += "--------------\n"
        for transcription in transcriptions {
            output += "[\(transcription.timestamp.formatted(date: .omitted, time: .standard))] \(transcription.text)\n"
        }
        
        if !translations.isEmpty {
            output += "\nTranslations:\n"
            output += "------------\n"
            for translation in translations {
                output += "[\(translation.timestamp.formatted(date: .omitted, time: .standard))] \(translation.text)\n"
            }
        }
        
        return output
    }
    
    private func exportAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? "Error encoding JSON"
        } catch {
            return "Error encoding JSON: \(error)"
        }
    }
    
    private func exportAsCSV() -> String {
        var output = "Type,Timestamp,Text,Confidence,Original Text\n"
        
        for transcription in transcriptions {
            let timestamp = transcription.timestamp.formatted()
            let text = transcription.text.replacingOccurrences(of: "\"", with: "\"\"")
            let confidence = transcription.confidence
            output += "Transcription,\"\(timestamp)\",\"\(text)\",\"\(confidence)\",\n"
        }
        
        for translation in translations {
            let timestamp = translation.timestamp.formatted()
            let text = translation.text.replacingOccurrences(of: "\"", with: "\"\"")
            let originalText = translation.originalText.replacingOccurrences(of: "\"", with: "\"\"")
            output += "Translation,\"\(timestamp)\",\"\(text)\",,\"\(originalText)\"\n"
        }
        
        return output
    }
    
    private func exportAsMarkdown() -> String {
        var output = "# Transcription Session\n\n"
        output += "**Session ID:** `\(id.uuidString)`  \n"
        output += "**Start Time:** \(startTime.formatted())  \n"
        if let endTime = endTime {
            output += "**End Time:** \(endTime.formatted())  \n"
        }
        output += "**Duration:** \(formattedDuration)  \n\n"
        
        if let contactName = metadata.contactName {
            output += "**Contact:** \(contactName)  \n"
        }
        if let topic = metadata.topic {
            output += "**Topic:** \(topic)  \n"
        }
        if !metadata.tags.isEmpty {
            output += "**Tags:** \(metadata.tags.joined(separator: ", "))  \n"
        }
        output += "\n"
        
        output += "## Japanese Transcriptions\n\n"
        for transcription in transcriptions {
            output += "**\(transcription.timestamp.formatted(date: .omitted, time: .standard))**  \n"
            output += "\(transcription.text)\n\n"
        }
        
        if !translations.isEmpty {
            output += "## English Translations\n\n"
            for translation in translations {
                output += "**\(translation.timestamp.formatted(date: .omitted, time: .standard))**  \n"
                output += "\(translation.text)  \n"
                output += "*Original:* \(translation.originalText)\n\n"
            }
        }
        
        return output
    }
}

// MARK: - Transcription Segment

struct TranscriptionSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let confidence: String
    let audioStart: Double
    let audioEnd: Double
    
    init(text: String, timestamp: Date, confidence: String = "", audioStart: Double = 0, audioEnd: Double = 0) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.confidence = confidence
        self.audioStart = audioStart
        self.audioEnd = audioEnd
    }
}

// MARK: - Translation Segment

struct TranslationSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let originalText: String
    let sourceLanguage: String
    
    init(text: String, timestamp: Date, originalText: String, sourceLanguage: String = "ja") {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.originalText = originalText
        self.sourceLanguage = sourceLanguage
    }
}

// MARK: - Session Metadata

struct SessionMetadata: Codable {
    var contactName: String?
    var topic: String?
    var notes: String?
    var tags: [String]
    var language: String
    var audioSource: String?
    
    init() {
        self.contactName = nil
        self.topic = nil
        self.notes = nil
        self.tags = []
        self.language = "ja"
        self.audioSource = nil
    }
}

// MARK: - Settings

struct TranscriptionSettings: Codable {
    var modelSize: String
    var confidenceThreshold: Float
    var chunkDuration: TimeInterval
    var enableTranslation: Bool
    var autoSave: Bool
    var saveInterval: TimeInterval
    var targetLanguage: String
    var sourceLanguage: String
    
    static let `default` = TranscriptionSettings(
        modelSize: "ggml-medium.bin",
        confidenceThreshold: 0.5,
        chunkDuration: 3.0,
        enableTranslation: false,
        autoSave: true,
        saveInterval: 300.0, // 5 minutes
        targetLanguage: "en",
        sourceLanguage: "ja"
    )
}

// MARK: - Search and Export

struct SearchCriteria {
    var query: String
    var dateRange: ClosedRange<Date>?
    var tags: [String]
    var minConfidence: Float?
    var hasTranslation: Bool?
    
    init() {
        self.query = ""
        self.dateRange = nil
        self.tags = []
        self.minConfidence = nil
        self.hasTranslation = nil
    }
}

enum ExportFormat: String, CaseIterable {
    case text = "txt"
    case json = "json"
    case csv = "csv"
    case markdown = "md"
    
    var displayName: String {
        switch self {
        case .text:
            return "Plain Text"
        case .json:
            return "JSON"
        case .csv:
            return "CSV"
        case .markdown:
            return "Markdown"
        }
    }
}
