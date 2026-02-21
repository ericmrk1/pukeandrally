import SpriteKit

class HUDNode: SKNode {

    private var energyBar: SKShapeNode!
    private var energyFill: SKShapeNode!
    private var energyLabel: SKLabelNode!
    private var scoreLabel: SKLabelNode!
    private var distanceLabel: SKLabelNode!
    private var aidStationLabel: SKLabelNode!
    private var speedLabel: SKLabelNode!
    private var energyIcon: SKLabelNode!
    private var stateLabel: SKLabelNode!
    private var dnfStrikesLabel: SKLabelNode!
    private var aidProgress: [SKShapeNode] = []
    private var screenSize: CGSize

    /// Vertical slots for messages so they stack above/below and don't overlap
    private static let messageSlotCount = 6
    private var messageSlotInUse: [Bool] = Array(repeating: false, count: 6)
    private let messageSlotSpacing: CGFloat = 48

    private var _score: Int = 0
    private var _energy: CGFloat = GameConstants.energyMax
    private var _distance: CGFloat = 0
    private var _aidStation: Int = 0
    private var _totalAid: Int = 5

    var score: Int {
        get { _score }
        set { _score = newValue; scoreLabel.text = "⭐ \(newValue)" }
    }
    var energy: CGFloat {
        get { _energy }
        set {
            _energy = max(0, min(newValue, GameConstants.energyMax))
            updateEnergyBar()
        }
    }

    /// 0, 1, or 2 strikes toward DNF (3rd = DNF). Displayed as e.g. "⚠️ 0/3"
    var dnfStrikes: Int = 0 {
        didSet {
            let n = min(3, max(0, dnfStrikes))
            dnfStrikesLabel.text = "⚠️ \(n)/3"
            if n == 0 {
                dnfStrikesLabel.fontColor = UIColor.white.withAlphaComponent(0.5)
            } else if n == 1 {
                dnfStrikesLabel.fontColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
            } else {
                dnfStrikesLabel.fontColor = UIColor(red: 1, green: 0.35, blue: 0.2, alpha: 1)
            }
        }
    }

    init(size: CGSize, aidStations: Int) {
        self.screenSize = size
        self._totalAid = aidStations
        super.init()
        buildHUD(size: size, aidStations: aidStations)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildHUD(size: CGSize, aidStations: Int) {
        let barW: CGFloat = 200
        let barH: CGFloat = 20
        let barX = size.width * 0.5 - barW * 0.5
        let barY = size.height - 38

        // Background panel
        let panel = SKShapeNode(rectOf: CGSize(width: size.width, height: 55), cornerRadius: 0)
        panel.fillColor = UIColor.black.withAlphaComponent(0.55)
        panel.strokeColor = .clear
        panel.position = CGPoint(x: size.width/2, y: size.height - 27)
        panel.zPosition = 98
        addChild(panel)

        // Energy bar background
        energyBar = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: barH/2)
        energyBar.fillColor = UIColor(red:0.2,green:0.2,blue:0.2,alpha:1)
        energyBar.strokeColor = UIColor.white.withAlphaComponent(0.3)
        energyBar.lineWidth = 1
        energyBar.position = CGPoint(x: barX + barW/2, y: barY)
        energyBar.zPosition = 99
        addChild(energyBar)

        // Energy fill
        energyFill = SKShapeNode(rectOf: CGSize(width: barW - 4, height: barH - 4), cornerRadius: (barH-4)/2)
        energyFill.fillColor = UIColor(red:0.2,green:0.9,blue:0.3,alpha:1)
        energyFill.strokeColor = .clear
        energyFill.position = CGPoint(x: barX + barW/2, y: barY)
        energyFill.zPosition = 100
        addChild(energyFill)

        // Energy icon
        energyIcon = SKLabelNode(text: "⚡")
        energyIcon.fontSize = 16
        energyIcon.position = CGPoint(x: barX - 14, y: barY - 8)
        energyIcon.zPosition = 100
        addChild(energyIcon)

        // Energy label
        energyLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        energyLabel.fontSize = 11
        energyLabel.fontColor = .white
        energyLabel.verticalAlignmentMode = .center
        energyLabel.position = CGPoint(x: barX + barW/2, y: barY)
        energyLabel.zPosition = 101
        addChild(energyLabel)
        updateEnergyBar()

        // Score
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        scoreLabel.fontSize = 18
        scoreLabel.fontColor = UIColor(red:1,green:0.85,blue:0.2,alpha:1)
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 16, y: barY - 8)
        scoreLabel.zPosition = 100
        scoreLabel.text = "⭐ 0"
        addChild(scoreLabel)

        // Distance
        distanceLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        distanceLabel.fontSize = 13
        distanceLabel.fontColor = UIColor.white.withAlphaComponent(0.9)
        distanceLabel.horizontalAlignmentMode = .right
        distanceLabel.position = CGPoint(x: size.width - 16, y: barY - 8)
        distanceLabel.zPosition = 100
        distanceLabel.text = "0.0 km"
        addChild(distanceLabel)

        // Aid station progress dots
        let dotY = barY - barH - 14
        let dotSpacing: CGFloat = 24
        let totalDotW = CGFloat(aidStations) * dotSpacing
        let startX = size.width/2 - totalDotW/2 + dotSpacing/2
        for i in 0..<aidStations {
            let dot = SKShapeNode(circleOfRadius: 7)
            dot.fillColor = UIColor(red:0.3,green:0.3,blue:0.3,alpha:1)
            dot.strokeColor = UIColor.white.withAlphaComponent(0.5)
            dot.lineWidth = 1.5
            dot.position = CGPoint(x: startX + CGFloat(i) * dotSpacing, y: dotY)
            dot.zPosition = 100
            addChild(dot)
            aidProgress.append(dot)

            let aidIcon = SKLabelNode(text: "🏕")
            aidIcon.fontSize = 8
            aidIcon.verticalAlignmentMode = .center
            aidIcon.position = CGPoint(x: 0, y: 0)
            dot.addChild(aidIcon)
        }

        // State label (running/walking/sprinting)
        stateLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        stateLabel.fontSize = 12
        stateLabel.fontColor = UIColor(red:0.3,green:1,blue:0.5,alpha:1)
        stateLabel.position = CGPoint(x: size.width/2, y: dotY - 16)
        stateLabel.zPosition = 100
        stateLabel.text = "🏃 RUNNING"
        addChild(stateLabel)

        // DNF strikes (0/3 = energy hit zero count; 3rd time = DNF)
        dnfStrikesLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        dnfStrikesLabel.fontSize = 12
        dnfStrikesLabel.fontColor = UIColor.white.withAlphaComponent(0.5)
        dnfStrikesLabel.horizontalAlignmentMode = .left
        dnfStrikesLabel.position = CGPoint(x: 16, y: barY - 28)
        dnfStrikesLabel.zPosition = 100
        dnfStrikesLabel.text = "⚠️ 0/3"
        addChild(dnfStrikesLabel)
    }

    private func updateEnergyBar() {
        let ratio = _energy / GameConstants.energyMax
        let barW: CGFloat = 196
        let newW = max(4, barW * ratio)
        let barH: CGFloat = 16
        let path = UIBezierPath(roundedRect: CGRect(x: -barW/2, y: -barH/2, width: newW, height: barH), cornerRadius: barH/2)
        energyFill.path = path.cgPath

        if ratio > 0.6 {
            energyFill.fillColor = UIColor(red:0.2, green:0.9, blue:0.3, alpha:1)
        } else if ratio > 0.3 {
            energyFill.fillColor = UIColor(red:1.0, green:0.8, blue:0.1, alpha:1)
        } else {
            energyFill.fillColor = UIColor(red:0.9, green:0.2, blue:0.2, alpha:1)
            if ratio < 0.15 {
                let pulse = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.5, duration: 0.2),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.2)
                ])
                energyFill.run(SKAction.repeat(pulse, count: 2))
            }
        }
        let pct = Int(ratio * 100)
        energyLabel.text = "\(pct)%"
    }

    func updateDistance(_ km: CGFloat, total: Int) {
        distanceLabel.text = String(format: "%.1f / %d km", km, total)
    }

    func markAidStation(_ index: Int) {
        guard index < aidProgress.count else { return }
        let dot = aidProgress[index]
        dot.fillColor = UIColor(red:0.2,green:0.8,blue:0.3,alpha:1)
        let pop = SKAction.sequence([
            SKAction.scale(to: 1.5, duration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])
        dot.run(pop)
    }

    func updateStateLabel(state: PlayerState, energy: CGFloat) {
        switch state {
        case .running:   stateLabel.text = "🏃 RUNNING";  stateLabel.fontColor = UIColor(red:0.3,green:1,blue:0.5,alpha:1)
        case .sprinting: stateLabel.text = "⚡ SPRINT!";  stateLabel.fontColor = UIColor(red:1,green:0.9,blue:0.1,alpha:1)
        case .walking:   stateLabel.text = "🚶 WALKING";  stateLabel.fontColor = UIColor(red:0.8,green:0.5,blue:0.3,alpha:1)
        case .hiking:    stateLabel.text = "🥾 HIKING";   stateLabel.fontColor = UIColor(red:0.4,green:0.8,blue:0.4,alpha:1)
        case .jumping:   stateLabel.text = "🦘 JUMP!";    stateLabel.fontColor = .white
        case .celebration: stateLabel.text = "🎉 AID STATION!"; stateLabel.fontColor = UIColor(red:1,green:0.8,blue:0.2,alpha:1)
        case .dead: stateLabel.text = "💀 GAME OVER"; stateLabel.fontColor = UIColor(red:0.6,green:0.2,blue:0.2,alpha:1)
        }
    }

    func showMessage(_ text: String, color: UIColor = .white) {
        let slot = messageSlotInUse.firstIndex(where: { !$0 }) ?? 0
        messageSlotInUse[slot] = true

        // Keep all messages below the energy bar / HUD (panel bottom ~ height-55, leave margin)
        let maxMessageY = screenSize.height - 55 - 44
        let y = maxMessageY - CGFloat(slot) * messageSlotSpacing

        let lbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        lbl.text = text
        lbl.fontSize = 24
        lbl.fontColor = color
        lbl.position = CGPoint(x: screenSize.width/2, y: y)
        lbl.zPosition = 200
        lbl.setScale(0.5)
        addChild(lbl)

        let slotToFree = slot
        lbl.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.2, duration: 0.2),
                SKAction.fadeIn(withDuration: 0.1)
            ]),
            SKAction.scale(to: 1.0, duration: 0.1),
            SKAction.wait(forDuration: 1.2),
            SKAction.group([
                SKAction.scale(to: 1.5, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.run { [weak self] in
                guard slotToFree < HUDNode.messageSlotCount else { return }
                self?.messageSlotInUse[slotToFree] = false
            },
            SKAction.removeFromParent()
        ]))
    }
}
