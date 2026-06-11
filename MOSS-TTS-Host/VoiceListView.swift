import SwiftUI

struct VoiceInfo: Identifiable {
    let id = UUID()
    let name: String
    let language: String
    let identifier: String
}

struct VoiceListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var modelManager = ModelManager.shared
    
    let voices: [VoiceInfo] = [
        VoiceInfo(name: "MOSS English", language: "English (US)", identifier: "com.openmoss.mosstts.voice.en"),
        VoiceInfo(name: "MOSS Cantonese", language: "Cantonese (Hong Kong)", identifier: "com.openmoss.mosstts.voice.yue")
    ]
    
    var isModelReady: Bool {
        modelManager.status.contains("ready")
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: isModelReady ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isModelReady ? .green : .red)
                        Text("Model Status")
                        Spacer()
                        Text(isModelReady ? "Downloaded" : "Not Available")
                            .foregroundColor(.secondary)
                    }
                    
                    if !isModelReady && modelManager.isDownloading {
                        ProgressView(value: modelManager.downloadProgress) {
                            Text("Downloading...")
                        }
                        Text("\(Int(modelManager.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Model")
                }
                
                Section {
                    ForEach(voices) { voice in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(voice.name)
                                        .font(.headline)
                                    Text(voice.language)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isModelReady {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Text("Identifier: \(voice.identifier)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Available Voices")
                }
                
                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open iOS Voice Settings", systemImage: "gear")
                    }
                    
                    Text("To enable these voices: Settings → Accessibility → Spoken Content → Voices → MOSS-TTS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Enable Voices")
                } footer: {
                    Text("Note: Voices must be enabled in iOS Settings after the extension is properly installed and signed.")
                }
                
                if isModelReady {
                    Section {
                        Button(role: .destructive) {
                            Task {
                                await modelManager.deleteModel()
                            }
                        } label: {
                            Label("Delete Model", systemImage: "trash")
                        }
                    } header: {
                        Text("Model Management")
                    } footer: {
                        Text("Deleting the model will require re-downloading before voices can be used.")
                    }
                }
            }
            .navigationTitle("Voices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    VoiceListView()
}
