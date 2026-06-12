import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var modelManager = ModelManager.shared
    @State private var showVoiceList = false
 @State private var debugLines: [String] = []

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
                        if let url = URL(string: "App-prefs:ACCESSIBILITY") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Accessibility Settings", systemImage: "gear")
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

                // Debug diagnostics
                if !debugLines.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Diagnostics")
                                .font(.headline)
                            Spacer()
                            Button {
                                let text = debugLines.joined(separator: "\n")
                                UIPasteboard.general.string = text
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                        }
                        ForEach(debugLines, id: \.self) { line in
                            Text(line)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
        }
        .task {
            await modelManager.ensureModelIsDownloaded()
            debugLines = Self.collectDiagnostics()
        }
        .sheet(isPresented: $showVoiceList) {
            VoiceListView()
        }
    }

    private static func collectDiagnostics() -> [String] {
        var lines: [String] = []
        let bundle = Bundle.main

        // Bundle ID
        lines.append("Host bundle ID: \(bundle.bundleIdentifier ?? "nil")")

        // App Group container
        let appGroupID = "group.com.openmoss.mosstts"
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            lines.append("App Group: OK → \(container.lastPathComponent)")
        } else {
            lines.append("App Group: FAILED (not configured)")
        }

        // Check if extension is embedded in the app bundle
        let extensionBundleName = "MOSS-TTS-Extension.appex"
        if let extURL = bundle.url(forResource: extensionBundleName, withExtension: nil) {
            lines.append("Extension embedded: YES")

            // Read extension's Info.plist to verify audio component registration
            let extPlist = extURL.appendingPathComponent("Info.plist")
            if let plist = NSDictionary(contentsOf: extPlist) {
                let extID = plist["CFBundleIdentifier"] as? String ?? "nil"
                lines.append("Extension bundle ID: \(extID)")

                if let audioComponents = plist["AudioComponents"] as? [[String: Any]],
                   let first = audioComponents.first,
                   let desc = first["AudioComponentDescription"] as? [String: Any] {
                    let mfr = desc["componentManufacturer"] as? String ?? "?"
                    let sub = desc["componentSubType"] as? String ?? "?"
                    lines.append("AudioComponent: \(mfr)/\(sub)")
                } else {
                    lines.append("AudioComponent: NOT FOUND in extension plist")
                }

                if let ext = plist["NSExtension"] as? [String: Any],
                   let attrs = ext["NSExtensionAttributes"] as? [String: Any] {
                    let pointID = ext["NSExtensionPointIdentifier"] as? String ?? "?"
                    let compTypes = attrs["componentTypes"] as? [String] ?? []
                    lines.append("Extension point: \(pointID)")
                    lines.append("Component types: \(compTypes.joined(separator: ", "))")
                }
            } else {
                lines.append("Extension plist: UNREADABLE")
            }
        } else {
            lines.append("Extension embedded: NO (appex not found)")
        }

        // Model directory
        var modelFound = false
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let modelDir = container.appendingPathComponent("MOSS-TTS-Nano-100M")
            if FileManager.default.fileExists(atPath: modelDir.path) {
                if let files = try? FileManager.default.contentsOfDirectory(atPath: modelDir.path) {
                    lines.append("Model dir (App Group): \(files.count) files")
                } else {
                    lines.append("Model dir (App Group): exists")
                }
                modelFound = true
            }
        }
        if !modelFound {
            let localDocs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let modelDir = localDocs?.appendingPathComponent("MOSS-TTS-Nano-100M")
            if let dir = modelDir, FileManager.default.fileExists(atPath: dir.path) {
                if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                    lines.append("Model dir (local): \(files.count) files")
                }
                modelFound = true
            }
        }
        if !modelFound {
            lines.append("Model dir: NOT FOUND (extension will self-download)")
        }

        return lines
    }
}

#Preview {
    ContentView()
}
