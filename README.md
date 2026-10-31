# Pico

A native macOS desktop companion built with SwiftUI, AppKit, and SpriteKit. No backend or third-party dependencies.

## Current preview

The Developer character sits behind a laptop in a transparent floating window, initially at the bottom right of the main display, above the Dock. He can take a coffee break, type, or sleep. Drag him to move; the position is restored on the next launch.

Click the paw icon in the menu bar to open the control panel. Select Rest, Work, or Sleep; adjust playback speed from 0.5× to 1.5×; pause or resume animation; show or hide Pico; reset his position; or quit. The panel currently uses Russian labels. State and speed are remembered between launches. Pico does not appear in the Dock or open a standard app window. macOS Reduce Motion disables the animation.

## Requirements

A normal left click triggers a state-specific reaction: Rest shows “Привет!”, looks toward the viewer, and waves with the free hand while holding the mug low, Work shows “…” without interrupting typing, and Sleep emits three floating Z letters without waking the character. Paused/reduced-motion playback shows a static reaction without moving the character. Repeated clicks do not stack reactions. The separate two-frame DeveloperGreetingAtlas interrupts a sip if necessary, then returns to the regular idle cycle. The existing coffee atlas is unchanged. Moving the pointer at least four points while holding the left button counts as dragging; releasing a drag does not trigger a reaction. Right-click and Control-click retain the context menu.

Owner-run reaction check: click in all three states, double-click, drag and release, then open the context menu. In Work, confirm typing continues while the busy bubble appears. In Rest, click both while holding the mug and while sipping: confirm a wave, a low mug and subsequent return to the automatic coffee cycle. Check state changes, repeated clicks and pause during the greeting. In Sleep, check the Z letters stay inside the overlay. Check animation pause and Reduce Motion. The assistant has checked the diff and project metadata, but has not built or run this milestone.

Right-click Pico (or Control-click) to open a native context menu with character states, timer start/pause/resume/reset, animation pause, and Hide. A checkmark indicates the selected state. Timer actions use the durations configured in the menu-bar panel; the remaining time is a snapshot taken when the context menu opens. Regular left-button dragging still moves the character. Show a hidden character again through the paw panel.

Owner-run context-menu check: right-click and Control-click the character, change states, start/pause/resume/reset a one-minute timer, and hide/show Pico. Confirm left-button dragging still works and dismissing the menu does not move Pico. Runtime verification is pending; the assistant has not launched this update.

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

Three manual states are available: Rest (coffee with a closed laptop), Work (typing in response to key activity, or optional automatic typing bursts), and Sleep (a fixed resting pose with localized torso breathing). State changes crossfade over 0.22 seconds. Pause freezes playback; changing the state while paused shows its first frame. Two-frame generated atlases are an initial animation pass and need visual review for alignment and jitter. Walking and general automatic state selection are not implemented. A focus/break timer is available in the menu panel. Optional word bubbles are available in Work. The window is 200 points square; visible artwork is approximately 180 points across. The small transparent margins also accept dragging.

Additional atlases: `DeveloperWorkingAtlas` and `DeveloperSleepingAtlas`, each with two equally sized horizontal cells. Work now uses its first cell with localized, alternating warps around both hands instead of switching between poses. Sleep uses only its first cell to keep furniture fixed; a small bounded SpriteKit warp moves the central hoodie region instead of scaling or rotating the whole sprite. `SpriteClip` loads catalog images into frames; `CompanionState` defines the selected behavior. This version uses bundled assets only, not user-imported character packages.

## Manual verification

- Confirm that Pico appears at the bottom right, with no opaque rectangle or window border.
- Put another normal application window behind him; confirm Pico remains visible without taking keyboard focus.
- In Rest, confirm the laptop is closed and Pico occasionally drinks coffee. Check the two poses for distracting jumps.
- Drag to another location; quit from the paw menu and relaunch to check persistence.
- Open the paw panel and switch between all three states, including rapid repeated switching. Check that the last selected state wins with no leftover sprite.
- Select Work with “Печатать вместе со мной” enabled: while idle, the hands must remain still. Type in another app and confirm short movements of both hands with word display off. Mouse movement and clicks alone must not trigger typing.
- Turn the switch off: automatic typing bursts and thinking pauses should resume. Turn it on again while idle: there must be no replay of earlier input.
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

The floating window stays above normal application windows. System overlays and some exclusive full-screen applications may cover it. Rest and Sleep run independently of keyboard activity. Work can follow aggregate keyboard activity or play automatically. Hand animation does not use an event tap or input permissions. Optional word display uses a separate passive event tap and requires Input Monitoring consent; it never controls input.

There is no automated test target yet. The initial scaffold was built and run by the project owner. The owner has also run the desktop preview and selected the softer-lighting character. The state animation and control panel changes require a fresh owner-run build and visual verification. The assistant has not built or run this version.

## Keyboard activity and privacy

“Печатать вместе со мной” is enabled by default for this implementation; its setting is remembered. Switch it off to use the automatic Work animation saved in commit `ef8352b`.

The hand animation queries [Core Graphics aggregate event activity](https://developer.apple.com/documentation/coregraphics/cgeventsource/counterforeventtype(_:eventtype:)) for the current login session. It samples the key-down total approximately 30 times per second, compares it with the previous sample, and signals a short animation only when new activity is recent. It does not receive individual events, inspect key codes or characters, or display a press count. The previous event tap and its permission preflight gate are not used for hand movement.

With word display off, only the latest aggregate sample is held in memory; there is no typing history, text collection, clipboard access, or transmission. Sampling stops outside visible, unpaused Work, when synchronization is off, during sleep, and with Reduce Motion enabled. Starting again establishes a fresh baseline; old activity is not replayed. Fast presses are combined into short bursts, not queued.

Apple documents that this counter excludes key autorepeat and modifier-only presses; holding a key is therefore not a continuous typing signal. Media keys may not be counted. The session state can include software-generated events, so this is an activity animation rather than an exact physical keystroke mirror. System restrictions may limit the activity reported; no readiness or permission-success claim is shown in the panel.

The project owner confirmed that aggregate activity synchronization works. The assistant has not built or run the subsequent two-hand animation and word-display changes. Verify rapid typing, idle time, mouse-only use, Pause/Resume, Hide/Show, mode changes, and sleep/wake. The automatic mode remains available.

## Optional word display

Enable “Показывать набранные слова” under Work to preview what you type. It starts off each time Pico launches. This explicitly enables a separate [listen-only keyboard event tap](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)); the working aggregate activity monitor is unchanged. Permission denial affects words only, never the hands.

If needed, “Разрешить показ слов” requests Input Monitoring and opens its settings. It disappears once macOS reports access for this process. If a stale grant belongs to another build, “Показать эту копию Pico” reveals the exact running bundle so you can select that copy in settings. Restart the same app if macOS requests it. Stable development signing helps grants survive rebuilds; moving an ad-hoc executable does not repair a mismatched grant. Pico never resets permissions itself.

Characters accumulate above the laptop. Space, Return, or Tab sends the current word upward; Backspace removes its last grapheme. Text is bounded to 24 characters per bubble and three flying bubbles; longer words split into chunks. A draft clears after four animation seconds without new input. There is no transcript, file logging, clipboard reading, or network transmission.

The preview is visible to people and screen recordings. Only enable it when you want your typing shown. Text clears on pause, hide, mode changes, sync or word-display disable, sleep, app switches, mouse clicks, navigation, and Command/Control shortcuts. The optional monitor stops when inactive or when macOS reports Secure Event Input, and checks secure input before decoding each event. This relies on the source app using macOS secure-input facilities; it is not a universal detector for sensitive content in ordinary text fields.

This is a visualization of key-event text, not a copy of the target app's document. Paste, dictation, autocomplete, cursor edits and composed IME input are not reconstructed; dead keys or composed input may differ from the final text in the target app. Ordinary Russian/English typing and Shift use the Unicode supplied by macOS.

Manual verification for this update:

- With word display off or permission denied, confirm both hands still respond and no text appears.
- With word display enabled and permission granted, type `hello ` and `привет ` in a normal text editor: letters should accumulate and each Space should send only the completed word upward.
- Try Backspace, repeated spaces, Return, a long word, rapid typing and a pause; check bounded bubbles and legibility.
- Switch apps, click a different field, hide Pico, pause, disable synchronization and change states; no draft should reappear later.
- With macOS Secure Event Input active, confirm that words pause and existing text clears. Use dummy text for this check.
- Inspect both hands and nearby laptop edges at 0.5×, 1× and 1.5×. The atlas is unchanged; the new warps need owner-run visual verification.

## Focus and break timer

The menu panel includes configurable work (1–120 minutes, default 25) and break (1–30 minutes, default 5) intervals. Start selects Work; finishing work selects Rest and leaves a reminder in the menu bar. Start the break explicitly. Completing a break leaves Pico resting until another work interval is started. Pause/Resume and Reset affect only the timer, not animation playback. Reset leaves the current character mode unchanged. Manual character selection remains available during an interval.

The countdown continues when the panel is closed or Pico is hidden. A deadline, rather than tick counting, handles delayed callbacks and sleep: waking after a deadline finishes that interval once and waits for user action. System clock changes affect the deadline. Only durations are persisted; quitting Pico cancels the active timer. There are no system notifications, sounds, automatic login launch, or automatic cycle chaining in this milestone.

Owner-run verification: set work and rest to one minute, start work, close the panel and watch the menu bar. Confirm the countdown and coffee mode at completion; explicitly start the break. Check timer pause/resume, reset, hiding Pico, sleep/wake, and switching character states. Animation speed and animation pause must not change the timer.

Standalone timer checks (run from the repository root):

```sh
xcrun swiftc Pico/App/FocusTimer.swift Tests/FocusTimerChecks.swift -o /tmp/pico-focus-timer-checks
/tmp/pico-focus-timer-checks
```

These checks cover pause, resume, late ticks, single completion, manual phase transitions, duplicate starts, and cancellation. They do not launch Pico. The assistant has not compiled or run them; build and runtime verification remain owner-run.
