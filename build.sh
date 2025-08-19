#!/bin/bash

# Nihongo Transcriber Build Script
# This script helps build and run the macOS transcription application

echo "🎯 Nihongo Transcriber Build Script"
echo "=================================="

# Check if we're in the right directory
if [ ! -f "NihongoTranscriber.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the NihongoTranscriber directory"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode is not installed or not in PATH"
    echo "Please install Xcode from the Mac App Store"
    exit 1
fi

# Check if Whisper.cpp exists
if [ ! -d "../whisper.cpp" ]; then
    echo "⚠️  Warning: Whisper.cpp not found in parent directory"
    echo "The app will need to be configured with correct paths"
    echo ""
    echo "To install Whisper.cpp:"
    echo "cd .."
    echo "git clone https://github.com/ggerganov/whisper.cpp.git"
    echo "cd whisper.cpp"
    echo "make"
    echo "cd ../NihongoTranscriber"
    echo ""
fi

# Check if whisper-cli exists
if [ -f "../whisper.cpp/build/bin/whisper-cli" ]; then
    echo "✅ Whisper.cpp found and built"
    echo "   CLI: ../whisper.cpp/build/bin/whisper-cli"
else
    echo "⚠️  Warning: whisper-cli not found"
    echo "   Expected: ../whisper.cpp/build/bin/whisper-cli"
    echo "   Please build Whisper.cpp first"
    echo ""
fi

# Check for models
if [ -d "../whisper.cpp/models" ]; then
    echo "📁 Models directory found"
    echo "   Available models:"
    for model in ../whisper.cpp/models/*.bin; do
        if [ -f "$model" ]; then
            size=$(du -h "$model" | cut -f1)
            echo "   - $(basename "$model") ($size)"
        fi
    done
else
    echo "⚠️  Warning: Models directory not found"
    echo "   Expected: ../whisper.cpp/models"
    echo "   Please download models first"
    echo ""
fi

echo ""
echo "🚀 Building Nihongo Transcriber..."

# Build the project
xcodebuild -project NihongoTranscriber.xcodeproj \
           -scheme NihongoTranscriber \
           -configuration Debug \
           -derivedDataPath build \
           build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "🎉 Ready to run!"
    echo ""
    echo "Next steps:"
    echo "1. Open NihongoTranscriber.xcodeproj in Xcode"
    echo "2. Press Cmd+R to build and run"
    echo "3. Grant microphone permissions when prompted"
    echo ""
    echo "Or run directly:"
    echo "open build/Build/Products/Debug/NihongoTranscriber.app"
else
    echo "❌ Build failed!"
    echo "Please check the error messages above"
    exit 1
fi 