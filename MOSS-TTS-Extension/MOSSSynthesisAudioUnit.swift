import Foundation
import AVFoundation
import MLX
import MLXAudio

@objc(MOSSSynthesisAudioUnit)
public class MOSSSynthesisAudioUnit: AVSpeechSynthesisProviderAudioUnit {
    
    private var model: MLXAudio.TTSModel?
    private let modelQueue = DispatchQueue(label: "com.openmoss.mosstts.modelQueue", qos: .userInitiated)
    private let appGroupName = "group.com.openmoss.mosstts"
    
    // 1. Advertise Available Voices to iOS (English and Cantonese)
    public override var speechVoices: [AVSpeechSynthesisProviderVoice] {
        return [
            AVSpeechSynthesisProviderVoice(
                name: "MOSS English",
                identifier: "com.openmoss.mosstts.voice.en",
                primaryLanguages: ["en-US"],
                supportedLanguages: ["en-US", "en-GB"]
            ),
            AVSpeechSynthesisProviderVoice(
                name: "MOSS Cantonese",
                identifier: "com.openmoss.mosstts.voice.yue",
                primaryLanguages: ["yue-CN"],
                supportedLanguages: ["yue-CN", "zh-HK"]
            )
        ]
    }
    
    // 2. Initialize the MLX Model from the Shared App Group
    public override func initialize() {
        super.initialize()
        
        modelQueue.async {
            do {
                guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupName) else {
                    print("❌ App Group not configured")
                    return
                }
                
                let modelPath = containerURL.appendingPathComponent("MOSS-TTS-Nano-100M").path
                
                // Load the quantized Nano model optimized for extension memory limits
                self.model = try MLXAudio.loadTTSModel(modelPath)
                print("✅ MOSS-TTS Nano model loaded successfully")
            } catch {
                print("❌ Failed to load MOSS-TTS model: \(error)")
            }
        }
    }
    
    // 3. Synthesize Speech from SSML
    public override func synthesizeSpeech(for request: AVSpeechSynthesisProviderRequest) {
        let ssml = request.ssmlRepresentation
        let voiceIdentifier = request.voiceIdentifier
        
        // Determine language based on the requested voice identifier
        let isCantonese = voiceIdentifier == "com.openmoss.mosstts.voice.yue"
        let languageCode = isCantonese ? "yue" : "en"
        
        // Extract plain text from SSML
        let text = extractPlainText(from: ssml)
        
        modelQueue.async {
            guard let model = self.model else {
                request.outputBlock(nil, true) // Signal error/done
                return
            }
            
            do {
                // Generate audio using MLX-Audio
                let result = try model.generate(
                    text: text,
                    language: languageCode
                )
                
                // Convert MLXArray to AVAudioPCMBuffer
                let audioBuffer = self.convertMLXArrayToPCMBuffer(result.audio)
                
                // Return the buffer to the system. 'true' indicates this is the final chunk.
                request.outputBlock(audioBuffer, true)
                
            } catch {
                print("❌ Synthesis failed: \(error)")
                request.outputBlock(nil, true)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func extractPlainText(from ssml: String) -> String {
        // Basic regex to strip SSML tags like <speak>, <voice>, <break/>
        // In production, use XMLParser for robust SSML handling
        return ssml.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                   .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func convertMLXArrayToPCMBuffer(_ array: MLXArray) -> AVAudioPCMBuffer? {
        // MOSS-TTS-Nano outputs 24kHz, 1-channel, Float32 PCM
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24000, channels: 1, interleaved: false)!
        let frameCount = AVAudioFrameCount(array.size)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        
        // Copy data from MLXArray to the buffer's floatChannelData
        // Note: Adjust based on the exact MLX Swift API version for data extraction
        let data = array.data()
        data.withUnsafeBytes { rawBuffer in
            guard let source = rawBuffer.baseAddress?.assumingMemoryBound(to: Float.self) else { return }
            guard let destination = buffer.floatChannelData?[0] else { return }
            destination.assign(from: source, count: Int(frameCount))
        }
        
        return buffer
    }
}