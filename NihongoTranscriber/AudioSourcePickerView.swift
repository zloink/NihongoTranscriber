import SwiftUI

struct AudioSourcePickerView: View {
    @Binding var selectedSource: AudioSource
    let audioCaptureManager: AudioCaptureManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Select Audio Source")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Audio source options
            VStack(alignment: .leading, spacing: 16) {
                ForEach(AudioSource.allCases, id: \.self) { source in
                    AudioSourceOption(
                        source: source,
                        isSelected: selectedSource == source,
                        isAvailable: isSourceAvailable(source),
                        onSelect: {
                            selectedSource = source
                        }
                    )
                }
            }
            .padding()
            
            Spacer()
            
            // Permission info
            permissionInfoView
                .padding()
        }
        .frame(width: 500, height: 400)
    }
    
    private func isSourceAvailable(_ source: AudioSource) -> Bool {
        let permissions = audioCaptureManager.checkPermissions()
        
        switch source {
        case .microphone:
            return permissions.microphone
        case .systemAudio:
            return permissions.microphone && permissions.screenRecording
        case .allAudio:
            return permissions.microphone && permissions.screenRecording
        case .applicationSpecific:
            return permissions.microphone && permissions.screenRecording
        }
    }
    
    private var permissionInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions Status")
                .font(.headline)
            
            let permissions = audioCaptureManager.checkPermissions()
            
            HStack {
                Image(systemName: permissions.microphone ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(permissions.microphone ? .green : .red)
                Text("Microphone Access")
                Spacer()
                if !permissions.microphone {
                    Button("Grant") {
                        audioCaptureManager.requestPermissions()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            HStack {
                Image(systemName: permissions.screenRecording ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(permissions.screenRecording ? .green : .red)
                Text("Screen Recording (for system audio)")
                Spacer()
                if !permissions.screenRecording {
                    Button("Grant") {
                        audioCaptureManager.requestPermissions()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct AudioSourceOption: View {
    let source: AudioSource
    let isSelected: Bool
    let isAvailable: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            if isAvailable {
                onSelect()
            }
        }) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: source.iconName)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 30)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.displayName)
                        .font(.headline)
                        .foregroundColor(isAvailable ? .primary : .secondary)
                    
                    Text(source.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Status indicator
                if !isAvailable {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(backgroundColorForOption)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColorForOption, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1.0 : 0.6)
    }
    
    private var iconColor: Color {
        if !isAvailable {
            return .orange
        } else if isSelected {
            return .green
        } else {
            return .accentColor
        }
    }
    
    private var backgroundColorForOption: Color {
        if isSelected {
            return Color.accentColor.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var borderColorForOption: Color {
        if isSelected {
            return .accentColor
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

enum AudioSource: String, CaseIterable {
    case microphone = "microphone"
    case systemAudio = "system_audio"
    case allAudio = "all_audio"
    case applicationSpecific = "app_specific"
    
    var displayName: String {
        switch self {
        case .microphone:
            return "Microphone"
        case .systemAudio:
            return "System Audio"
        case .allAudio:
            return "All Audio"
        case .applicationSpecific:
            return "Application Audio"
        }
    }
    
    var description: String {
        switch self {
        case .microphone:
            return "Capture audio from your microphone input"
        case .systemAudio:
            return "Capture system audio output (WhatsApp, FaceTime, etc.)"
        case .allAudio:
            return "Capture all audio - both microphone and system audio"
        case .applicationSpecific:
            return "Target specific applications for audio capture"
        }
    }
    
    var iconName: String {
        switch self {
        case .microphone:
            return "mic.fill"
        case .systemAudio:
            return "speaker.wave.3.fill"
        case .allAudio:
            return "waveform"
        case .applicationSpecific:
            return "app.badge"
        }
    }
}

#Preview {
    AudioSourcePickerView(
        selectedSource: .constant(.systemAudio),
        audioCaptureManager: AudioCaptureManager()
    )
}
