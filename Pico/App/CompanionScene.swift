import SpriteKit

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
    var assetName: String {
        switch self {
        case .idle: return "DeveloperIdleAtlas"
        case .working: return "DeveloperWorkingAtlas"
        case .sleeping: return "DeveloperSleepingAtlas"
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
    private var state: CompanionState = .idle
    private var animated = true
    private var keyboardSyncEnabled = true
    private var playbackRate: Double = 1
    private let steam = SKNode()
    private let words = WordBubbleNode()
    private lazy var handRest = handPose(near: 0, far: 0)
    private lazy var handFirst = handPose(near: 0.012, far: 0)
    private lazy var handSecond = handPose(near: 0, far: 0.012)
    private var cupRaised = false

    override func didMove(to view: SKView) {
        guard rig.parent == nil else { return }
        backgroundColor = .clear
        scaleMode = .resizeFill
        for state in CompanionState.allCases {
            clips[state] = SpriteClip(assetName: state.assetName)
        }
        rig.position = CGPoint(x: size.width / 2, y: 5)
        character.size = CGSize(width: 190, height: 190)
        character.anchorPoint = CGPoint(x: 0.5, y: 0)
        steam.zPosition = 6
        rig.addChild(steam)
        words.position = CGPoint(x: 51, y: 65)
        words.zPosition = 10
        rig.addChild(words)
        addChild(rig)
        applyState(transition: false)
    }

    func setState(_ newState: CompanionState) {
        guard newState != state else { return }
        state = newState
        applyState(transition: animated && !isPaused)
    }

    func setAnimated(_ enabled: Bool) {
        animated = enabled
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
              character.action(forKey: "keypress") == nil else { return }
        // Do not queue bursts: the hands settle as soon as typing stops.
        character.run(typingBurst(), withKey: "keypress")
    }

    func stopTyping() {
        character.removeAction(forKey: "keypress")
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
        let xs: [Float] = [0, 0.38, 0.475, 0.54, 0.57, 0.5825, 0.625, 1]
        let ys: [Float] = [0, 0.105, 0.17, 0.2275, 0.235, 0.285, 1]
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
                let nearWeight = weight(x, y, left: 0.38, bottom: 0.105, width: 0.19, height: 0.13)
                let farWeight = weight(x, y, left: 0.54, bottom: 0.17, width: 0.085, height: 0.115)
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
            cycle = .sequence([
                .wait(forDuration: 4.2, withRange: 1.5),
                .run { [weak self] in self?.moveCup(raised: true) },
                .setTexture(clip.frames[1]), .wait(forDuration: 1.1),
                .run { [weak self] in self?.moveCup(raised: false) },
                .setTexture(clip.frames[0])
            ])
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
                let u = (x - 0.20) / 0.28
                let v = (y - 0.17) / 0.20
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
        wisp.position = cupRaised ? CGPoint(x: 13, y: 73) : CGPoint(x: 0, y: 52)
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
