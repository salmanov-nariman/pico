import AppKit
import Combine
import CoreGraphics
import SpriteKit

final class CompanionController: NSObject, ObservableObject, NSWindowDelegate {
    let focusTimer = FocusTimer()
    @Published private(set) var isVisible = false
    @Published private(set) var animationEnabled = true

    @Published private(set) var selectedState: CompanionState = .idle
    @Published private(set) var playbackRate: Double = 1
    @Published private(set) var reduceMotion = false
    @Published private(set) var automaticMode = false
    @Published private(set) var restAfterMinutes = 2
    @Published private(set) var sleepAfterMinutes = 10
    private var activityTimer: Timer?

    @Published private(set) var keyboardSyncEnabled = true
    private let keyboardMonitor = KeyboardActivityMonitor()
    @Published private(set) var wordsEnabled = false
    @Published private(set) var wordStatus = ""
    @Published private(set) var wordPermissionNeeded = false
    @Published private(set) var wordConnectionFailed = false
    private let wordMonitor = WordInputMonitor()
    private var wordHealthTimer: Timer?

    private let size = NSSize(width: 200, height: 200)
    private let positionKey = "companion.origin"
    private var panel: NSPanel?
    private var scene: CompanionScene?
    private var visibilityRefresh: DispatchWorkItem?

    override init() {
        super.init()
        focusTimer.onStart = { [weak self] phase in
            self?.applyState(phase == .focus ? .working : .idle)
        }
        focusTimer.onFinish = { [weak self] _ in
            self?.applyState(.idle)
        }
        automaticMode = UserDefaults.standard.bool(forKey: "companion.automaticMode")
        restAfterMinutes = min(15, max(1, UserDefaults.standard.object(forKey: "companion.restAfter") as? Int ?? 2))
        sleepAfterMinutes = min(60, max(restAfterMinutes + 1, UserDefaults.standard.object(forKey: "companion.sleepAfter") as? Int ?? 10))
        keyboardSyncEnabled = UserDefaults.standard.object(forKey: "companion.typingFollowsKeyboard") as? Bool ?? true
        keyboardMonitor.onActivity = { [weak self] in
            self?.scene?.registerKeystroke()
        }
        wordMonitor.onInput = { [weak self] input in
            guard let self, self.wordsEnabled else { return }
            self.scene?.receiveWordInput(input)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(frontApplicationChanged),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshKeyboardMonitoring),
            name: NSApplication.didBecomeActiveNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(workspaceWillSleep),
            name: NSWorkspace.willSleepNotification, object: nil
        )
        selectedState = CompanionState(rawValue: UserDefaults.standard.string(forKey: "companion.state") ?? "") ?? .idle
        let savedRate = UserDefaults.standard.object(forKey: "companion.rate") as? Double ?? 1
        playbackRate = savedRate.isFinite ? min(max(savedRate, 0.5), 1.5) : 1
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for name in [NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didWakeNotification,
                     NSWorkspace.screensDidWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(workspaceChanged), name: name, object: nil
            )
        }
        animationEnabled = UserDefaults.standard.object(forKey: "companion.animate") as? Bool ?? true
        NotificationCenter.default.addObserver(
            self, selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(motionPreferencesChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil
        )
    }

    deinit {
        activityTimer?.invalidate()
        wordHealthTimer?.invalidate()
        visibilityRefresh?.cancel()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func show() {
        if panel == nil { createPanel() }
        guard let panel else { return }
        panel.setFrameOrigin(clamped(panel.frame.origin))
        panel.orderFrontRegardless()
        isVisible = true
        scene?.isPaused = false
        refreshAutomaticMode()
        refreshKeyboardMonitoring()
    }

    func toggleVisibility() {
        if isVisible {
            visibilityRefresh?.cancel()
            panel?.orderOut(nil)
            scene?.isPaused = true
            isVisible = false
            refreshAutomaticMode()
            refreshKeyboardMonitoring()
        } else {
            show()
        }
    }

    func toggleAnimation() {
        animationEnabled.toggle()
        UserDefaults.standard.set(animationEnabled, forKey: "companion.animate")
        motionPreferencesChanged()
    }

    func selectState(_ state: CompanionState) {
        // A manual choice wins even if the selected state is unchanged.
        setAutomaticMode(false)
        applyState(state)
    }

    private func applyState(_ state: CompanionState) {
        guard state != selectedState else { return }
        selectedState = state
        UserDefaults.standard.set(state.rawValue, forKey: "companion.state")
        scene?.setState(state)
        refreshKeyboardMonitoring()
    }

    func setAutomaticMode(_ enabled: Bool) {
        automaticMode = enabled
        UserDefaults.standard.set(enabled, forKey: "companion.automaticMode")
        refreshAutomaticMode()
    }

    func configureAutomaticMode(rest: Int, sleep: Int) {
        restAfterMinutes = min(15, max(1, rest))
        sleepAfterMinutes = min(60, max(restAfterMinutes + 1, sleep))
        UserDefaults.standard.set(restAfterMinutes, forKey: "companion.restAfter")
        UserDefaults.standard.set(sleepAfterMinutes, forKey: "companion.sleepAfter")
        updateAutomaticState()
    }

    private func refreshAutomaticMode() {
        activityTimer?.invalidate()
        activityTimer = nil
        guard automaticMode, isVisible, animationEnabled else { return }
        updateAutomaticState()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateAutomaticState()
        }
        timer.tolerance = 0.15
        activityTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func updateAutomaticState() {
        // Running, paused and completed timer sessions retain their selected
        // behavior until reset, so activity cannot erase the break reminder.
        guard automaticMode, isVisible, animationEnabled else { return }
        switch focusTimer.status {
        case .running, .paused:
            applyState(focusTimer.phase == .focus ? .working : .idle)
            return
        case .finished:
            applyState(.idle)
            return
        case .ready: break
        }
        let idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!
        )
        guard idleSeconds.isFinite, idleSeconds >= 0 else { return }
        let state: CompanionState = idleSeconds >= Double(sleepAfterMinutes * 60) ? .sleeping
            : idleSeconds >= Double(restAfterMinutes * 60) ? .idle : .working
        applyState(state)
    }

    func setKeyboardSync(_ enabled: Bool) {
        keyboardSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "companion.typingFollowsKeyboard")
        scene?.setKeyboardSync(enabled)
        refreshKeyboardMonitoring()
    }

    @objc private func refreshKeyboardMonitoring() {
        if keyboardSyncEnabled, selectedState == .working,
           isVisible, animationEnabled, !reduceMotion {
            keyboardMonitor.start()
        } else {
            keyboardMonitor.stop()
            scene?.stopTyping()
        }
        refreshWordMonitoring()
    }

    func setWordsEnabled(_ enabled: Bool) {
        wordsEnabled = enabled
        scene?.clearWords()
        refreshWordMonitoring()
    }

    func requestWordPermission() {
        wordMonitor.requestPermission()
        openWordPermissionSettings()
        refreshWordMonitoring()
    }

    func openWordPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func revealRunningApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    @objc private func frontApplicationChanged() {
        scene?.clearWords()
        refreshWordMonitoring()
    }

    private func refreshWordMonitoring() {
        guard wordsEnabled, keyboardSyncEnabled, selectedState == .working,
              isVisible, animationEnabled, !reduceMotion else {
            wordMonitor.stop()
            wordHealthTimer?.invalidate()
            wordHealthTimer = nil
            scene?.clearWords()
            wordStatus = "Показ слов выключен или приостановлен."
            wordPermissionNeeded = false
            wordConnectionFailed = false
            return
        }
        if wordHealthTimer == nil {
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.refreshWordMonitoring()
            }
            timer.tolerance = 0.1
            wordHealthTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        wordPermissionNeeded = !wordMonitor.hasPermission
        wordConnectionFailed = false
        if wordPermissionNeeded {
            wordMonitor.stop()
            scene?.clearWords()
            wordStatus = "Для букв нужен доступ к вводу. Движение рук работает и без него."
        } else if wordMonitor.isSecureInput {
            wordMonitor.stop()
            scene?.clearWords()
            wordStatus = "Защищённый ввод: показ слов приостановлен."
        } else if wordMonitor.start() {
            wordStatus = "Набирай слово; пробел отправит его вверх."
        } else {
            scene?.clearWords()
            wordConnectionFailed = true
            wordStatus = "Не удалось включить буквы. Проверь доступ именно для этой копии Pico и перезапусти её."
        }
    }

    @objc private func workspaceWillSleep() {
        activityTimer?.invalidate()
        activityTimer = nil
        keyboardMonitor.stop()
        scene?.stopTyping()
        wordMonitor.stop()
        wordHealthTimer?.invalidate()
        wordHealthTimer = nil
        scene?.clearWords()
    }

    func setPlaybackRate(_ rate: Double) {
        playbackRate = rate.isFinite ? min(max(rate, 0.5), 1.5) : 1
        UserDefaults.standard.set(playbackRate, forKey: "companion.rate")
        scene?.setPlaybackRate(playbackRate)
    }

    func resetPosition() {
        if panel == nil { createPanel() }
        panel?.setFrameOrigin(defaultOrigin())
        savePosition()
        show()
    }

    func savePosition() {
        guard let panel else { return }
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: positionKey)
    }

    func windowDidMove(_ notification: Notification) {
        savePosition()
    }

    @objc private func displaysChanged() {
        guard let panel else { return }
        panel.setFrameOrigin(clamped(panel.frame.origin))
        savePosition()
    }

    /// Reassert visibility after macOS finishes changing Spaces, without taking focus.
    @objc private func workspaceChanged() {
        focusTimer.refresh()
        refreshAutomaticMode()
        keyboardMonitor.stop()
        refreshKeyboardMonitoring()
        visibilityRefresh?.cancel()
        guard isVisible else { return }
        panel?.orderFrontRegardless()
        let refresh = DispatchWorkItem { [weak self] in
            guard let self, self.isVisible else { return }
            self.panel?.orderFrontRegardless()
        }
        visibilityRefresh = refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: refresh)
    }

    @objc private func motionPreferencesChanged() {
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        scene?.setAnimated(animationEnabled && !reduceMotion)
        refreshAutomaticMode()
        refreshKeyboardMonitoring()
    }

    private func createPanel() {
        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        window.title = "Pico"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        // Use the modern overlay behavior for Stage Manager and full-screen apps.
        // Stationary opts out of the default floating-window hiding in Mission Control.
        window.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications,
                                     .stationary, .ignoresCycle]
        window.animationBehavior = .none
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.delegate = self

        let view = DraggableSpriteView(frame: NSRect(origin: .zero, size: size))
        view.allowsTransparency = true
        view.preferredFramesPerSecond = 60
        view.setAccessibilityLabel("Pico desktop companion. Drag to move.")
        view.onDragEnded = { [weak self] in self?.displaysChanged() }
        view.onClick = { [weak self] in self?.scene?.greet() }
        view.makeContextMenu = { [weak self] in self?.makeContextMenu() }
        let companionScene = CompanionScene(size: size)
        companionScene.setKeyboardSync(keyboardSyncEnabled)
        companionScene.setState(selectedState)
        companionScene.setPlaybackRate(playbackRate)
        companionScene.setAnimated(animationEnabled && !reduceMotion)
        view.presentScene(companionScene)
        window.contentView = view
        panel = window
        scene = companionScene
        motionPreferencesChanged()

        let saved = UserDefaults.standard.string(forKey: positionKey).map(NSPointFromString)
        window.setFrameOrigin(clamped(saved ?? defaultOrigin()))
    }

    private func makeContextMenu() -> NSMenu {
        focusTimer.refresh()
        let menu = NSMenu(title: "Pico")
        menu.autoenablesItems = false
        for state in CompanionState.allCases {
            let item = NSMenuItem(title: state.title, action: #selector(contextSelectState(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = state.rawValue
            item.state = selectedState == state ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let timerTitle: String
        let timerAction: Selector
        switch focusTimer.status {
        case .ready:
            timerTitle = "Начать работу · \(focusTimer.focusMinutes) мин"
            timerAction = #selector(contextStartTimer)
        case .running:
            timerTitle = "Пауза таймера · \(focusTimer.timeLabel)"
            timerAction = #selector(contextPauseTimer)
        case .paused:
            timerTitle = "Продолжить таймер · \(focusTimer.timeLabel)"
            timerAction = #selector(contextResumeTimer)
        case .finished:
            timerTitle = focusTimer.phase == .focus
                ? "Начать отдых · \(focusTimer.restMinutes) мин"
                : "Начать работу · \(focusTimer.focusMinutes) мин"
            timerAction = #selector(contextStartTimer)
        }
        let timerItem = NSMenuItem(title: timerTitle, action: timerAction, keyEquivalent: "")
        timerItem.target = self
        menu.addItem(timerItem)
        if focusTimer.status != .ready {
            let reset = NSMenuItem(title: "Сбросить таймер", action: #selector(contextResetTimer), keyEquivalent: "")
            reset.target = self
            menu.addItem(reset)
        }
        menu.addItem(.separator())
        let animation = NSMenuItem(title: animationEnabled ? "Приостановить анимацию" : "Продолжить анимацию",
                                   action: #selector(contextToggleAnimation), keyEquivalent: "")
        animation.target = self
        animation.isEnabled = !reduceMotion
        menu.addItem(animation)
        let hide = NSMenuItem(title: "Скрыть Pico", action: #selector(contextHide), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)
        return menu
    }

    @objc private func contextSelectState(_ item: NSMenuItem) {
        guard let rawValue = item.representedObject as? String,
              let state = CompanionState(rawValue: rawValue) else { return }
        selectState(state)
    }

    @objc private func contextStartTimer() { focusTimer.startNext() }
    @objc private func contextPauseTimer() { focusTimer.pause() }
    @objc private func contextResumeTimer() { focusTimer.resume() }
    @objc private func contextResetTimer() { focusTimer.reset() }
    @objc private func contextToggleAnimation() { toggleAnimation() }
    @objc private func contextHide() { if isVisible { toggleVisibility() } }

    private func defaultOrigin() -> NSPoint {
        guard let frame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else { return .zero }
        return NSPoint(x: frame.maxX - size.width - 16, y: frame.minY + 12)
    }

    private func clamped(_ origin: NSPoint) -> NSPoint {
        guard origin.x.isFinite, origin.y.isFinite else { return defaultOrigin() }
        let proposed = NSRect(origin: origin, size: size)
        let screen = NSScreen.screens.max { first, second in
            intersectionArea(proposed, first.visibleFrame) < intersectionArea(proposed, second.visibleFrame)
        }
        guard let screen, intersectionArea(proposed, screen.visibleFrame) > 0 else {
            return defaultOrigin()
        }
        let frame = screen.visibleFrame
        return NSPoint(
            x: min(max(origin.x, frame.minX), max(frame.minX, frame.maxX - size.width)),
            y: min(max(origin.y, frame.minY), max(frame.minY, frame.maxY - size.height))
        )
    }

    private func intersectionArea(_ first: NSRect, _ second: NSRect) -> CGFloat {
        let intersection = first.intersection(second)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}

private final class DraggableSpriteView: SKView {
    var onDragEnded: (() -> Void)?
    var onClick: (() -> Void)?
    var makeContextMenu: (() -> NSMenu?)?
    private var pressLocation: NSPoint?
    private var initialOrigin: NSPoint?
    private var dragging = false

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        pressLocation = nil
        initialOrigin = nil
        dragging = false
        if event.modifierFlags.contains(.control) {
            showContextMenu(with: event)
            return
        }
        pressLocation = NSEvent.mouseLocation
        initialOrigin = window?.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pressLocation, let initialOrigin else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - pressLocation.x
        let dy = current.y - pressLocation.y
        if !dragging, hypot(dx, dy) < 4 { return }
        dragging = true
        window?.setFrameOrigin(NSPoint(x: initialOrigin.x + dx, y: initialOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        guard pressLocation != nil else { return }
        let wasDragging = dragging
        pressLocation = nil
        initialOrigin = nil
        dragging = false
        if wasDragging { onDragEnded?() } else { onClick?() }
    }

    override func rightMouseDown(with event: NSEvent) {
        showContextMenu(with: event)
    }

    private func showContextMenu(with event: NSEvent) {
        guard let menu = makeContextMenu?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
