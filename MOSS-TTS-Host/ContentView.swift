import SwiftUI

struct ContentView: View {
    @State private var modelStatus: String = "Checking model status..."
    @State private var isDownloading: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("MOSS-TTS iOS Engine")
                .font(.largeTitle)
                .bold()

            Text(modelStatus)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()

            if isDownloading {
                ProgressView("Downloading MOSS-TTS-Nano...")
                    .padding()
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