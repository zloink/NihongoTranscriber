# Nihongo Transcriber

A native macOS application for real-time Japanese speech transcription using Whisper.cpp. Perfect for language learners who want to capture and review conversations in Japanese.

## Features

### 🎯 **Real-time Transcription**
- **Near real-time processing** with 3-second audio chunks
- **Japanese language optimization** using Whisper models
- **High-quality audio capture** from system audio, applications, or microphone

### 🌐 **Smart Translation**
- **Side-by-side display** of Japanese transcription and English translation
- **Toggle translation on/off** to focus on Japanese learning
- **Automatic language detection** and processing

### 🎵 **Flexible Audio Capture**
- **System Audio**: Capture WhatsApp, FaceTime, and other app audio
- **Application-specific**: Target specific applications for audio capture
- **Microphone input**: Record your own voice when needed
- **All audio sources**: Comprehensive capture option

### 💾 **Session Management**
- **Automatic saving** with configurable intervals
- **Session metadata**: Add contact names, topics, and tags
- **Search and filter** through saved transcriptions
- **Export options**: Text, JSON, CSV, and Markdown formats

### ⚙️ **Customizable Settings**
- **Model selection**: Choose between small, medium, and large Whisper models
- **Quality tuning**: Adjust confidence thresholds and processing parameters
- **Audio optimization**: Configure chunk sizes and capture settings

## System Requirements

- **macOS 14.0** or later
- **M1/M2 Mac** recommended for optimal performance
- **8GB RAM** minimum (16GB recommended)
- **Whisper.cpp** installation with models

## Prerequisites

### 1. Install Whisper.cpp

The application requires a working Whisper.cpp installation. You can either:

**Option A: Use existing installation**
If you already have Whisper.cpp installed (like in the parent directory), the app will automatically detect it.

**Option B: Install Whisper.cpp**
```bash
# Clone the repository
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp

# Build the project
make

# Download models (recommended: medium or large for Japanese)
./models/download-ggml-model.sh medium
# or
./models/download-ggml-model.sh large
```

### 2. Required Models

The application works best with these Whisper models:
- **ggml-medium.bin** (1.5GB) - Recommended balance of speed and accuracy
- **ggml-large.bin** (3.1GB) - Best accuracy, slower processing
- **ggml-small.bin** (500MB) - Fastest, lower accuracy

## Building the Application

### 1. Open in Xcode

```bash
# Open the project
open NihongoTranscriber.xcodeproj
```

### 2. Configure Paths

The application automatically looks for Whisper.cpp in the parent directory. If your installation is elsewhere, update these paths in `WhisperWrapper.swift`:

```swift
private let whisperCLIPath: String = "/path/to/whisper.cpp/build/bin/whisper-cli"
private let modelsDirectory: String = "/path/to/whisper.cpp/models"
```

### 3. Build and Run

1. Select your target device (Mac)
2. Press `Cmd+R` to build and run
3. Grant microphone permissions when prompted

## Usage Guide

### Getting Started

1. **Launch the app** - It will appear in your dock
2. **Grant permissions** - Allow microphone access when prompted
3. **Select audio source** - Choose where to capture audio from
4. **Start recording** - Click the record button to begin transcription

### During a Call

1. **Start your call** (WhatsApp, FaceTime, etc.)
2. **Launch Nihongo Transcriber**
3. **Click "Start Recording"**
4. **Watch real-time transcription** appear in Japanese
5. **Toggle translation** if you want English alongside

### Managing Sessions

- **Auto-save**: Sessions are automatically saved every 5 minutes
- **Manual save**: Click "Save Session" to save immediately
- **Pause/Resume**: Use pause button during breaks in conversation
- **Stop recording**: Click stop when the call ends

### Reviewing Later

1. **Open Settings** (Cmd+,)
2. **Go to Sessions tab**
3. **Search and filter** your saved transcriptions
4. **Export** in your preferred format
5. **Add metadata** like contact names and topics

## Configuration

### Audio Settings

- **Chunk Duration**: 1-10 seconds (3 seconds recommended)
- **Sample Rate**: 16kHz (optimized for Whisper)
- **Channels**: Mono for best transcription quality

### Transcription Settings

- **Model Size**: Choose based on accuracy vs. speed preference
- **Confidence Threshold**: Filter out low-quality transcriptions
- **Auto-translation**: Enable/disable automatic English translation

### Auto-save Settings

- **Enable auto-save**: Automatically save progress during long sessions
- **Save interval**: Configure how often to save (1-30 minutes)

## Troubleshooting

### Common Issues

**"Whisper CLI not found"**
- Verify Whisper.cpp is built and `whisper-cli` exists
- Check paths in `WhisperWrapper.swift`
- Ensure the executable has proper permissions

**"No audio detected"**
- Check microphone permissions in System Preferences
- Verify audio source selection
- Ensure audio is actually playing in the selected source

**"Transcription quality is poor"**
- Try a larger Whisper model (medium or large)
- Reduce background noise
- Speak more clearly and slowly
- Adjust confidence threshold in settings

**"App is slow or unresponsive"**
- Use a smaller Whisper model
- Increase chunk duration
- Close other resource-intensive applications
- Ensure adequate RAM (16GB+ recommended)

### Performance Tips

1. **Use M2 Mac** for best performance
2. **Choose appropriate model size** for your needs
3. **Optimize chunk duration** (3 seconds is usually optimal)
4. **Close unnecessary applications** during transcription
5. **Use SSD storage** for faster model loading

## Development

### Project Structure

```
NihongoTranscriber/
├── NihongoTranscriberApp.swift      # Main app entry point
├── ContentView.swift                # Main UI interface
├── AudioCaptureManager.swift        # Core Audio integration
├── TranscriptionManager.swift       # Session and workflow management
├── WhisperWrapper.swift             # Whisper.cpp integration
├── TranscriptionSession.swift       # Data models
├── AudioSourcePickerView.swift      # Audio source selection
├── SettingsView.swift               # Configuration interface
└── Assets.xcassets/                 # App icons and resources
```

### Key Components

- **AudioCaptureManager**: Handles Core Audio integration and system audio capture
- **WhisperWrapper**: Interfaces with Whisper.cpp for transcription and translation
- **TranscriptionManager**: Coordinates the entire transcription workflow
- **SwiftUI Views**: Modern, responsive user interface

### Extending the App

The application is designed to be easily extensible:

- **Add new audio sources** by extending `AudioSourceType`
- **Support new export formats** by adding to `ExportFormat`
- **Customize transcription settings** in `TranscriptionSettings`
- **Add new Whisper models** by updating the models directory

## License

This project is open source. Feel free to modify and distribute according to your needs.

## Contributing

Contributions are welcome! Areas that could use improvement:

- **Better system audio capture** using Core Audio APIs
- **Real-time speaker identification**
- **Cloud transcription options**
- **Advanced search and filtering**
- **Integration with note-taking apps**

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Verify your Whisper.cpp installation
3. Check system permissions and audio settings
4. Review the console logs for error messages

---

**Happy Japanese Learning! 🇯🇵**

This tool should make your language learning journey much more effective by giving you written reference for spoken conversations. 