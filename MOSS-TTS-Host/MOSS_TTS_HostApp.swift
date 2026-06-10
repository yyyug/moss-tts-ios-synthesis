import SwiftUI

@main
struct MOSS_TTS_HostApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Task {
                        await ModelManager.shared.ensureModelIsDownloaded()
                    }
                }
        }
    }
}