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
                    Text("Tap a voice to download. Once downloaded, use the delete button to remove it.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section {
                    ForEach(voices) { voice in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(voice.name)
                                    .font(.headline)
                                Text(voice.language)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if isModelReady {
                                Button(role: .destructive) {
                                    Task {
                                        await modelManager.deleteModel()
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            } else if modelManager.isDownloading {
                                ProgressView()
                            } else {
                                Button {
                                    Task {
                                        await modelManager.ensureModelIsDownloaded()
                                    }
                                } label: {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Available Voices")
                }

                if modelManager.isDownloading {
                    Section {
                        ProgressView(value: modelManager.downloadProgress) {
                            Text("Downloading model...")
                        }
                        Text("\(Int(modelManager.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
