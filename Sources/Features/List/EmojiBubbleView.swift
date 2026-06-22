import SwiftUI
import SpriteKit
@preconcurrency import CoreMotion
import CoreHaptics

struct EmojiBubbleView: View {
    let emojis: [String]
    let palette: DiaryPalette
    @State private var sceneID = UUID()

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: makeScene(size: geo.size))
                .id(sceneID)
                .cornerRadius(12)
        }
        .onChange(of: emojis) { sceneID = UUID() }
        .onChange(of: palette.paper) { sceneID = UUID() }
    }

    private func makeScene(size: CGSize) -> SKScene {
        EmojiBubbleScene(size: size, emojis: emojis, bgColor: UIColor(palette.card))
    }
}

// MARK: - SKScene

final class EmojiBubbleScene: SKScene, SKPhysicsContactDelegate {
    private let emojis: [String]
    private let motionManager = CMMotionManager()
    private var previousGravity: CGVector = .zero
    private let gravityThreshold: CGFloat = 0.02
    private var hapticEngine: CHHapticEngine?

    private struct Cat {
        static let emoji: UInt32 = 0x1 << 0
        static let wall:  UInt32 = 0x1 << 1
    }

    init(size: CGSize, emojis: [String], bgColor: UIColor) {
        self.emojis = emojis
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = bgColor
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))
        physicsBody?.categoryBitMask = Cat.wall
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = .zero
        setupEmojis()
        startMotion()
        prepareHaptics()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupEmojis() {
        let emojiSize: CGFloat = 26
        var placed: [CGPoint] = []
        for emoji in emojis {
            let label = SKLabelNode(text: emoji)
            label.fontSize = emojiSize
            label.verticalAlignmentMode   = .center
            label.horizontalAlignmentMode = .center

            var pos: CGPoint
            var tries = 0
            repeat {
                pos = CGPoint(
                    x: CGFloat.random(in: emojiSize...(size.width  - emojiSize)),
                    y: CGFloat.random(in: emojiSize...(size.height - emojiSize))
                )
                tries += 1
            } while placed.contains(where: { $0.distance(to: pos) < emojiSize * 1.5 }) && tries < 100

            placed.append(pos)
            label.position = pos
            label.physicsBody = SKPhysicsBody(circleOfRadius: emojiSize / 2)
            label.physicsBody?.restitution     = 0.6
            label.physicsBody?.friction        = 0.5
            label.physicsBody?.linearDamping   = 1.0
            label.physicsBody?.allowsRotation  = false
            label.physicsBody?.categoryBitMask    = Cat.emoji
            label.physicsBody?.contactTestBitMask = Cat.emoji | Cat.wall
            addChild(label)
        }
    }

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let g = motion?.gravity else { return }
            let scale: CGFloat = 9.8
            let next = CGVector(dx: g.x * scale, dy: g.y * scale)
            let dx = abs(next.dx - previousGravity.dx)
            let dy = abs(next.dy - previousGravity.dy)
            if dx > gravityThreshold || dy > gravityThreshold {
                physicsWorld.gravity = next
                previousGravity = next
            }
        }
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? hapticEngine?.start()
    }

    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        let cats  = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        let speed = max(contact.bodyA.velocity.length(), contact.bodyB.velocity.length())
        guard (cats == (Cat.emoji | Cat.emoji) || cats == (Cat.emoji | Cat.wall)),
              speed > 80 else { return }
        Task { @MainActor [weak self] in self?.fireHaptic() }
    }

    @MainActor
    private func fireHaptic() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []),
              let player  = try? hapticEngine?.makePlayer(with: pattern) else { return }
        try? player.start(atTime: 0)
    }

    deinit { motionManager.stopDeviceMotionUpdates() }
}

// MARK: - helpers

private extension CGVector {
    func length() -> CGFloat { sqrt(dx*dx + dy*dy) }
}

private extension CGPoint {
    func distance(to p: CGPoint) -> CGFloat { hypot(x - p.x, y - p.y) }
}
