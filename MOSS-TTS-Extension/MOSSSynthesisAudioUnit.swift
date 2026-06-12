import Foundation
import AVFoundation
import MLX
import MLXAudioTTS

@objc(MOSSSynthesisAudioUnit)
public class MOSSSynthesisAudioUnit: AVSpeechSynthesisProviderAudioUnit {

    private var model: (any SpeechGenerationModel)?
    private let appGroupName = "group.com.openmoss.mosstts"
    private let modelName = "MOSS-TTS-Nano-100M"
    private let modelRepo = "mlx-community/MOSS-TTS-Nano-100M"

    // Audio generation state
    private var audioBuffer: AVAudioPCMBuffer?
    private var framePosition: AVAudioFramePosition = 0

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
                    primaryLanguages: ["yue-Hant-HK"],
                    supportedLanguages: ["yue-Hant-HK", "zh-Hant-HK"]
                )
            ]
        }
        set { }
    }

    private func resolveModelPath() async throws -> String {
        // 1. Try App Group container (shared with host app)
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) {
            let modelDir = appGroupURL.appendingPathComponent(modelName)
            if FileManager.default.fileExists(atPath: modelDir.path) {
                print("Using model from App Group container")
                return modelDir.path
            }
        }

        // 2. Try extension's own container
        let extContainer = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let modelDir = extContainer.appendingPathComponent(modelName)
        if FileManager.default.fileExists(atPath: modelDir.path) {
            print("Using model from extension container")
            return modelDir.path
        }

        // 3. Download model into extension's container
        print("Model not found, downloading to extension container...")
        try await downloadModel(to: modelDir)
        return modelDir.path
    }

    private func downloadModel(to directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let apiURL = URL(string: "https://huggingface.co/api/models/\(modelRepo)/tree/main")!
        let session = URLSession.shared
        let (data, _) = try await session.data(from: apiURL)
        let files = try JSONDecoder().decode([HFApiItem].self, from: data).filter { $0.type == "file" }

        for file in files {
            let fileURL = URL(string: "https://huggingface.co/\(modelRepo)/resolve/main/\(file.path)")!
            let dest = directory.appendingPathComponent(file.path)
            guard !FileManager.default.fileExists(atPath: dest.path) else { continue }
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            let (temp, response) = try await session.download(from: fileURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
            try FileManager.default.moveItem(at: temp, to: dest)
        }
    }

    // 2. Called by the system to begin speech synthesis
    public override func synthesizeSpeechRequest(_ request: AVSpeechSynthesisProviderRequest) {
        let ssml = request.ssmlRepresentation
        let voiceIdentifier = request.voice.identifier

        let isCantonese = voiceIdentifier == "com.openmoss.mosstts.voice.yue"
        let languageCode = isCantonese ? "yue" : "en"

        let text = ssml.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                       .trimmingCharacters(in: .whitespacesAndNewlines)

        print("synthesizeSpeechRequest: \(text) (Language: \(languageCode))")

        framePosition = 0
        audioBuffer = nil

        Task {
            do {
                if self.model == nil {
                    let modelPath = try await self.resolveModelPath()
                    self.model = try await TTS.loadModel(modelRepo: modelPath)
                }

                guard let model = self.model else { return }

                let audio = try await model.generate(
                    text: text,
                    voice: nil,
                    refAudio: nil,
                    refText: nil,
                    language: languageCode
                )

                let samples = audio.asArray(Float.self)
                let format = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: Double(model.sampleRate),
                    channels: 1,
                    interleaved: false
                )!
                let frameCount = AVAudioFrameCount(samples.count)

                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
                buffer.frameLength = frameCount

                if let destination = buffer.floatChannelData?[0] {
                    destination.assign(from: samples, count: samples.count)
                }

                self.audioBuffer = buffer
                self.framePosition = 0

            } catch {
                print("❌ Synthesis failed: \(error)")
            }
        }
    }

    // 3. Called by the system to cancel
    public override func cancelSpeechRequest() {
        audioBuffer = nil
        framePosition = 0
    }

    // 4. Provide audio data to the system render pipeline
    public override var internalRenderBlock: AUInternalRenderBlock {
        return { [weak self] actionFlags, timestamp, frameCount, busNumber, audioBufferList, events, pullInputBlock in
            guard let self = self else {
                return noErr
            }

            _ = actionFlags
            _ = timestamp
            _ = events
            _ = pullInputBlock

            let unsafeBuffer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard busNumber < unsafeBuffer.count else { return noErr }

            guard let dst = unsafeBuffer[busNumber].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            guard let src = self.audioBuffer?.floatChannelData?[0] else {
                return noErr
            }

            let totalFrames = Int(self.audioBuffer?.frameLength ?? 0)
            let currentFrame = Int(self.framePosition)
            let framesToCopy = min(Int(frameCount), max(0, totalFrames - currentFrame))

            if framesToCopy > 0 {
                memcpy(dst, src + currentFrame, framesToCopy * MemoryLayout<Float>.size)
                self.framePosition += AVAudioFramePosition(framesToCopy)
            }

            return noErr
        }
    }
}

private struct HFApiItem: Decodable {
    let path: String
    let type: String
}
