# Pico

A native macOS desktop companion: choose a little programmer or a cat to work, drink coffee and sleep beside your windows. Pico reacts to typing, includes a focus timer with break reminders, and celebrates successful builds and tests. Built with SwiftUI, AppKit and SpriteKit; no backend or third-party dependencies.

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later

## Run

1. Clone this repository and open `Pico.xcodeproj` in Xcode.
2. Select the **Pico** scheme and **My Mac**.
3. In **Signing & Capabilities**, choose your development team. For a local preview without an account, select **Sign to Run Locally** and clear the development team in Build Settings.
4. Press **⌘R**.

Pico appears in the bottom-right corner. Open the paw icon in the menu bar for settings, drag the character to move him, or right-click for quick actions.

Optional display of typed words requires **Input Monitoring** permission for the exact copy of Pico you launch. Basic typing animation works independently of that permission.

## Run without Xcode open

Quit Pico and stop the Xcode run, then execute these commands from the repository folder:

```sh
bash scripts/install-local.sh
open "$HOME/Applications/Pico.app"
```

This builds and installs Pico in your personal Applications folder. Launch it from there afterward; avoid running two copies at once.
