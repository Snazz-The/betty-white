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

For now, set `ANTHROPIC_API_KEY` in the scheme (**Product › Scheme › Edit Scheme › Run › Arguments › Environment Variables**).
Don't commit the scheme with the key in it; the generated project is gitignored, so this is safe by default.

## Customizing

- **Personality:** edit `Sources/Resources/Personality.md`. It's the system prompt.
- **Model:** `Sources/Brain/Config.swift`.
- **Name / bundle ID:** `project.yml` (`name`, `PRODUCT_NAME`, `PRODUCT_BUNDLE_IDENTIFIER`).

## Layout

```
Sources/
  App/        app entry point
  Brain/      CompanionBrain, Anthropic streaming client, config, personality
  Views/      menu bar chat UI
  Resources/  Personality.md
Tests/        unit tests (SSE parsing, request shape)
```

CI (`.github/workflows/companion-macos.yml`) generates the project and runs `xcodebuild test` on a macOS runner.
