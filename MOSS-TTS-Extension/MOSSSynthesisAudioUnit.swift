import Foundation
import AVFoundation
import MLX
import MLXAudioTTS

@objc(MOSSSynthesisAudioUnit)
public class MOSSSynthesisAudioUnit: AVSpeechSynthesisProviderAudioUnit {
    
    private var model: (any SpeechGenerationModel)?
    private let modelQueue = DispatchQueue(label: "com.openmoss.mosstts.modelQueue", qos: .userInitiated)
    private let appGroupName = "group.com.openmoss.mosstts"
    
    // 1. Advertise Available Voices to iOS (English and Cantonese)
    public override var speechVoices: [AVSpeechSynthesisProviderVoice] {
        get {
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
        set { }
    }
    
    // 2. Synthesize Speech from SSML
    @objc public func synthesizeSpeech(for request: AVSpeechSynthesisProviderRequest, outputBlock: @escaping (AVAudioPCMBuffer?, Bool) -> Void) {
        let ssml = request.ssmlRepresentation
        let voiceIdentifier = request.voice.identifier
        
        let isCantonese = voiceIdentifier == "com.openmoss.mosstts.voice.yue"
        let languageCode = isCantonese ? "yue" : "en"
        
        let text = ssml.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("Synthesizing: \(text) (Language: \(languageCode))")
        
        Task {
            do {
                // Load model if not already loaded
                if self.model == nil {
                    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupName) else {
                        throw NSError(domain: "MOSS-TTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "App Group not configured"])
                    }
                    let modelPath = containerURL.appendingPathComponent("MOSS-TTS-Nano-100M").path
                    self.model = try await TTS.loadModel(modelRepo: modelPath)
                }
                
                guard let model = self.model else {
                    outputBlock(nil, true)
                    return
                }
                
                // Generate audio using MLX-Audio (non-streaming, returns single MLXArray)
                let audio = try await model.generate(
                    text: text,
                    voice: nil,
                    refAudio: nil,
                    refText: nil,
                    language: languageCode
                )
                
                // Convert MLXArray to AVAudioPCMBuffer (sampleRate from model, 1-channel, Float32)
                let samples = audio.asArray(Float.self)
                let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(model.sampleRate), channels: 1, interleaved: false)!
                let frameCount = AVAudioFrameCount(samples.count)
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    outputBlock(nil, true)
                    return
                }
                buffer.frameLength = frameCount
                
                if let destination = buffer.floatChannelData?[0] {
                    destination.assign(from: samples, count: samples.count)
                }
                
                // Return the buffer to the system. 'true' indicates this is the final chunk.
                outputBlock(buffer, true)
                
            } catch {
                print("❌ Synthesis failed: \(error)")
                outputBlock(nil, true)
            }
        }
    }
}