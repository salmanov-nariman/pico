# Pico

A native macOS desktop companion, built with Swift and SwiftUI.

## Current state

This initial scaffold opens a standard window with the Pico name and a temporary system paw icon. Desktop characters, transparent windows, animations, and interactions are not implemented yet. No backend or third-party dependencies are required.

## Requirements

- macOS 14 Sonoma or later.
- Xcode 15 or later with the macOS SDK.

## Run in Xcode

1. Open `Pico.xcodeproj`.
2. Select the shared **Pico** scheme and **My Mac** destination.
3. Press **Command-R**.

Local builds use ad-hoc signing and do not require a development team. Distribution signing and notarization are not configured.

## Build and run from Terminal

From the repository directory:

```sh
xcodebuild -project Pico.xcodeproj -scheme Pico -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
open build/Build/Products/Debug/Pico.app
```

If the active developer directory points to Command Line Tools, select Xcode for this Terminal session before building:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Source layout

```text
Pico.xcodeproj/                Xcode project and shared scheme
Pico/App/                     Application entry point and initial view
Pico/Resources/Assets.xcassets/ Asset catalog
```

AppKit and SpriteKit components will be introduced when desktop rendering and animation are implemented. Production character assets are not included yet.

## Manual verification

- Build and launch the Pico scheme.
- Confirm that a window shows “Pico”, a paw icon, and “Your desktop companion”.
- Resize the window and quit with Command-Q.

There is no automated test target yet. Build and manual verification must be performed locally; the initial scaffold has not been compiled or launched by the assistant.
