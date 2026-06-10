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
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) else {
            status = "Error: App Group not configured."
            return
        }
        
        let modelDirectory = containerURL.appendingPathComponent(modelName)
        
        if FileManager.default.fileExists(atPath: modelDirectory.path) {
            status = "MOSS-TTS-Nano model is ready."
            return
        }
        
        await downloadModel(to: modelDirectory)
    }
    
    private func downloadModel(to directory: URL) async {
        isDownloading = true
        status = "Preparing to download MOSS-TTS-Nano from Hugging Face..."
        
        do {
            // Create temporary directory for download
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Hugging Face API to list files in the repo
            let apiURL = URL(string: "https://huggingface.co/api/models/\(modelRepo)/tree/main")!
            var request = URLRequest(url: apiURL)
            request.httpMethod = "GET"
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let files = try JSONDecoder().decode([HFFile].self, from: data)
            
            status = "Downloading \(files.count) model files..."
            
            for (index, file) in files.enumerated() {
                let fileURL = URL(string: "https://huggingface.co/\(modelRepo)/resolve/main/\(file.path)")!
                let destinationURL = directory.appendingPathComponent(file.path)
                
                // Create subdirectories if needed
                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                
                status = "Downloading \(file.path) (\(index + 1)/\(files.count))"
                try await downloadFile(from: fileURL, to: destinationURL)
                
                downloadProgress = Double(index + 1) / Double(files.count)
            }
            
            try FileManager.default.removeItem(at: tempDir)
            isDownloading = false
            downloadProgress = 1.0
            status = "MOSS-TTS-Nano model downloaded and ready!"
            
        } catch {
            isDownloading = false
            status = "Download failed: \(error.localizedDescription)"
            print("Download error: \(error)")
        }
    }
    
    private func downloadFile(from url: URL, to destination: URL) async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Download", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }
}

struct HFFile: Decodable {
    let path: String
    let type: String
}