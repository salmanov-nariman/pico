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
        case .working: return "Увлечённо печатает и иногда задумывается."
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
    private let character = SKSpriteNode()
    private var outgoing: SKSpriteNode?
    private var clips: [CompanionState: SpriteClip] = [:]
    private var state: CompanionState = .idle
    private var animated = true
    private var playbackRate: Double = 1
    private let steam = SKNode()
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
        rig.addChild(character)
        steam.zPosition = 6
        rig.addChild(steam)
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
        rig.speed = enabled ? CGFloat(playbackRate) : 0
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
        steam.removeAllActions()
        steam.removeAllChildren()
        cupRaised = false

        if transition, let previousTexture = character.texture {
            let previous = SKSpriteNode(texture: previousTexture, size: character.size)
            previous.anchorPoint = character.anchorPoint
            previous.alpha = character.alpha
            previous.warpGeometry = character.warpGeometry
            rig.addChild(previous)
            outgoing = previous
            let fade = SKAction.fadeOut(withDuration: 0.22)
            fade.timingMode = .easeInEaseOut
            previous.run(.sequence([fade, .removeFromParent()]))
            character.alpha = 0
            let reveal = SKAction.fadeIn(withDuration: 0.22)
            reveal.timingMode = .easeInEaseOut
            character.run(reveal, withKey: "transition")
        } else {
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
            // Use the scene's animation clock, independent of keyboard access.
            let keystroke = SKAction.sequence([
                .setTexture(clip.frames[1]), .wait(forDuration: 0.12),
                .setTexture(clip.frames[0]), .wait(forDuration: 0.14)
            ])
            cycle = .sequence([
                .repeat(keystroke, count: 7),
                .wait(forDuration: 0.45, withRange: 0.3),
                .repeat(keystroke, count: 4),
                .wait(forDuration: 1.1, withRange: 0.6)
            ])
        case .sleeping:
            cycle = sleepingBreath()
        }
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
