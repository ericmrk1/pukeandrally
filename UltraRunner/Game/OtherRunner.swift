import SpriteKit

/// Visual-only NPC runner with configurable outfit colors. No physics body — they never block
/// the player; tap to target and pass them to see "On Your Left" / "Stay Hard" / "Who's gonna carry the boats".
class OtherRunner: SKNode {

    private var body: SKShapeNode!
    private var head: SKShapeNode!
    private var leftArm: SKShapeNode!
    private var rightArm: SKShapeNode!
    private var leftLeg: SKShapeNode!
    private var rightLeg: SKShapeNode!
    private var shadow: SKShapeNode!
    private var visor: SKShapeNode!

    struct OutfitColors {
        var shirt: UIColor
        var shirtStroke: UIColor
        var legs: UIColor
        var visor: UIColor
    }

    static let outfitPresets: [OutfitColors] = [
        OutfitColors(shirt: UIColor(red:0.2,green:0.6,blue:0.35,alpha:1), shirtStroke: UIColor(red:0.1,green:0.4,blue:0.2,alpha:1), legs: UIColor(red:0.15,green:0.35,blue:0.5,alpha:1), visor: UIColor(red:0.2,green:0.6,blue:0.35,alpha:1)),
        OutfitColors(shirt: UIColor(red:0.35,green:0.25,blue:0.7,alpha:1), shirtStroke: UIColor(red:0.2,green:0.15,blue:0.5,alpha:1), legs: UIColor(red:0.5,green:0.2,blue:0.6,alpha:1), visor: UIColor(red:0.35,green:0.25,blue:0.7,alpha:1)),
        OutfitColors(shirt: UIColor(red:0.1,green:0.5,blue:0.55,alpha:1), shirtStroke: UIColor(red:0.05,green:0.35,blue:0.4,alpha:1), legs: UIColor(red:0.2,green:0.45,blue:0.5,alpha:1), visor: UIColor(red:0.1,green:0.5,blue:0.55,alpha:1)),
        OutfitColors(shirt: UIColor(red:0.85,green:0.45,blue:0.1,alpha:1), shirtStroke: UIColor(red:0.6,green:0.25,blue:0.05,alpha:1), legs: UIColor(red:0.3,green:0.2,blue:0.15,alpha:1), visor: UIColor(red:0.85,green:0.45,blue:0.1,alpha:1)),
        OutfitColors(shirt: UIColor(red:0.7,green:0.2,blue:0.5,alpha:1), shirtStroke: UIColor(red:0.5,green:0.1,blue:0.35,alpha:1), legs: UIColor(red:0.4,green:0.15,blue:0.35,alpha:1), visor: UIColor(red:0.7,green:0.2,blue:0.5,alpha:1)),
        OutfitColors(shirt: UIColor(red:0.25,green:0.4,blue:0.7,alpha:1), shirtStroke: UIColor(red:0.15,green:0.25,blue:0.5,alpha:1), legs: UIColor(red:0.2,green:0.35,blue:0.6,alpha:1), visor: UIColor(red:0.25,green:0.4,blue:0.7,alpha:1)),
        OutfitColors(shirt: UIColor(red:0.5,green:0.35,blue:0.15,alpha:1), shirtStroke: UIColor(red:0.35,green:0.22,blue:0.08,alpha:1), legs: UIColor(red:0.4,green:0.5,blue:0.2,alpha:1), visor: UIColor(red:0.5,green:0.35,blue:0.15,alpha:1)),
    ]

    init(outfit: OutfitColors? = nil) {
        super.init()
        name = "otherRunner"
        let colors = outfit ?? OtherRunner.outfitPresets.randomElement()!
        buildRunner(colors: colors)
        startAnimation()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildRunner(colors: OutfitColors) {
        shadow = SKShapeNode(ellipseOf: CGSize(width: 36, height: 10))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.3)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -28)
        addChild(shadow)

        leftLeg = SKShapeNode(rectOf: CGSize(width: 8, height: 24), cornerRadius: 3)
        leftLeg.fillColor = colors.legs
        leftLeg.strokeColor = .clear
        leftLeg.position = CGPoint(x: -8, y: -18)
        addChild(leftLeg)

        rightLeg = SKShapeNode(rectOf: CGSize(width: 8, height: 24), cornerRadius: 3)
        rightLeg.fillColor = colors.legs
        rightLeg.strokeColor = .clear
        rightLeg.position = CGPoint(x: 8, y: -18)
        addChild(rightLeg)

        body = SKShapeNode(rectOf: CGSize(width: 24, height: 28), cornerRadius: 5)
        body.fillColor = colors.shirt
        body.strokeColor = colors.shirtStroke
        body.lineWidth = 1.5
        body.position = CGPoint(x: 0, y: 0)
        addChild(body)

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

        head = SKShapeNode(circleOfRadius: 14)
        head.fillColor = UIColor(red:0.9,green:0.72,blue:0.55,alpha:1)
        head.strokeColor = UIColor(red:0.7,green:0.5,blue:0.35,alpha:1)
        head.lineWidth = 1.5
        head.position = CGPoint(x: 0, y: 22)
        addChild(head)

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

        visor = SKShapeNode(rectOf: CGSize(width: 26, height: 8), cornerRadius: 2)
        visor.fillColor = colors.visor
        visor.strokeColor = .clear
        visor.position = CGPoint(x: 0, y: 12)
        head.addChild(visor)
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
        leftLeg.zRotation = angle
        rightLeg.zRotation = -angle
        leftArm.zRotation = -angle * 0.6
        rightArm.zRotation = angle * 0.6
        body.position.y = sin(phase * .pi * 4 * 3) * 2
    }
}
