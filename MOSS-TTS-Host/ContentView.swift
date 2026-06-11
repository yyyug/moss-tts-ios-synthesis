import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var modelManager = ModelManager.shared
    @State private var showVoiceList = false

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
                }

                // Voices button - always visible
                Button {
                    showVoiceList = true
                } label: {
                    Label("Voices", systemImage: "waveform.circle")
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                if modelManager.status.contains("ready") || modelManager.status.contains("ready!") {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open iOS Voice Settings", systemImage: "gear")
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding()
        }
        .task {
            await modelManager.ensureModelIsDownloaded()
        }
        .sheet(isPresented: $showVoiceList) {
            VoiceListView()
        }
    }
}

#Preview {
    ContentView()
}
