# MOSS-TTS iOS System Synthesis Provider

**iOS 17+ system-wide speech synthesis using MOSS-TTS-Nano via Apple's MLX framework.**

This project embeds a custom TTS engine directly into iOS via `AVSpeechSynthesisProviderAudioUnit`, making high-quality English and Cantonese voices available system-wide — in VoiceOver, Live Speech, third-party apps, and any feature that uses `AVSpeechSynthesizer`.

---

## Architecture

```
[ System / VoiceOver / App ]
           │ (SSML request)
           ▼
[MOSS-TTS-Extension (.appex)]
  ┌─────────────────────────────────┐
  │ AVSpeechSynthesisProviderAudio  │
  │         Unit                    │
  │  ┌─────────────────────────┐   │
  │  │ MLXAudioTTS              │   │
  │  │ (MOSS-TTS-Nano model)    │   │
  │  │ → TTS.loadModel()       │   │
  │  │ → model.generate()      │   │
  │  └─────────────────────────┘   │
  └─────────────────────────────────┘
           │ (AVAudioPCMBuffer)
           ▼
[ iOS Audio System → Speaker ]
```

Two components work together:

- **MOSS-TTS-Host** — Standard iOS app. Manages the shared App Group container (`group.com.openmoss.mosstts`). Downloads the MOSS-TTS-Nano model from Hugging Face and places it in the shared container so the extension can access it.

- **MOSS-TTS-Extension** — An `AVSpeechSynthesisProviderAudioUnit` app extension registered as a Voice Speech Provider (`vspr`). Receives SSML from the system, parses the text, runs inference with `MLXAudioTTS`, and returns `AVAudioPCMBuffer` to the iOS audio pipeline.

---

## Voices

| Voice | Identifier | Language |
|---|---|---|
| MOSS English | `com.openmoss.mosstts.voice.en` | `en-US`, `en-GB` |
| MOSS Cantonese | `com.openmoss.mosstts.voice.yue` | `yue-CN`, `zh-HK` |

---

## Requirements

- iOS 17.0+
- Apple Silicon device (iPhone 15 Pro+ / iPad with M-series chip) for on-device MLX inference
- Xcode 16.5+ (Swift 6.2 toolchain required by `mlx-audio-swift`)
- [Apple Developer Program](https://developer.apple.com/programs/) ($99/year) for code signing

---

## Setup & Build

### Prerequisites

```bash
brew install xcodegen
```

### Generate Xcode Project

```bash
xcodegen generate
```

This creates `MOSSTTS.xcodeproj` from `project.yml`.

### Signing Configuration

You must configure code signing with a valid Apple Developer team:

1. Open `MOSSTTS.xcodeproj` in Xcode
2. Select both targets → Signing & Capabilities → select your team
3. Enable **App Groups** capability on both targets with `group.com.openmoss.mosstts`
4. Ensure the Host App and Extension have matching App Group entitlements

### Build & Run

```bash
xcodebuild archive \
  -project MOSSTTS.xcodeproj \
  -scheme MOSS-TTS-Host \
  -archivePath build/MOSSTTS.xcarchive \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates
```

### Model Download

The Host App automatically downloads `MOSS-TTS-Nano-100M` from Hugging Face (`mlx-community/MOSS-TTS-Nano-100M`) to the shared App Group container on first launch.

---

## GitHub Actions (Unsigned IPA Build)

The workflow `.github/workflows/build-ipa.yml` builds an unsigned IPA on push to `main` or manual dispatch.

### What it does:
1. Selects **Xcode 26.3** (available on `macos-15` runner) for Swift 6.2 support
2. Installs **XcodeGen** and generates the Xcode project
3. Resolves all Swift Package dependencies (MLX, MLXAudio, etc.)
4. Builds the archive with code signing disabled
5. Packages the unsigned `.ipa`
6. Uploads the IPA as a downloadable artifact

**Caching** — Swift Package checkouts and XcodeGen are cached between runs to avoid re-downloading.

### Unsigned IPA Limitations

An unsigned IPA **cannot run on a real device**. iOS enforces code signing for all executables, and app extensions are rejected without valid provisioning profiles. The unsigned IPA serves as a **build validation artifact** — it proves the project compiles and packages correctly. Use the signed local build for actual testing.

---

## Dependencies

| Package | Purpose |
|---|---|
| [mlx-swift](https://github.com/ml-explore/mlx-swift) | Apple MLX framework for Swift |
| [mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift) | MLX-based audio models (TTS, STT, codecs) |
| [MOSS-TTS-Nano-100M](https://huggingface.co/mlx-community/MOSS-TTS-Nano-100M) | Quantized 100M-parameter multilingual TTS model |

---

## Implementation Details

### Extension Info.plist

The extension registers as a `vspr` (Voice Speech Provider) audio unit component:

- `NSExtensionPointIdentifier`: `com.apple.audio.synthesis.provider`
- `componentTypes`: `["vspr"]`
- `subtype`: `"moss"`

### Speech Synthesis Flow

1. iOS sends SSML to `synthesizeSpeech(for:outputBlock:)`
2. The extension extracts plain text from SSML and identifies the language from `request.voice.identifier`
3. If the MOSS-TTS-Nano model hasn't been loaded yet, it loads from the shared App Group container
4. `model.generate(text:voice:refAudio:refText:language:)` runs inference via MLX
5. The resulting `MLXArray` is converted to `AVAudioPCMBuffer` and returned to the system

### App Group

Both targets share `group.com.openmoss.mosstts`. The Host App downloads the model to this container, and the Extension reads it from there.

---

## License

This project uses [MOSS-TTS](https://github.com/OpenMOSS/MOSS-TTS) (Apache 2.0) via MLX-Audio.
