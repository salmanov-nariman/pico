import SpriteKit

enum CompanionCharacter: String, CaseIterable, Identifiable {
    case developer, cat

    var id: String { rawValue }
    var title: String { self == .developer ? "Программист" : "Кот" }
    var assetPrefix: String { self == .developer ? "Developer" : "Cat" }

    func assetName(for state: CompanionState) -> String {
        let suffix: String
        switch state {
        case .idle: suffix = "Idle"
        case .working: suffix = "Working"
        case .sleeping: suffix = "Sleeping"
        }
        return "\(assetPrefix)\(suffix)Atlas"
    }
}

enum CompanionState: String, CaseIterable, Identifiable {
    case idle, working, sleeping

    var id: String { rawValue }
    var title: String {
        switch self {
        case .idle: return "Отдых"
        case .working: return "Работа"
        case .sleeping: return "Сон"
        }
    }
    var symbol: String {
        switch self {
        case .idle: return "cup.and.saucer"
        case .working: return "laptopcomputer"
        case .sleeping: return "moon.zzz"
        }
    }
    var subtitle: String {
        switch self {
        case .idle: return "Закрыл ноутбук и наслаждается кофе."
        case .working: return "Пишет код за своим ноутбуком."
        case .sleeping: return "Дремлет, положив голову на руки."
        }
    }
}

/// Loads equally sized horizontal frames from a bundled asset catalog image.
private struct SpriteClip {
    let frames: [SKTexture]

    init(assetName: String, frameCount: Int = 2) {
        let atlas = SKTexture(imageNamed: assetName)
        frames = (0..<frameCount).map { index in
            let width = 1 / CGFloat(frameCount)
            let texture = SKTexture(
                rect: CGRect(x: CGFloat(index) * width, y: 0, width: width, height: 1),
                in: atlas
            )
            texture.filteringMode = .nearest
            return texture
        }
    }
}

final class CompanionScene: SKScene {
    private let rig = SKNode()
    private var character = SKSpriteNode()
    private var outgoing: SKSpriteNode?
    private var clips: [CompanionState: SpriteClip] = [:]
    private var greetingClip: SpriteClip?
    private var successClip: SpriteClip?
    private var celebration: SKSpriteNode?
    private var state: CompanionState = .idle
    private var selectedCharacter: CompanionCharacter = .developer
    private var animated = true
    private var keyboardSyncEnabled = true
    private var playbackRate: Double = 1
    private let steam = SKNode()
    private let words = WordBubbleNode()
    private let greeting = SKNode()
    private let developerNotice = SKNode()
    private lazy var handRest = handPose(near: 0, far: 0)
    private lazy var handFirst = handPose(near: 0.012, far: 0)
    private lazy var handSecond = handPose(near: 0, far: 0.012)
    private var cupRaised = false

    override func didMove(to view: SKView) {
        guard rig.parent == nil else { return }
        backgroundColor = .clear
        scaleMode = .resizeFill
        loadClips()
        rig.position = CGPoint(x: size.width / 2, y: 5)
        character.size = CGSize(width: 190, height: 190)
        character.anchorPoint = CGPoint(x: 0.5, y: 0)
        steam.zPosition = 6
        rig.addChild(steam)
        words.zPosition = 10
        rig.addChild(words)
        greeting.position = CGPoint(x: size.width / 2, y: 181)
        greeting.zPosition = 20
        addChild(greeting)
        developerNotice.position = CGPoint(x: size.width / 2, y: 153)
        developerNotice.zPosition = 30
        addChild(developerNotice)
        addChild(rig)
        applyState(transition: false)
    }

    func setCharacter(_ selection: CompanionCharacter) {
        guard selection != selectedCharacter else { return }
        selectedCharacter = selection
        // Selection can be restored before SpriteKit presents the scene.
        guard rig.parent != nil else { return }
        clearDeveloperNotice()
        loadClips()
        applyState(transition: false)
    }

    private func loadClips() {
        for state in CompanionState.allCases {
            clips[state] = SpriteClip(assetName: selectedCharacter.assetName(for: state))
        }
        greetingClip = SpriteClip(assetName: "\(selectedCharacter.assetPrefix)GreetingAtlas")
        successClip = SpriteClip(assetName: "\(selectedCharacter.assetPrefix)SuccessAtlas")
        handRest = handPose(near: 0, far: 0)
        handFirst = handPose(near: 0.012, far: 0)
        handSecond = handPose(near: 0, far: 0.012)
        words.position = CGPoint(x: 51, y: selectedCharacter == .cat ? 79 : 65)
    }

    func setState(_ newState: CompanionState) {
        guard newState != state else { return }
        state = newState
        applyState(transition: animated && !isPaused)
    }

    func setAnimated(_ enabled: Bool) {
        animated = enabled
        if !enabled { endCelebration() }
        if !enabled { stopTyping(); clearWords() }
        rig.speed = enabled ? CGFloat(playbackRate) : 0
    }

    func setKeyboardSync(_ enabled: Bool) {
        guard keyboardSyncEnabled != enabled else { return }
        keyboardSyncEnabled = enabled
        clearWords()
        if state == .working { applyState(transition: false) }
    }

    func registerKeystroke() {
        guard keyboardSyncEnabled, state == .working, animated, !isPaused,
              clips[.working] != nil,
              character.action(forKey: "keypress") == nil,
              character.action(forKey: "greeting") == nil else { return }
        // Do not queue bursts: the hands settle as soon as typing stops.
        character.run(typingBurst(), withKey: "keypress")
    }

    func stopTyping() {
        character.removeAction(forKey: "keypress")
        character.removeAction(forKey: "greeting")
        if keyboardSyncEnabled, state == .working, let clip = clips[.working] {
            character.texture = clip.frames[0]
            character.warpGeometry = handRest
        }
    }

    func receiveWordInput(_ input: WordInput) {
        guard keyboardSyncEnabled, state == .working, animated, !isPaused else { return }
        words.receive(input)
    }

    func clearWords() { words.clear() }

    func clearDeveloperNotice() {
        developerNotice.removeAllChildren()
        endCelebration()
    }

    private func endCelebration() {
        celebration?.removeAllActions()
        celebration?.removeFromParent()
        celebration = nil
        rig.isHidden = false
    }

    private func celebrateSuccess() {
        guard animated, !isPaused, let successClip else { return }
        endCelebration()
        greeting.removeAllChildren()
        let sprite = SKSpriteNode(texture: successClip.frames[0])
        sprite.size = character.size
        sprite.anchorPoint = character.anchorPoint
        sprite.position = rig.position
        sprite.zPosition = 5
        celebration = sprite
        rig.isHidden = true
        addChild(sprite)
        sprite.run(.sequence([
            .setTexture(successClip.frames[0]), .wait(forDuration: 0.18),
            .setTexture(successClip.frames[1]), .wait(forDuration: 1.4),
            .run { [weak self] in self?.endCelebration() }
        ]))
    }

    func showDeveloperEvent(_ event: DeveloperEvent) {
        guard !isPaused else { return }
        clearDeveloperNotice()
        if event.isSuccess { celebrateSuccess() }
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = event.title
        label.fontSize = 12
        label.verticalAlignmentMode = .center
        label.fontColor = event.isSuccess ? SKColor(red: 0.65, green: 1, blue: 0.77, alpha: 1)
            : event.isFailure ? SKColor(red: 1, green: 0.65, blue: 0.63, alpha: 1)
            : SKColor(red: 0.72, green: 0.9, blue: 1, alpha: 1)
        if label.frame.width > 170 { label.setScale(170 / label.frame.width) }
        let bubble = SKShapeNode(rectOf: CGSize(width: label.frame.width + 16, height: 28), cornerRadius: 8)
        bubble.fillColor = SKColor(white: 0.06, alpha: 0.9)
        bubble.strokeColor = SKColor(white: 1, alpha: 0.15)
        label.zPosition = 1
        bubble.addChild(label)
        developerNotice.addChild(bubble)
        if animated {
            bubble.alpha = 0
            bubble.run(.sequence([.fadeIn(withDuration: 0.15), .wait(forDuration: 4),
                                  .fadeOut(withDuration: 0.25), .removeFromParent()]))
        } else {
            bubble.run(.sequence([.wait(forDuration: 4), .removeFromParent()]))
        }
    }

    func greet() {
        guard !isPaused, celebration == nil, greeting.children.isEmpty,
              character.action(forKey: "restGreeting") == nil else { return }
        if state == .sleeping {
            showSleepReaction()
            return
        }
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = state == .working ? "…" : "Привет!"
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        let bubble = SKShapeNode(rectOf: CGSize(width: state == .working ? 40 : 78, height: 24), cornerRadius: 8)
        bubble.fillColor = SKColor(red: 0.08, green: 0.11, blue: 0.17, alpha: 0.86)
        bubble.strokeColor = SKColor(white: 1, alpha: 0.15)
        label.zPosition = 1
        bubble.addChild(label)
        greeting.addChild(bubble)
        // This clock is independent of playback speed and animation pause.
        // Reduce Motion shows the same message without an animated transition.
        if animated {
            bubble.alpha = 0
            bubble.run(.sequence([.fadeIn(withDuration: 0.12), .wait(forDuration: 1.2),
                                  .fadeOut(withDuration: 0.2), .removeFromParent()]))
        } else {
            bubble.run(.sequence([.wait(forDuration: 1.5), .removeFromParent()]))
        }
        guard state == .idle, animated, let greetingClip, let idleClip = clips[.idle] else { return }
        character.removeAction(forKey: "frames")
        // Interrupt even a sip: lower the cup and greet with the free hand.
        moveCup(raised: false)
        let wave = SKAction.sequence([
            .setTexture(greetingClip.frames[0]), .wait(forDuration: 0.18),
            .setTexture(greetingClip.frames[1]), .wait(forDuration: 0.18)
        ])
        character.run(.sequence([
            .repeat(wave, count: 3),
            .setTexture(idleClip.frames[0]),
            .run { [weak self] in
                guard let self, self.state == .idle else { return }
                self.character.run(.repeatForever(self.coffeeCycle()), withKey: "frames")
            }
        ]), withKey: "restGreeting")
    }

    private func showSleepReaction() {
        let cloud = SKNode()
        greeting.addChild(cloud)
        for index in 0..<3 {
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = "Z"
            label.fontSize = CGFloat(11 + index * 3)
            label.fontColor = SKColor(red: 0.65, green: 0.84, blue: 1, alpha: 1)
            label.position = CGPoint(x: -16 + CGFloat(index) * 15, y: -24 + CGFloat(index) * 5)
            cloud.addChild(label)
            if animated {
                label.alpha = 0
                label.run(.sequence([
                    .wait(forDuration: Double(index) * 0.25),
                    .group([
                        .moveBy(x: 5, y: 15, duration: 1.2),
                        .sequence([.fadeIn(withDuration: 0.2), .wait(forDuration: 0.5), .fadeOut(withDuration: 0.5)])
                    ])
                ]))
            }
        }
        cloud.run(.sequence([.wait(forDuration: 1.9), .removeFromParent()]))
    }

    private func coffeeSip() -> SKAction {
        guard let clip = clips[.idle] else { return .wait(forDuration: 0) }
        return .sequence([
            .run { [weak self] in self?.moveCup(raised: true) },
            .setTexture(clip.frames[1]), .wait(forDuration: 1.1),
            .run { [weak self] in self?.moveCup(raised: false) },
            .setTexture(clip.frames[0])
        ])
    }

    private func coffeeCycle() -> SKAction {
        .sequence([.wait(forDuration: 4.2, withRange: 1.5), coffeeSip()])
    }

    private func typingBurst() -> SKAction {
        guard let first = SKAction.warp(to: handFirst, duration: 0.07),
              let firstDown = SKAction.warp(to: handRest, duration: 0.06),
              let second = SKAction.warp(to: handSecond, duration: 0.07),
              let rest = SKAction.warp(to: handRest, duration: 0.06) else {
            return .wait(forDuration: 0.26)
        }
        for action in [first, firstDown, second, rest] { action.timingMode = .easeInEaseOut }
        return .sequence([first, firstDown, second, rest])
    }

    /// Compact deformation around each hand on the first working texture.
    /// Keeps the head, chair and laptop outside the moving regions.
    private func handPose(near: Float, far: Float) -> SKWarpGeometryGrid {
        // Concentrate vertices at the hands instead of tessellating the entire
        // sprite into 1,600 quads. Every hand pose uses identical topology.
        let isCat = selectedCharacter == .cat
        let xs: [Float] = isCat
            ? [0, 0.31, 0.42, 0.53, 0.59, 0.65, 1]
            : [0, 0.38, 0.475, 0.54, 0.57, 0.5825, 0.625, 1]
        let ys: [Float] = isCat
            ? [0, 0.15, 0.17, 0.22, 0.235, 0.29, 0.30, 1]
            : [0, 0.105, 0.17, 0.2275, 0.235, 0.285, 1]
        var source: [SIMD2<Float>] = []
        var destination: [SIMD2<Float>] = []
        func weight(_ x: Float, _ y: Float, left: Float, bottom: Float,
                    width: Float, height: Float) -> Float {
            let u = (x - left) / width
            let v = (y - bottom) / height
            guard u > 0, u < 1, v > 0, v < 1 else { return 0 }
            let envelope = sin(u * .pi) * sin(v * .pi)
            return envelope * envelope
        }
        for y in ys {
            for x in xs {
                let nearWeight = weight(x, y, left: isCat ? 0.31 : 0.38,
                                        bottom: isCat ? 0.15 : 0.105,
                                        width: isCat ? 0.22 : 0.19, height: isCat ? 0.14 : 0.13)
                let farWeight = weight(x, y, left: isCat ? 0.53 : 0.54, bottom: 0.17,
                                       width: isCat ? 0.12 : 0.085, height: isCat ? 0.13 : 0.115)
                source.append(SIMD2<Float>(x, y))
                destination.append(SIMD2<Float>(x, y + near * nearWeight + far * farWeight))
            }
        }
        return SKWarpGeometryGrid(columns: xs.count - 1, rows: ys.count - 1,
                                  sourcePositions: source, destinationPositions: destination)
    }

    func setPlaybackRate(_ rate: Double) {
        playbackRate = rate.isFinite ? min(max(rate, 0.5), 1.5) : 1
        rig.speed = animated ? CGFloat(playbackRate) : 0
    }

    private func applyState(transition: Bool) {
        guard let clip = clips[state] else { return }
        endCelebration()
        outgoing?.removeFromParent()
        outgoing = nil
        character.removeAllActions()
        let previous = character
        // Configure a fresh sprite before attaching it to the rendered tree.
        // Do not reuse a renderer mesh across unwarped/work/sleep topologies.
        character = SKSpriteNode()
        character.size = previous.size
        character.anchorPoint = previous.anchorPoint
        character.subdivisionLevels = 0
        steam.removeAllActions()
        steam.removeAllChildren()
        cupRaised = false
        greeting.removeAllChildren()
        clearWords()

        if transition, previous.parent != nil {
            outgoing = previous
            let fade = SKAction.fadeOut(withDuration: 0.22)
            fade.timingMode = .easeInEaseOut
            previous.run(.sequence([fade, .removeFromParent()]))
            character.alpha = 0
            let reveal = SKAction.fadeIn(withDuration: 0.22)
            reveal.timingMode = .easeInEaseOut
            character.run(reveal, withKey: "transition")
        } else {
            previous.removeFromParent()
            character.alpha = 1
        }

        character.warpGeometry = nil
        character.texture = clip.frames[0]
        let cycle: SKAction
        switch state {
        case .idle:
            steam.run(.repeatForever(.sequence([
                .run { [weak self] in self?.emitSteam() },
                .wait(forDuration: 0.7)
            ])))
            cycle = coffeeCycle()
        case .working:
            character.warpGeometry = handRest
            guard !keyboardSyncEnabled else {
                rig.addChild(character)
                return
            }
            // Use the scene's animation clock, independent of keyboard access.
            let keystroke = typingBurst()
            cycle = .sequence([
                .repeat(keystroke, count: 7),
                .wait(forDuration: 0.45, withRange: 0.3),
                .repeat(keystroke, count: 4),
                .wait(forDuration: 1.1, withRange: 0.6)
            ])
        case .sleeping:
            cycle = sleepingBreath()
        }
        rig.addChild(character)
        character.run(.repeatForever(cycle), withKey: "frames")
    }

    /// Deform only the central sleeve/torso region. Chair, head and laptop stay fixed.
    private func sleepingBreath() -> SKAction {
        let subdivisions = 24
        var source: [SIMD2<Float>] = []
        var destination: [SIMD2<Float>] = []
        for row in 0...subdivisions {
            for column in 0...subdivisions {
                let x = Float(column) / Float(subdivisions)
                let y = Float(row) / Float(subdivisions)
                let point = SIMD2<Float>(x, y)
                source.append(point)
                // Coordinates refer to the sleeping sprite, measured from bottom left.
                // Compact support prevents movement in surrounding furniture pixels.
                let isCat = selectedCharacter == .cat
                let u = (x - (isCat ? 0.12 : 0.20)) / (isCat ? 0.17 : 0.28)
                let v = (y - (isCat ? 0.24 : 0.17)) / (isCat ? 0.19 : 0.20)
                var lift: Float = 0
                if u > 0, u < 1, v > 0, v < 1 {
                    let envelope = sin(u * .pi) * sin(v * .pi)
                    lift = envelope * envelope * 0.004
                }
                destination.append(SIMD2<Float>(x, y + lift))
            }
        }
        let rest = SKWarpGeometryGrid(columns: subdivisions, rows: subdivisions,
                                      sourcePositions: source, destinationPositions: source)
        let expanded = SKWarpGeometryGrid(columns: subdivisions, rows: subdivisions,
                                          sourcePositions: source, destinationPositions: destination)
        character.warpGeometry = rest
        guard let inhale = SKAction.warp(to: expanded, duration: 2.2),
              let exhale = SKAction.warp(to: rest, duration: 2.6) else {
            return .wait(forDuration: 4.8)
        }
        inhale.timingMode = .easeInEaseOut
        exhale.timingMode = .easeInEaseOut
        return .sequence([inhale, exhale, .wait(forDuration: 0.3)])
    }

    private func moveCup(raised: Bool) {
        cupRaised = raised
        steam.removeAllChildren()
    }

    private func emitSteam() {
        guard state == .idle, animated, steam.children.count < 3 else { return }
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: 1, y: 11),
                      control1: CGPoint(x: -4, y: 4), control2: CGPoint(x: 5, y: 7))
        let wisp = SKShapeNode(path: path)
        wisp.strokeColor = SKColor(white: 0.9, alpha: 1)
        wisp.lineWidth = 1.1
        wisp.alpha = 0
        if selectedCharacter == .cat {
            wisp.position = cupRaised ? CGPoint(x: 13, y: 106) : CGPoint(x: 9, y: 86)
        } else {
            wisp.position = cupRaised ? CGPoint(x: 13, y: 73) : CGPoint(x: 0, y: 52)
        }
        steam.addChild(wisp)
        let rise = SKAction.moveBy(x: -3, y: 13, duration: 1.7)
        rise.timingMode = .easeOut
        let opacity = SKAction.sequence([
            .fadeAlpha(to: 0.28, duration: 0.35),
            .fadeOut(withDuration: 1.35)
        ])
        wisp.run(.sequence([.group([rise, opacity]), .removeFromParent()]))
    }

}
