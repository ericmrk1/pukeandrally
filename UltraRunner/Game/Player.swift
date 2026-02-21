import SpriteKit

enum PlayerState {
    case running, sprinting, walking, hiking, jumping, celebration
}

class Player: SKNode {

    var body: SKShapeNode!
    var head: SKShapeNode!
    var leftArm: SKShapeNode!
    var rightArm: SKShapeNode!
    var leftLeg: SKShapeNode!
    var rightLeg: SKShapeNode!
    var shadow: SKShapeNode!
    var trail: SKEmitterNode?

    var state: PlayerState = .running {
        didSet { if oldValue != state { updateAnimation() } }
    }

    private var legAngle: CGFloat = 0
    private var armAngle: CGFloat = 0
    private var animTimer: Timer?
    private var bouncePhase: CGFloat = 0

    override init() {
        super.init()
        buildPlayer()
        startAnimation()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildPlayer() {
        // Shadow
        shadow = SKShapeNode(ellipseOf: CGSize(width: 36, height: 10))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.3)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -28)
        addChild(shadow)

        // Legs
        leftLeg = SKShapeNode(rectOf: CGSize(width: 8, height: 24), cornerRadius: 3)
        leftLeg.fillColor = UIColor(red:0.2,green:0.4,blue:0.8,alpha:1)
        leftLeg.strokeColor = .clear
        leftLeg.position = CGPoint(x: -8, y: -18)
        addChild(leftLeg)

        rightLeg = SKShapeNode(rectOf: CGSize(width: 8, height: 24), cornerRadius: 3)
        rightLeg.fillColor = UIColor(red:0.2,green:0.4,blue:0.8,alpha:1)
        rightLeg.strokeColor = .clear
        rightLeg.position = CGPoint(x: 8, y: -18)
        addChild(rightLeg)

        // Body
        body = SKShapeNode(rectOf: CGSize(width: 24, height: 28), cornerRadius: 5)
        body.fillColor = UIColor(red:0.9,green:0.3,blue:0.2,alpha:1)
        body.strokeColor = UIColor(red:0.7,green:0.1,blue:0.05,alpha:1)
        body.lineWidth = 1.5
        body.position = CGPoint(x: 0, y: 0)
        addChild(body)

        // Arms
        leftArm = SKShapeNode(rectOf: CGSize(width: 7, height: 20), cornerRadius: 3)
        leftArm.fillColor = UIColor(red:0.85,green:0.65,blue:0.5,alpha:1)
        leftArm.strokeColor = .clear
        leftArm.position = CGPoint(x: -16, y: 4)
        addChild(leftArm)

        rightArm = SKShapeNode(rectOf: CGSize(width: 7, height: 20), cornerRadius: 3)
        rightArm.fillColor = UIColor(red:0.85,green:0.65,blue:0.5,alpha:1)
        rightArm.strokeColor = .clear
        rightArm.position = CGPoint(x: 16, y: 4)
        addChild(rightArm)

        // Head
        head = SKShapeNode(circleOfRadius: 14)
        head.fillColor = UIColor(red:0.9,green:0.72,blue:0.55,alpha:1)
        head.strokeColor = UIColor(red:0.7,green:0.5,blue:0.35,alpha:1)
        head.lineWidth = 1.5
        head.position = CGPoint(x: 0, y: 22)
        addChild(head)

        // Eyes
        let leftEye = SKShapeNode(circleOfRadius: 3)
        leftEye.fillColor = UIColor(red:0.15,green:0.1,blue:0.4,alpha:1)
        leftEye.strokeColor = .clear
        leftEye.position = CGPoint(x: -5, y: 3)
        head.addChild(leftEye)

        let rightEye = SKShapeNode(circleOfRadius: 3)
        rightEye.fillColor = UIColor(red:0.15,green:0.1,blue:0.4,alpha:1)
        rightEye.strokeColor = .clear
        rightEye.position = CGPoint(x: 5, y: 3)
        head.addChild(rightEye)

        // Visor / hat
        let visor = SKShapeNode(rectOf: CGSize(width: 26, height: 8), cornerRadius: 2)
        visor.fillColor = UIColor(red:0.9,green:0.3,blue:0.2,alpha:1)
        visor.strokeColor = .clear
        visor.position = CGPoint(x: 0, y: 12)
        head.addChild(visor)

        // Physics body
        let physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 28, height: 55))
        physicsBody.isDynamic = true
        physicsBody.allowsRotation = false
        physicsBody.restitution = 0
        physicsBody.friction = 0.5
        physicsBody.linearDamping = 0.1
        physicsBody.categoryBitMask = PhysicsCategory.player
        physicsBody.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.obstacle | PhysicsCategory.pickup
        physicsBody.collisionBitMask = PhysicsCategory.ground | PhysicsCategory.obstacle
        self.physicsBody = physicsBody
    }

    private func startAnimation() {
        let anim = SKAction.repeatForever(
            SKAction.customAction(withDuration: 0.3) { [weak self] _, time in
                self?.animateLegs(phase: time)
            }
        )
        run(anim, withKey: "runAnim")
    }

    private func animateLegs(phase: CGFloat) {
        let angle = sin(phase * .pi * 2 * 3) * 0.5
        switch state {
        case .running:
            leftLeg.zRotation = angle
            rightLeg.zRotation = -angle
            leftArm.zRotation = -angle * 0.6
            rightArm.zRotation = angle * 0.6
            body.position.y = sin(phase * .pi * 4 * 3) * 2
        case .sprinting:
            leftLeg.zRotation = angle * 1.4
            rightLeg.zRotation = -angle * 1.4
            leftArm.zRotation = -angle * 0.9
            rightArm.zRotation = angle * 0.9
            body.position.y = sin(phase * .pi * 5 * 3) * 2.5
        case .walking:
            leftLeg.zRotation = angle * 0.4
            rightLeg.zRotation = -angle * 0.4
            leftArm.zRotation = -angle * 0.3
            rightArm.zRotation = angle * 0.3
            body.position.y = sin(phase * .pi * 2 * 3) * 1
        case .hiking:
            leftLeg.zRotation = angle * 0.7
            rightLeg.zRotation = -angle * 0.7
            leftArm.zRotation = -angle * 0.5
            rightArm.zRotation = angle * 0.5
            body.position.y = sin(phase * .pi * 3 * 3) * 1.5
        case .jumping:
            leftLeg.zRotation = 0.4
            rightLeg.zRotation = -0.4
            leftArm.zRotation = -0.6
            rightArm.zRotation = 0.6
        case .celebration:
            leftLeg.zRotation = angle * 0.6
            rightLeg.zRotation = -angle * 0.6
            leftArm.zRotation = sin(phase * .pi * 4 * 3) * 0.8
            rightArm.zRotation = -sin(phase * .pi * 4 * 3) * 0.8
        }
    }

    private func updateAnimation() {
        switch state {
        case .sprinting:
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.05, duration: 0.1),
                SKAction.scale(to: 0.97, duration: 0.1)
            ])
            body.run(SKAction.repeatForever(pulse))
        default:
            body.removeAllActions()
            body.run(SKAction.scale(to: 1.0, duration: 0.1))
        }
    }

    func jump() {
        guard let pb = physicsBody else { return }
        pb.velocity = CGVector(dx: 0, dy: 0)
        pb.applyImpulse(CGVector(dx: GameConstants.jumpImpulseForward, dy: GameConstants.jumpImpulse))
        state = .jumping
    }

    func setColor(_ color: UIColor) {
        body.fillColor = color
    }
}
