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

Local builds use ad-hoc signing and do not require a development team. Distribution signing and notarization are not configured.

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

Three manual states are available: Rest (coffee with a closed laptop), Work (typing in response to keyboard activity, with small floating characters from your key presses), and Sleep (a fixed resting pose with localized torso breathing). State changes crossfade over 0.22 seconds. Pause freezes playback; changing the state while paused shows its first frame. Two-frame generated atlases are an initial animation pass and need visual review for alignment and jitter. Walking, speech bubbles, automatic behavior, and timers are not implemented. The window is 200 points square; visible artwork is approximately 180 points across. The small transparent margins also accept dragging.

Additional atlases: `DeveloperWorkingAtlas` and `DeveloperSleepingAtlas`, each with two equally sized horizontal cells. Sleep uses only its first cell to keep furniture fixed; a small bounded SpriteKit warp moves the central hoodie region instead of scaling or rotating the whole sprite. `SpriteClip` loads catalog images into frames; `CompanionState` defines the selected behavior. This version uses bundled assets only, not user-imported character packages.

## Manual verification

- Confirm that Pico appears at the bottom right, with no opaque rectangle or window border.
- Put another normal application window behind him; confirm Pico remains visible without taking keyboard focus.
- In Rest, confirm the laptop is closed and Pico occasionally drinks coffee. Check the two poses for distracting jumps.
- Drag to another location; quit from the paw menu and relaunch to check persistence.
- Open the paw panel and switch between all three states, including rapid repeated switching. Check that the last selected state wins with no leftover sprite.
- In Work, watch hand movement and brief floating typed characters. Labels must stop when paused and disappear on a state change.
- In Sleep, watch the chair and laptop edges: they should remain fixed while only the hoodie area moves subtly. There should be no whole-image sway.
- Check 0.5× and 1.5× speeds, Pause/Resume, Hide/Show, and Move to Bottom Right. Changing state while paused should show a still pose.
- Quit and relaunch to verify state, speed, and position persistence.
- Enable Reduce Motion in macOS Accessibility settings and check that motion stops.
- Swipe between desktop Spaces; check that Pico remains at his saved location without taking keyboard focus.
- Test Mission Control, Stage Manager, and a full-screen app. macOS controls the transition animation; some system overlays can still cover Pico.
- Hide Pico, switch Spaces, and confirm he stays hidden. Open the installed app again to show him.
- Test sleep/wake and, if available, another display and display disconnection.
- Launch the installed copy, quit Xcode and Terminal, and confirm Pico keeps running.

The floating window stays above normal application windows. System overlays and some exclusive full-screen applications may cover it. The optional keyboard activity feature requires Input Monitoring permission. Screen recording is not required.

There is no automated test target yet. The initial scaffold was built and run by the project owner. The owner has also run the desktop preview and selected the softer-lighting character. The state animation and control panel changes require a fresh owner-run build and visual verification. The assistant has not built or run this version.


## Optional typing synchronization

Select Work in the panel, then enable “Печатать вместе со мной”. macOS asks for Input Monitoring access. Grant it to Pico in System Settings > Privacy & Security > Input Monitoring, then restart Pico if requested. Development builds using ad-hoc signing may need permission to be granted again after rebuilding. “Проверить доступ” retries the connection; “Проверить анимацию” previews one typing burst without permissions.

Pico uses a passive listen-only event tap. While synchronization is enabled, it reads the first Unicode character of each key-down event and briefly displays it above the laptop. These characters are visible to anyone viewing or recording the screen. No typing history, logs, files, network transmission, or clipboard access are used. Command/Control shortcuts and control/function characters are skipped; Space appears as ␣. Modifier-aware Unicode text supports keyboard layouts such as Russian and English; composed input methods may produce intermediate characters rather than finalized text. At most eight glyphs are visible; fast typing replaces the oldest. Pausing, hiding, disabling synchronization, or changing state clears the visible glyphs. Monitoring stops when disabled, hidden, paused, in Reduce Motion, or outside Work. Secure input fields may suppress events; this is expected. Without permission, Work remains still except for explicit preview clicks.

The development app now builds without App Sandbox to support system-wide keyboard observation. This does not bypass macOS Input Monitoring consent. Existing preferences stored by the previous sandboxed build may reset when switching to this build.

### Verification of the latest changes

- Rest: no table or legs, closed laptop and coffee mug; verify logo placement at normal display size.
- Sleep: chair and laptop stay fixed; only the hoodie region breathes.
- Work: no typing while you are idle; key presses in another app trigger short hand movement and brief typed characters. Stopping typing stops the motion after the current short burst.
- Turn synchronization off, hide Pico, switch modes, and pause: no new key-driven effects should appear. Check permission denial and restart after granting access.
- The assistant has not built or launched this update; compile and check the behavior locally.

Latest visual check: type `abc АБВ {} ; @` with appropriate layouts and Shift; compare the glyphs. Check Space, Backspace, arrows, Command-C/V, rapid typing, pause and sync off. Preview Animation moves the hands without inventing letters. Secure-input fields may suppress events. Build/run verification is still performed by the owner.

Coffee now uses a relaxed smile and separate animated steam that follows the cup pose. Keyboard connection is checked every two seconds while synchronization is enabled. The panel shows an activity count (no character history) and an explicit reconnect button. Unicode is read at the annotated session event tap. The reported stopped-typing issue is not yet confirmed resolved: use the count to distinguish missing input events from rendering issues. If the count stays zero, retry access for the current Pico build; secure input or a stale macOS permission may prevent delivery. If it increases while the hands stay still, report that distinction. User build and runtime validation are pending.
