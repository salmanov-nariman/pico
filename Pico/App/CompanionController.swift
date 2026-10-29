import AppKit
import Combine
import CoreGraphics
import SpriteKit

final class CompanionController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var isVisible = false
    @Published private(set) var animationEnabled = true

    @Published private(set) var selectedState: CompanionState = .idle
    @Published private(set) var playbackRate: Double = 1
    @Published private(set) var reduceMotion = false

    @Published private(set) var keyboardSyncEnabled = false
    @Published private(set) var keyboardMessage = "Связь с клавиатурой выключена."
    @Published private(set) var receivedKeyPresses = 0
    private var keyboardHealthTimer: Timer?
    private let keyboardMonitor = KeyboardActivityMonitor()

    private let size = NSSize(width: 200, height: 200)
    private let positionKey = "companion.origin"
    private var panel: NSPanel?
    private var scene: CompanionScene?
    private var visibilityRefresh: DispatchWorkItem?

    override init() {
        super.init()
        keyboardSyncEnabled = UserDefaults.standard.bool(forKey: "companion.keyboardSync")
        keyboardMonitor.onPress = { [weak self] glyph in
            guard let self else { return }
            self.receivedKeyPresses = (self.receivedKeyPresses + 1) % 1_000_000
            self.scene?.registerKeystroke(glyph: glyph)
        }
        keyboardMonitor.onUnavailable = { [weak self] in
            DispatchQueue.main.async { [weak self] in self?.refreshKeyboardMonitoring() }
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshKeyboardMonitoring),
            name: NSApplication.didBecomeActiveNotification, object: nil
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
        keyboardHealthTimer?.invalidate()
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
        if keyboardHealthTimer == nil {
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                guard let self, self.keyboardSyncEnabled else { return }
                self.refreshKeyboardMonitoring()
            }
            RunLoop.main.add(timer, forMode: .common)
            keyboardHealthTimer = timer
        }
        scene?.isPaused = false
        refreshKeyboardMonitoring()
    }

    func toggleVisibility() {
        if isVisible {
            visibilityRefresh?.cancel()
            scene?.clearTypingEffects()
            panel?.orderOut(nil)
            scene?.isPaused = true
            isVisible = false
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
        guard state != selectedState else { return }
        selectedState = state
        UserDefaults.standard.set(state.rawValue, forKey: "companion.state")
        scene?.setState(state)
        refreshKeyboardMonitoring()
    }

    func setKeyboardSync(_ enabled: Bool) {
        keyboardSyncEnabled = enabled
        if !enabled { scene?.clearTypingEffects() }
        UserDefaults.standard.set(enabled, forKey: "companion.keyboardSync")
        if enabled && !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
        refreshKeyboardMonitoring()
    }

    @objc func refreshKeyboardMonitoring() {
        guard keyboardSyncEnabled else {
            keyboardMonitor.stop()
            keyboardMessage = "Связь с клавиатурой выключена."
            return
        }
        guard CGPreflightListenEventAccess() else {
            keyboardMonitor.stop()
            keyboardMessage = "Разреши Pico мониторинг ввода в настройках macOS, затем перезапусти приложение."
            return
        }
        guard selectedState == .working else {
            keyboardMonitor.stop()
            keyboardMessage = "Выбери режим «Работа»."
            return
        }
        guard isVisible else {
            keyboardMonitor.stop()
            keyboardMessage = "Покажи Pico, чтобы включить реакцию на клавиши."
            return
        }
        guard animationEnabled, !reduceMotion else {
            keyboardMonitor.stop()
            keyboardMessage = reduceMotion
                ? "macOS уменьшает движение: анимация отключена."
                : "Анимация на паузе. Нажми «Продолжить»."
            return
        }
        keyboardMessage = keyboardMonitor.start()
            ? "Готов: начни печатать в любом приложении."
            : "Не удалось подключиться. Проверь разрешение и перезапусти Pico."
    }

    func reconnectKeyboard() {
        keyboardMonitor.stop()
        receivedKeyPresses = 0
        if keyboardSyncEnabled && !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
        refreshKeyboardMonitoring()
    }

    func previewKeystroke() {
        scene?.registerKeystroke()
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
        let companionScene = CompanionScene(size: size)
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

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
        onDragEnded?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
