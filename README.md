# Pico

A native macOS desktop companion built with SwiftUI, AppKit, and SpriteKit. No backend or third-party dependencies.

## Current preview

The Developer character sits behind a laptop in a transparent floating window, initially at the bottom right of the main display, above the Dock. He can take a coffee break, type, or sleep. Drag him to move; the position is restored on the next launch.

Click the paw icon in the menu bar to open the control panel. Select Rest, Work, or Sleep; adjust playback speed from 0.5× to 1.5×; pause or resume animation; show or hide Pico; reset his position; or quit. The panel currently uses Russian labels. State and speed are remembered between launches. Pico does not appear in the Dock or open a standard app window. macOS Reduce Motion disables the animation.

## Requirements

- macOS 14 Sonoma or later.
- Xcode 15 or later with the macOS SDK.

## Run in Xcode

1. Open `Pico.xcodeproj`.
2. Select **Pico** and **My Mac**.
3. Press **Command-R**.

The current project uses automatic Apple Development signing. Select your own team in Signing & Capabilities, or use Sign to Run Locally for a local preview. Distribution signing and notarization are not configured.

## Build and run from Terminal

Quit an existing Pico instance from its menu bar icon before launching an updated build. From the repository directory:

```sh
xcodebuild -project Pico.xcodeproj -scheme Pico -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
open build/Build/Products/Debug/Pico.app
```

If the active developer directory points to Command Line Tools, select Xcode for this Terminal session:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Install for everyday use (without Xcode running)

Quit Pico using the paw menu and stop any Xcode run. From the repository directory:

```sh
bash scripts/install-local.sh
open "$HOME/Applications/Pico.app"
```

The script builds Release, copies Pico to your personal Applications folder, and verifies the local signature. It does not launch the app or require administrator privileges. It refuses to replace another application with a different bundle identifier. Use the same script to update Pico after code or asset changes.

Once launched this way, Pico runs independently of Xcode and Terminal. You can close both. Quit Pico explicitly from its paw menu. Opening the installed app again shows the character if it was hidden. Do not run an Xcode copy at the same time as the installed copy.

Pico currently runs until you quit it or log out. For automatic launch after login, optionally add `~/Applications/Pico.app` to macOS System Settings > General > Login Items (the exact label varies by macOS version). Installation does not enable login launch automatically.

## Source layout

```text
Pico.xcodeproj/                  Xcode project and shared scheme
Pico/App/PicoApp.swift           App lifecycle and menu bar entry
Pico/App/ContentView.swift       Menu controls
Pico/App/CompanionController.swift  Floating window, dragging, persistence
Pico/App/CompanionScene.swift    Idle animation and sprite rendering
Pico/Resources/Assets.xcassets/  Bundled character atlas and accent color
```

## Character asset

`DeveloperIdleAtlas` is an AI-generated transparent PNG based on the supplied Developer character reference. It contains two horizontal cells: holding a coffee mug and taking a sip, with the laptop closed. SpriteKit reads each half separately. The previous idle artwork is retained locally as a reference. The full reference sheet is not used as a runtime sprite.

Three manual states are available: Rest (coffee with a closed laptop), Work (automatic typing bursts with short thinking pauses), and Sleep (a fixed resting pose with localized torso breathing). State changes crossfade over 0.22 seconds. Pause freezes playback; changing the state while paused shows its first frame. Two-frame generated atlases are an initial animation pass and need visual review for alignment and jitter. Walking, speech bubbles, automatic state selection, and timers are not implemented. The window is 200 points square; visible artwork is approximately 180 points across. The small transparent margins also accept dragging.

Additional atlases: `DeveloperWorkingAtlas` and `DeveloperSleepingAtlas`, each with two equally sized horizontal cells. Sleep uses only its first cell to keep furniture fixed; a small bounded SpriteKit warp moves the central hoodie region instead of scaling or rotating the whole sprite. `SpriteClip` loads catalog images into frames; `CompanionState` defines the selected behavior. This version uses bundled assets only, not user-imported character packages.

## Manual verification

- Confirm that Pico appears at the bottom right, with no opaque rectangle or window border.
- Put another normal application window behind him; confirm Pico remains visible without taking keyboard focus.
- In Rest, confirm the laptop is closed and Pico occasionally drinks coffee. Check the two poses for distracting jumps.
- Drag to another location; quit from the paw menu and relaunch to check persistence.
- Open the paw panel and switch between all three states, including rapid repeated switching. Check that the last selected state wins with no leftover sprite.
- Select Work without typing: hands should start moving immediately, alternating typing bursts and short pauses, with no floating text. No keyboard controls or permission prompts should appear.
- Pause Work and confirm it freezes; resume and confirm typing continues. Hide/Show and switch Rest → Work → Sleep → Work, including while paused, to check that only the selected animation runs.
- In Sleep, watch the chair and laptop edges: they should remain fixed while only the hoodie area moves subtly. There should be no whole-image sway.
- Check 0.5× and 1.5× speeds, Pause/Resume, Hide/Show, and Move to Bottom Right. Changing state while paused should show a still pose.
- Quit and relaunch to verify state, speed, and position persistence.
- Enable Reduce Motion in macOS Accessibility settings and check that motion stops.
- Swipe between desktop Spaces; check that Pico remains at his saved location without taking keyboard focus.
- Test Mission Control, Stage Manager, and a full-screen app. macOS controls the transition animation; some system overlays can still cover Pico.
- Hide Pico, switch Spaces, and confirm he stays hidden. Open the installed app again to show him.
- Test sleep/wake and, if available, another display and display disconnection.
- Launch the installed copy, quit Xcode and Terminal, and confirm Pico keeps running.

The floating window stays above normal application windows. System overlays and some exclusive full-screen applications may cover it. Animations run independently of keyboard activity. Input Monitoring, Accessibility access, and Screen Recording permission are not required.

There is no automated test target yet. The initial scaffold was built and run by the project owner. The owner has also run the desktop preview and selected the softer-lighting character. The state animation and control panel changes require a fresh owner-run build and visual verification. The assistant has not built or run this version.

## Keyboard privacy

Keyboard synchronization is currently removed. Pico does not install keyboard event monitors, read key contents, count presses, or request input permissions. Work uses a local SpriteKit animation with the existing two-frame atlas. It follows playback speed, Pause/Resume, Hide/Show, and macOS Reduce Motion. Previously granted Input Monitoring access is no longer used and can be removed in System Settings; Pico does not change system permissions itself.
