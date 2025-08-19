import SwiftUI

struct AudioSourcePickerView: View {
    @Binding var selectedSource: AudioSource
    let audioCaptureManager: AudioCaptureManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Select Audio Source")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose where to capture audio from for transcription")
                    .foregroundColor(.secondary)
                
                LazyVStack(spacing: 12) {
                    ForEach(AudioSource.allCases, id: \.self) { source in
                        AudioSourceRow(
                            source: source,
                            isSelected: selectedSource == source,
                            onSelect: {
                                selectedSource = source
                                audioCaptureManager.selectAudioSource(AudioSourceInfo(
                                    id: source.rawValue,
                                    name: source.displayName,
                                    type: mapAudioSourceToType(source),
                                    description: source.description
                                ))
                                dismiss()
                            }
                        )
                    }
                }
                
                Spacer()
                
                // Additional info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note:")
                        .font(.headline)
                    
                    Text("• System Audio: Captures output from applications like WhatsApp, FaceTime, etc.")
                    Text("• Specific App: Select a particular application to capture audio from")
                    Text("• Microphone: Captures your voice input only")
                    Text("• All Audio: Captures from all available audio sources")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
            .frame(width: 500, height: 600)
            .navigationTitle("Audio Source")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func mapAudioSourceToType(_ source: AudioSource) -> AudioSourceType {
        switch source {
        case .systemAudio:
            return .systemOutput
        case .specificApp:
            return .specificApp
        case .microphone:
            return .microphone
        case .allAudio:
            return .allAudio
        }
    }
}

struct AudioSourceRow: View {
    let source: AudioSource
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: iconName)
                            .foregroundColor(isSelected ? .accentColor : .primary)
                            .frame(width: 24)
                        
                        Text(source.displayName)
                            .font(.headline)
                            .foregroundColor(isSelected ? .accentColor : .primary)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    Text(source.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
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
        switch source {
        case .systemAudio:
            return "speaker.wave.2"
        case .specificApp:
            return "app.badge"
        case .microphone:
            return "mic"
        case .allAudio:
            return "waveform.path.ecg"
        }
    }
}

#Preview {
    AudioSourcePickerView(
        selectedSource: .constant(.systemAudio),
        audioCaptureManager: AudioCaptureManager()
    )
} 