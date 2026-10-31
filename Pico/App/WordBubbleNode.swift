import SpriteKit

/// A bounded, ephemeral word preview. No transcript is retained.
final class WordBubbleNode: SKNode {
    private var word = ""
    private var draft: SKNode?
    private let flying = SKNode()

    override init() {
        super.init()
        addChild(flying)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func receive(_ input: WordInput) {
        switch input {
        case .append(let text):
            for character in text {
                if character.isWhitespace {
                    commit()
                } else {
                    if word.count >= 24 { commit() }
                    word.append(character)
                }
            }
            renderDraft()
        case .backspace:
            if !word.isEmpty { word.removeLast() }
            renderDraft()
        case .commit: commit()
        case .clear: clear()
        }
        removeAction(forKey: "expiry")
        if !word.isEmpty {
            run(.sequence([.wait(forDuration: 4), .run { [weak self] in self?.clear() }]),
                withKey: "expiry")
        }
    }

    func clear() {
        removeAllActions()
        word = ""
        draft?.removeFromParent()
        draft = nil
        flying.removeAllChildren()
    }

    private func renderDraft() {
        draft?.removeFromParent()
        draft = nil
        guard !word.isEmpty else { return }
        let bubble = makeBubble(word)
        addChild(bubble)
        draft = bubble
    }

    private func commit() {
        guard !word.isEmpty else { return }
        let bubble = makeBubble(word)
        word = ""
        draft?.removeFromParent()
        draft = nil
        // Bound visible text during rapid typing.
        if flying.children.count >= 3 { flying.children.first?.removeFromParent() }
        flying.addChild(bubble)
        let rise = SKAction.moveBy(x: 0, y: 58, duration: 1.25)
        rise.timingMode = .easeOut
        let fade = SKAction.sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 1)])
        bubble.run(.sequence([.group([rise, fade]), .removeFromParent()]))
    }

    private func makeBubble(_ text: String) -> SKNode {
        let node = SKNode()
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 12
        label.fontColor = SKColor(red: 0.72, green: 0.92, blue: 1, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        // Fit above the laptop without clipping at the overlay's right edge.
        if label.frame.width > 78 { label.setScale(78 / label.frame.width) }
        let background = SKShapeNode(rectOf: CGSize(width: label.frame.width + 12, height: 23), cornerRadius: 7)
        background.fillColor = SKColor(red: 0.08, green: 0.11, blue: 0.17, alpha: 0.76)
        background.strokeColor = SKColor(white: 1, alpha: 0.14)
        label.zPosition = 1
        node.addChild(background)
        node.addChild(label)
        return node
    }
}
