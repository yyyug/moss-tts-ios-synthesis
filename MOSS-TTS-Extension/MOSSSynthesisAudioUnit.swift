import Foundation
import AVFoundation

@objc(MOSSSynthesisAudioUnit)
public class MOSSSynthesisAudioUnit: AVSpeechSynthesisProviderAudioUnit {
    
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
    
    // 2. Initialize the Engine
    public override func initialize() {
        super.initialize()
        print("✅ MOSS-TTS Extension initialized")
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
        print("Synthesizing: \(text) (Language: \(languageCode))")
        
        modelQueue.async {
            // TODO: Integrate MLXAudio here when building locally with Xcode 16.5+ (Swift 6.2)
            // For now, return a valid silent buffer to satisfy the system and allow successful IPA build
            
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24000, channels: 1, interleaved: false)!
            let frameCount: AVAudioFrameCount = 24000 // 1 second of silent audio
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                request.outputBlock(nil, true)
                return
            }
            buffer.frameLength = frameCount
            
            // Fill with silence (0.0)
            if let channelData = buffer.floatChannelData?[0] {
                channelData.initialize(repeating: 0.0, count: Int(frameCount))
            }
            
            // Return the buffer to the system. 'true' indicates this is the final chunk.
            request.outputBlock(buffer, true)
        }
    }
    
    // MARK: - Helpers
    
    private func extractPlainText(from ssml: String) -> String {
        // Basic regex to strip SSML tags like <speak>, <voice>, <break/>
        // In production, use XMLParser for robust SSML handling
        return ssml.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                   .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}