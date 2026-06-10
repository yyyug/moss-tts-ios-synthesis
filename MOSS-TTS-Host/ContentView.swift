import SwiftUI

struct ContentView: View {
    @StateObject private var modelManager = ModelManager.shared

    var body: some View {
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
            }

            Text("Once installed, go to Settings > Accessibility > Spoken Content > Voices to enable the MOSS-TTS English and Cantonese voices.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding()
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}