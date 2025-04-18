//
//  EmojiBubbleView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2025/4/18.
//

import SwiftUI
import SpriteKit
import CoreMotion
import CoreHaptics

struct EmojiBubbleView: View {
    let width: CGFloat
    let height: CGFloat
    let emojis: [String]
    let emojiSize: CGFloat
    let gravityScale: CGFloat

    var scene: SKScene {
        EmojiBubbleScene(size: CGSize(width: width, height: height),
                         emojis: emojis,
                         emojiSize: emojiSize,
                         gravityScale: gravityScale)
    }

    var body: some View {
        SpriteView(scene: scene)
            .frame(width: width, height: height)
            .background(Color(.white))
            .cornerRadius(13)
//            .shadow(radius: 10)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
            .padding()
    }
}

class EmojiBubbleScene: SKScene, SKPhysicsContactDelegate {
    private let emojis: [String]
    private let emojiSize: CGFloat
    private let gravityScale: CGFloat
    private let motionManager = CMMotionManager()
    private var previousGravity: CGVector = .zero
    private let gravityThreshold: CGFloat = 0.02 // 重力变化阈值
    private var hapticEngine: CHHapticEngine?

    private struct PhysicsCategory {
        static let emoji: UInt32 = 0x1 << 0
        static let boundary: UInt32 = 0x1 << 1
    }

    init(size: CGSize, emojis: [String], emojiSize: CGFloat, gravityScale: CGFloat) {
        self.emojis = emojis
        self.emojiSize = emojiSize
        self.gravityScale = gravityScale
        super.init(size: size)
        self.scaleMode = .resizeFill
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))
        self.physicsBody?.categoryBitMask = PhysicsCategory.boundary
        self.physicsWorld.contactDelegate = self
        self.physicsWorld.gravity = .zero
        self.backgroundColor = .white // 设置背景颜色为白色

        setupEmojis()
        startDeviceMotionUpdates()
        prepareHaptics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupEmojis() {
        var positions: [CGPoint] = []

        for emoji in emojis {
            let label = SKLabelNode(text: emoji)
            label.fontSize = emojiSize
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center

            var position: CGPoint
            var attempts = 0
            repeat {
                position = CGPoint(x: CGFloat.random(in: emojiSize/2...(size.width - emojiSize/2)),
                                   y: CGFloat.random(in: emojiSize/2...(size.height - emojiSize/2)))
                attempts += 1
            } while positions.contains(where: { $0.distance(to: position) < emojiSize }) && attempts < 100

            positions.append(position)
            label.position = position

            label.physicsBody = SKPhysicsBody(circleOfRadius: emojiSize / 2)
            label.physicsBody?.restitution = 0.6    // 弹性系数：0.0（无弹性）到 1.0（完全弹性）。值越高，碰撞后反弹越强。
            label.physicsBody?.friction = 0.2       // 摩擦系数：0.0（无摩擦）到 1.0（最大摩擦）。值越高，滑动时阻力越大。
            label.physicsBody?.linearDamping = 1.0  // 线性阻尼：0.0（无阻力）到 1.0（最大阻力）。值越高，物体移动时减速越快。
            label.physicsBody?.allowsRotation = true
            label.physicsBody?.categoryBitMask = PhysicsCategory.emoji
            label.physicsBody?.contactTestBitMask = PhysicsCategory.emoji | PhysicsCategory.boundary
            addChild(label)
        }
    }

    private func startDeviceMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let gravity = motion?.gravity else { return }
            let newGravity = CGVector(dx: gravity.x * self.gravityScale,
                                      dy: gravity.y * self.gravityScale)
            // 计算当前重力与之前重力的差值
            let deltaX = abs(newGravity.dx - self.previousGravity.dx)
            let deltaY = abs(newGravity.dy - self.previousGravity.dy)
            // 如果差值超过阈值，则更新物理世界的重力
            if deltaX > self.gravityThreshold || deltaY > self.gravityThreshold {
                self.physicsWorld.gravity = newGravity
                self.previousGravity = newGravity
            }
        }
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine Creation Error: \(error)")
        }
    }

    private func playHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        /*在 Core Haptics 框架中，intensity 和 sharpness 是两个关键参数，用于定义触觉反馈的感觉。它们的取值范围均为 0.0 到 1.0：
            •    intensity（强度）：表示振动的幅度或强度。0.0 表示最弱的振动，1.0 表示最强的振动。
            •    sharpness（锐度）：表示振动的“清晰度”或“尖锐度”。0.0 表示柔和、低频的感觉，1.0 表示清晰、尖锐的感觉。*/
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensity, sharpness],
                                  relativeTime: 0)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        // 计算两个碰撞体的类别组合
        let categories = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        // 如果是表情与表情或表情与边界的碰撞
        if categories == (PhysicsCategory.emoji | PhysicsCategory.emoji) ||
            categories == (PhysicsCategory.emoji | PhysicsCategory.boundary) {
            
            // 获取两个物体的速度大小
            let velocityA = contact.bodyA.velocity.length()
            let velocityB = contact.bodyB.velocity.length()
            
            // 设置触发触觉反馈的最小速度阈值
            let minVelocity: CGFloat = 80.0

            // 如果任一物体的速度超过阈值，则触发触觉反馈
            if velocityA > minVelocity || velocityB > minVelocity {
                playHaptic()
            }
        }
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}

extension CGVector {
    func length() -> CGFloat {
        return sqrt(dx*dx + dy*dy)
    }
}
extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return hypot(self.x - point.x, self.y - point.y)
    }
}
