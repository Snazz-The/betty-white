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
  Resources/  Personality.md
Tests/        unit tests (SSE parsing, request shape)
```

CI (`.github/workflows/companion-macos.yml`) generates the project and runs `xcodebuild test` on a macOS runner.
