# Companion

A native macOS companion: a menu bar chat, a desktop pet, and push-to-talk voice, all driven by Claude.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15.3 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An Anthropic API key

## Setup

```sh
cd Companion
xcodegen generate        # creates Companion.xcodeproj (gitignored)
open Companion.xcodeproj
```

In Xcode, pick your team under **Signing & Capabilities** for the Companion target, then run (⌘R).
The app has no Dock icon; look for the speech bubble in the menu bar.

Run `xcodegen generate` again whenever you add or remove files.

### API key

On first launch the chat popover asks for your Anthropic API key (get one at
[console.anthropic.com](https://console.anthropic.com/settings/keys)). It's saved in your login Keychain
under the service `com.snazz.companion`, account `anthropic-api-key`. Change or remove it later in
**Settings** (⋯ menu in the popover › Settings…, or ⌘,).

For development you can instead set `ANTHROPIC_API_KEY` in the scheme's environment variables;
a key in the Keychain takes precedence. The key is never written to disk in the repo.

## Voice

Hold **⌥Space** (Option+Space) anywhere, talk, and let go. Companion transcribes what you said
with Apple's Speech framework (on-device when your language supports it) and sends it as a voice
message. Replies to voice messages are shorter and are spoken aloud with the system voice.

- **Mute:** the speaker button in the popover header, or Settings › Voice.
- **Change the hotkey, voice, or speed:** Settings › Voice. The hotkey needs at least one modifier.
  By default only replies to spoken messages are read aloud; turn on
  "Also speak replies to typed messages" to hear everything.
- The first time you use push-to-talk, macOS asks for **Microphone** and **Speech Recognition**
  access. If you deny either, the popover shows a banner with a button that opens the right pane of
  System Settings › Privacy & Security. Grant access there and try again.
- Push-to-talk uses a Carbon global hotkey, so it needs no Accessibility permission.

## Desktop pet

A small character floats above your windows. Drag it anywhere; clicks outside its body pass straight
through to whatever is underneath. Right-click it to hide it, or toggle **Show Desktop Pet** in the
popover's ⋯ menu. It stays where you leave it, across relaunches. It reacts to the chat: thinking while waiting for a reply, talking while a reply streams.

### Swapping in real art

The art sits behind the `PetArtwork` protocol (`Sources/Pet/PetArtwork.swift`):

```swift
protocol PetArtwork {
    var size: CGSize { get }
    func view(for state: CompanionState) -> AnyView   // .idle, .listening, .thinking, .talking
    func contains(_ point: CGPoint) -> Bool           // hit area; everything else is click-through
}
```

Write a conformer (sprites, images, Lottie, Rive…) and return it from `PetArtworkProvider.current`.
`BlobPetArtwork` is the placeholder.

## Settings

Open from the popover's ⋯ menu › **Settings…** (⌘,).

- **General:** API key, launch at login (via `SMAppService`; macOS may ask you to approve it in
  System Settings › General › Login Items), show/hide the pet.
- **Voice:** push-to-talk shortcut, mute, voice, speaking speed, preview.

The pet's position is remembered between launches.

## Roadmap

- Phase 2: hands-free wake word.

## Customizing

- **Personality:** edit `Sources/Resources/Personality.md`. It's the system prompt.
- **Model:** `Sources/Brain/Config.swift`.
- **Name / bundle ID:** `project.yml` (`name`, `PRODUCT_NAME`, `PRODUCT_BUNDLE_IDENTIFIER`).

## Layout

```
Sources/
  App/        app entry point
  Brain/      CompanionBrain, Anthropic streaming client, config, personality
  Views/      menu bar chat UI and first-run onboarding
  Settings/   Keychain storage and the Settings window
  Pet/        desktop pet window, artwork protocol, placeholder art
  Voice/      push-to-talk hotkey, speech recognition, text-to-speech
  Resources/  Personality.md
Tests/        unit tests
```

CI (`.github/workflows/companion-macos.yml`) generates the project and runs `xcodebuild test` on a macOS runner.
