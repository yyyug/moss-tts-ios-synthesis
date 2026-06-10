import Foundation

@MainActor
class ModelManager: ObservableObject {
    static let shared = ModelManager()
    
    @Published var status: String = "Checking model status..."
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    
    private let appGroupName = "group.com.openmoss.mosstts"
    private let modelName = "MOSS-TTS-Nano-100M"
    private let modelRepo = "mlx-community/MOSS-TTS-Nano-100M"
    
    func ensureModelIsDownloaded() async {
        status = "Checking model status..."
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) else {
            status = "❌ Error: App Group '\(appGroupName)' not configured. Enable App Groups in both targets with this identifier."
            return
        }
        
        status = "✅ App Group OK. Container: \(containerURL.path)"
        
        let modelDirectory = containerURL.appendingPathComponent(modelName)
        
        if FileManager.default.fileExists(atPath: modelDirectory.path) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: modelDirectory.path)
                status = "✅ MOSS-TTS model ready (\(contents.count) files in model directory)."
            } catch {
                status = "✅ MOSS-TTS model directory exists."
            }
            return
        }
        
        status = "⬇️ Model not found locally. Starting download from Hugging Face..."
        await downloadModel(to: modelDirectory)
    }
    
    private func downloadModel(to directory: URL) async {
        isDownloading = true
        status = "Fetching file list from Hugging Face API..."
        
        do {
            // Create temporary directory
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Hugging Face API to list files in the repo
            let apiURL = URL(string: "https://huggingface.co/api/models/\(modelRepo)/tree/main")!
            status = "API: \(apiURL.absoluteString)"
            
            let (data, response) = try await URLSession.shared.data(from: apiURL)
            guard let httpResponse = response as? HTTPURLResponse else {
                status = "❌ Download failed: Not an HTTP response"
                isDownloading = false
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                status = "❌ API returned HTTP \(httpResponse.statusCode). Check model repo name."
                isDownloading = false
                return
            }
            
            // Decode file list
            let allItems = try JSONDecoder().decode([HFApiItem].self, from: data)
            let files = allItems.filter { $0.type == "file" }
            
            guard !files.isEmpty else {
                status = "❌ No files found in repository. Check model repo."
                isDownloading = false
                return
            }
            
            status = "⬇️ Downloading \(files.count) model files..."
            
            for (index, file) in files.enumerated() {
                let fileURL = URL(string: "https://huggingface.co/\(modelRepo)/resolve/main/\(file.path)")!
                let destinationURL = directory.appendingPathComponent(file.path)
                
                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                
                status = "⬇️ [\(index + 1)/\(files.count)] \(file.path)"
                try await downloadFile(from: fileURL, to: destinationURL)
                
                downloadProgress = Double(index + 1) / Double(files.count)
            }
            
            try FileManager.default.removeItem(at: tempDir)
            isDownloading = false
            downloadProgress = 1.0
            status = "✅ MOSS-TTS-Nano model downloaded and ready!"
            
        } catch let error as DecodingError {
            isDownloading = false
            status = "❌ JSON decode error: \(error.localizedDescription). The API response format may have changed."
            print("Decoding error: \(error)")
        } catch {
            isDownloading = false
            status = "❌ Download failed: \(error.localizedDescription)"
            print("Download error: \(error)")
        }
    }
    
    private func downloadFile(from url: URL, to destination: URL) async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Download", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response for \(url.lastPathComponent)"])
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }
}

struct HFApiItem: Decodable {
    let path: String
    let type: String  // "file" or "directory"
}

struct HFFile: Decodable {
    let path: String
    let type: String
}
