import SwiftUI

@main
struct NihongoTranscriberApp: App {
    @StateObject private var transcriptionManager = TranscriptionManager()
    @StateObject private var audioCaptureManager = AudioCaptureManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(transcriptionManager)
                .environmentObject(audioCaptureManager)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // Request audio permissions when app starts
                    audioCaptureManager.requestPermissions()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView()
                .environmentObject(transcriptionManager)
                .environmentObject(audioCaptureManager)
        }
    }
} 