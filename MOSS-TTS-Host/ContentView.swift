import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var modelManager = ModelManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "waveform")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("MOSS-TTS iOS Engine")
                    .font(.largeTitle)
                    .bold()

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
                } else if modelManager.status.contains("ready") || modelManager.status.contains("ready!") {
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

                Spacer()
            }
            .padding()
        }
        .task {
            await modelManager.ensureModelIsDownloaded()
        }
    }
}

#Preview {
    ContentView()
}
