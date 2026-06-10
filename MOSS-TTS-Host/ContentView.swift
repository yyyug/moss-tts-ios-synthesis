import SwiftUI
import AVFoundation
import UIKit

struct ContentView: View {
    @StateObject private var modelManager = ModelManager.shared
    @State private var extensionStatus: String = "Checking extension registration..."

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "waveform")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("MOSS-TTS iOS Engine")
                    .font(.largeTitle)
                    .bold()

                Text(extensionStatus)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                Text(modelManager.status)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                if modelManager.isDownloading {
                    ProgressView(value: modelManager.downloadProgress) {
                        Text("Downloading MOSS-TTS-Nano...")
                    }
                    .padding()

                    Text("\(Int(modelManager.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else if !extensionStatus.contains("✅") {
                    Button {
                        let url = URL(string: "App-Prefs:root=ACCESSIBILITY&path=Spoken%20Content/VOICES") ?? URL(string: UIApplication.openSettingsURLString)!
                        UIApplication.shared.open(url)
                    } label: {
                        Label("Open Accessibility → Spoken Content → Voices", systemImage: "arrow.up.forward.app")
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Text("Look for \"MOSS English\" and \"MOSS Cantonese\" in the voice list.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                Text("Once the extension is registered, go to Settings > Accessibility > Spoken Content > Voices to enable the MOSS-TTS voices.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .task {
            await checkExtensionRegistration()
            await modelManager.ensureModelIsDownloaded()
        }
    }

    private func checkExtensionRegistration() async {
        let expectedIDs = Set([
            "com.openmoss.mosstts.voice.en",
            "com.openmoss.mosstts.voice.yue"
        ])

        for _ in 0..<10 {
            let voices = AVSpeechSynthesisVoice.speechVoices()
            let foundIDs = Set(voices.map { $0.identifier })
            let missing = expectedIDs.subtracting(foundIDs)

            if missing.isEmpty {
                extensionStatus = "✅ Extension registered — \(voices.count) voices available"
                return
            }

            extensionStatus = "⏳ Waiting for extension registration... (\(foundIDs.count) voices found, \(missing.count) missing)"
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        extensionStatus = "⚠️ Extension not yet detected. Try rebooting the device or opening Settings > Accessibility > Spoken Content > Voices."
    }
}

#Preview {
    ContentView()
}