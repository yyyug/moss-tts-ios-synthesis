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
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
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
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            let apiURL = URL(string: "https://huggingface.co/api/models/\(modelRepo)/tree/main")!
            status = "API: \(apiURL.absoluteString)"
            
            let (data, response) = try await session.data(from: apiURL)
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
            
            let allItems = try JSONDecoder().decode([HFApiItem].self, from: data)
            let files = allItems.filter { $0.type == "file" }
            
            guard !files.isEmpty else {
                status = "❌ No files found in repository. Check model repo."
                isDownloading = false
                return
            }
            
            let totalFiles = files.count
            var downloaded = 0
            var skipped = 0
            
            for (index, file) in files.enumerated() {
                let fileURL = URL(string: "https://huggingface.co/\(modelRepo)/resolve/main/\(file.path)")!
                let destinationURL = directory.appendingPathComponent(file.path)
                
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    skipped += 1
                    downloaded += 1
                    downloadProgress = Double(downloaded) / Double(totalFiles)
                    status = "⏭️ [\(index + 1)/\(totalFiles)] \(file.path) (cached)"
                    continue
                }
                
                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                
                status = "⬇️ [\(index + 1)/\(totalFiles)] \(file.path)"
                do {
                    try await downloadFile(from: fileURL, to: destinationURL)
                    downloaded += 1
                } catch {
                    status = "❌ Failed to download \(file.path): \(error.localizedDescription). Retrying in 2s..."
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    try await downloadFile(from: fileURL, to: destinationURL)
                    downloaded += 1
                    status = "✅ Retry succeeded: \(file.path)"
                }
                
                downloadProgress = Double(downloaded) / Double(totalFiles)
            }
            
            isDownloading = false
            downloadProgress = 1.0
            if skipped > 0 {
                status = "✅ Model ready! (\(downloaded) files, \(skipped) were cached)"
            } else {
                status = "✅ MOSS-TTS-Nano model downloaded and ready!"
            }
            
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
        let (tempURL, response) = try await session.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Download", code: -1, userInfo: [NSLocalizedDescriptionKey: "HTTP error for \(url.lastPathComponent)"])
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }
}

struct HFApiItem: Decodable {
    let path: String
    let type: String
}
