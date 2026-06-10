import Foundation

@MainActor
class ModelManager: ObservableObject {
    static let shared = ModelManager()
    
    @Published var status: String = "Checking model status..."
    @Published var isDownloading: Bool = false
    
    private let appGroupName = "group.com.openmoss.mosstts"
    private let modelName = "MOSS-TTS-Nano-100M"
    
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
        
        status = "Model not found. Please download the MOSS-TTS-Nano-100M model from Hugging Face and place it in the App Group container."
        // In a real app, you would implement URLSession download logic here.
        // For now, users can manually place the model in the shared container via iTunes File Sharing or a download manager.
    }
}