import SpriteKit
import AVFoundation

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties
    var levelConfig: LevelConfig!
    var levelIndex: Int = 0

    private var player: Player!
    private var hud: HUDNode!
    private var terrainManager: TerrainManager!

    private var energy: CGFloat = GameConstants.energyMax
    private var score: Int = 0
    private var elapsedTime: Double = 0
    private var aidStationsReached: Int = 0
    private var isAlive = true
    private var isCelebrating = false

    private var touchStart: Date?
    private var isTouchHeld = false
    private var isOnGround = false
    private var jumpCount = 0

    private var lastUpdateTime: TimeInterval = 0
    private var currentSpeed: CGFloat = 0
    private var targetSpeed: CGFloat = 0

    private var obstacleHitCount = 0
    private let maxObstacleHits = 3
    private var hitCooldown: CGFloat = 0

    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var lastFootstep: CGFloat = 0

    // MARK: - Setup
    override func didMove(to view: SKView) {
        guard let levelConfig = levelConfig else { return }
        physicsWorld.gravity = CGVector(dx: 0, dy: -22)
        physicsWorld.contactDelegate = self

        setupBackground()
        terrainManager = TerrainManager(scene: self, config: levelConfig)

        // Player
        player = Player()
        player.position = CGPoint(x: size.width * 0.28, y: GameConstants.groundHeight + 40)
        player.zPosition = 20
        addChild(player)

        // HUD
        hud = HUDNode(size: size, aidStations: levelConfig.aidStations)
        hud.zPosition = 90
        addChild(hud)

        // Camera-ish – we'll just scroll the world
        targetSpeed = GameConstants.playerRunSpeed
        currentSpeed = targetSpeed

        // Countdown
        showCountdown()
    }

    private func setupBackground() {
        guard let lc = levelConfig else { return }

        // Sky gradient (two layers)
        let skyBottom = SKShapeNode(rectOf: size)
        skyBottom.fillColor = lc.skyBottom
        skyBottom.strokeColor = .clear
        skyBottom.position = CGPoint(x: size.width/2, y: size.height/2)
        skyBottom.zPosition = 0
        addChild(skyBottom)

        let skyTop = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height * 0.55))
        skyTop.fillColor = lc.skyTop
        skyTop.strokeColor = .clear
        skyTop.position = CGPoint(x: size.width/2, y: size.height * 0.73)
        skyTop.zPosition = 1
        addChild(skyTop)

        // Sun or planet
        let star = SKShapeNode(circleOfRadius: 32)
        star.fillColor = levelConfig.name.contains("MARS") ? UIColor(red:1,green:0.5,blue:0.2,alpha:1) : UIColor(red:1,green:0.95,blue:0.5,alpha:1)
        star.strokeColor = star.fillColor.withAlphaComponent(0.4)
        star.lineWidth = 8
        star.position = CGPoint(x: size.width * 0.85, y: size.height * 0.82)
        star.zPosition = 1
        addChild(star)

        // Clouds / stars
        for _ in 0..<(levelConfig.name.contains("MARS") ? 0 : 8) {
            let cloud = makeCloud()
            addChild(cloud)
        }

        // Ground line
        let groundLine = SKShapeNode(rectOf: CGSize(width: size.width * 10, height: 3))
        groundLine.fillColor = lc.accentColor.withAlphaComponent(0.5)
        groundLine.strokeColor = .clear
        groundLine.position = CGPoint(x: size.width/2, y: GameConstants.groundHeight)
        groundLine.zPosition = 7
        addChild(groundLine)
    }

    private func makeCloud() -> SKNode {
        let node = SKNode()
        let x = CGFloat.random(in: 0...size.width)
        let y = CGFloat.random(in: size.height * 0.6...size.height * 0.88)
        for _ in 0..<3 {
            let r = CGFloat.random(in: 18...38)
            let puff = SKShapeNode(circleOfRadius: r)
            puff.fillColor = UIColor.white.withAlphaComponent(CGFloat.random(in:0.35...0.7))
            puff.strokeColor = .clear
            puff.position = CGPoint(x: CGFloat.random(in:-30...30), y: CGFloat.random(in:-10...10))
            node.addChild(puff)
        }
        node.position = CGPoint(x: x, y: y)
        node.zPosition = 1
        let drift = SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: -CGFloat.random(in:15...40), y: 0, duration: 8),
            SKAction.moveBy(x: CGFloat.random(in:15...40), y: 0, duration: 8)
        ]))
        node.run(drift)
        return node
    }

    private func showCountdown() {
        isAlive = false
        let labels = ["3", "2", "1", "GO! 🏃"]
        var delay: Double = 0
        for (i, text) in labels.enumerated() {
            let lbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            lbl.text = text
            lbl.fontSize = i == 3 ? 60 : 80
            lbl.fontColor = i == 3 ? UIColor(red:0.2,green:0.9,blue:0.3,alpha:1) : .white
            lbl.position = CGPoint(x: size.width/2, y: size.height/2)
            lbl.zPosition = 200
            lbl.alpha = 0
            addChild(lbl)
            lbl.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.group([SKAction.fadeIn(withDuration: 0.15), SKAction.scale(to: 1.2, duration: 0.15)]),
                SKAction.scale(to: 1.0, duration: 0.15),
                SKAction.wait(forDuration: 0.55),
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
            delay += 0.9
        }
        run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.run { [weak self] in self?.isAlive = true }
        ]))
    }

    // MARK: - Touch
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isAlive, !isCelebrating else { return }
        touchStart = Date()
        isTouchHeld = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isAlive else { return }
        guard let start = touchStart else { return }
        let duration = Date().timeIntervalSince(start)
        if duration < 0.25 && isOnGround {
            doJump()
        }
        isTouchHeld = false
        touchStart = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouchHeld = false
        touchStart = nil
    }

    private func doJump() {
        guard isOnGround else { return }
        player.jump()
        isOnGround = false
        playSound("jump")
        spawnJumpEffect()
    }

    // MARK: - Update
    override func update(_ currentTime: TimeInterval) {
        guard isAlive else { return }
        let dt: CGFloat = lastUpdateTime == 0 ? 0.016 : CGFloat(min(currentTime - lastUpdateTime, 0.05))
        lastUpdateTime = currentTime
        elapsedTime += Double(dt)

        updateEnergy(dt: dt)
        updatePlayerState(dt: dt)
        updateSpeed(dt: dt)
        terrainManager.update(scrollSpeed: currentSpeed, dt: dt)
        updateHUD()
        updateHitCooldown(dt: dt)
        checkAidStationProgress()
        spawnParticleTrail(dt: dt)
    }

    private func updateEnergy(dt: CGFloat) {
        let drain: CGFloat
        if currentSpeed >= GameConstants.playerSprintSpeed * 0.95 {
            drain = GameConstants.energyDrainSprint * dt
        } else if currentSpeed <= GameConstants.playerWalkSpeed * 1.1 {
            drain = -GameConstants.energyRestoreWalk * dt // restore while walking
        } else {
            drain = GameConstants.energyDrainRun * dt
        }
        energy = max(0, min(GameConstants.energyMax, energy - drain))
        hud.energy = energy
    }

    private func updatePlayerState(dt: CGFloat) {
        let isJumping = !(player.physicsBody?.velocity.dy ?? 0 < 5 && isOnGround)

        if isJumping && !isOnGround {
            player.state = .jumping
        } else if energy <= 0 {
            player.state = .walking
        } else if isTouchHeld, let start = touchStart, Date().timeIntervalSince(start) > 0.25 {
            player.state = .sprinting
        } else {
            player.state = .running
        }
        hud.updateStateLabel(state: player.state, energy: energy)
    }

    private func updateSpeed(dt: CGFloat) {
        let target: CGFloat
        if energy <= 0 {
            target = GameConstants.playerWalkSpeed
        } else if player.state == .sprinting {
            target = GameConstants.playerSprintSpeed
        } else {
            target = GameConstants.playerRunSpeed
        }
        targetSpeed = target
        currentSpeed += (targetSpeed - currentSpeed) * min(dt * 5, 1.0)
    }

    private func updateHUD() {
        let kmTraveled = terrainManager.totalDistance / 60.0
        hud.score = score
        hud.updateDistance(kmTraveled, total: levelConfig.distanceKm)
        // Points for time bonus
        score = max(0, score + Int(GameConstants.pointsPerSecond * 0.016))
    }

    private func updateHitCooldown(dt: CGFloat) {
        if hitCooldown > 0 { hitCooldown -= dt }
    }

    private func checkAidStationProgress() {
        // nothing extra needed here, handled via contacts
    }

    // MARK: - Physics Contact
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB

        // Player hit ground
        if (a.categoryBitMask == PhysicsCategory.player && b.categoryBitMask == PhysicsCategory.ground) ||
           (b.categoryBitMask == PhysicsCategory.player && a.categoryBitMask == PhysicsCategory.ground) {
            isOnGround = true
            if player.state == .jumping { player.state = .running }
        }

        // Player hit obstacle
        if (a.categoryBitMask == PhysicsCategory.player && b.categoryBitMask == PhysicsCategory.obstacle) ||
           (b.categoryBitMask == PhysicsCategory.player && a.categoryBitMask == PhysicsCategory.obstacle) {
            handleObstacleHit(contact)
        }

        // Player hit pickup
        if (a.categoryBitMask == PhysicsCategory.player && b.categoryBitMask == PhysicsCategory.pickup) ||
           (b.categoryBitMask == PhysicsCategory.player && a.categoryBitMask == PhysicsCategory.pickup) {
            let pickupNode = a.categoryBitMask == PhysicsCategory.pickup ? a.node : b.node
            handlePickup(pickupNode)
        }
    }

    func didEnd(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        if (a.categoryBitMask == PhysicsCategory.player && b.categoryBitMask == PhysicsCategory.ground) ||
           (b.categoryBitMask == PhysicsCategory.player && a.categoryBitMask == PhysicsCategory.ground) {
            // Small grace period
            run(SKAction.sequence([
                SKAction.wait(forDuration: 0.08),
                SKAction.run { [weak self] in
                    if let vel = self?.player.physicsBody?.velocity, abs(vel.dy) > 5 {
                        self?.isOnGround = false
                    }
                }
            ]))
        }
    }

    private func handleObstacleHit(_ contact: SKPhysicsContact) {
        guard hitCooldown <= 0 else { return }
        hitCooldown = 1.5
        energy = max(0, energy - 20)
        score = max(0, score - 100)
        playSound("hit")
        shakeScreen()
        hud.showMessage("💥 OUCH! -100 pts", color: UIColor(red:1,green:0.3,blue:0.3,alpha:1))
        flashPlayer()
    }

    private func handlePickup(_ node: SKNode?) {
        guard let node = node, let name = node.name else { return }

        if name.hasPrefix("aidstation_") {
            let idx = Int(name.replacingOccurrences(of: "aidstation_", with: "")) ?? 0
            collectAidStation(node: node, index: idx)
            return
        }

        guard name.hasPrefix("pickup_") else { return }
        let typeStr = name.replacingOccurrences(of: "pickup_", with: "")

        var energyGain: CGFloat = 0
        var scoreGain = GameConstants.pointsPerCollectible
        var message = ""
        var msgColor = UIColor(red:0.3,green:1,blue:0.4,alpha:1)
        var soundName = "pickup"

        switch typeStr {
        case "water":    energyGain = GameConstants.energyFromWater;    message = "💧 Water! +\(Int(energyGain)) energy"; soundName = "water"
        case "gel":      energyGain = GameConstants.energyFromGel;      message = "⚡ Energy Gel! +\(Int(energyGain))"; scoreGain = 75; soundName = "slurp"
        case "salt":     energyGain = GameConstants.energyFromSalt;     message = "🧂 Salt tabs! +\(Int(energyGain))"
        case "gummyBear":energyGain = GameConstants.energyFromGummy;    message = "🐻 Gummy bears! +\(Int(energyGain))"; soundName = "munch"
        case "banana":   energyGain = GameConstants.energyFromBanana;   message = "🍌 Banana! +\(Int(energyGain))"
        case "cola":     energyGain = GameConstants.energyFromCola;     message = "🥤 Cola! +\(Int(energyGain))"; scoreGain = 80
        case "pretzel":  energyGain = GameConstants.energyFromPretzel;  message = "🥨 Pretzel! +\(Int(energyGain))"
        case "medkit":   energyGain = GameConstants.energyFromMedkit;   message = "🩺 Medkit! +\(Int(energyGain))"; scoreGain = 100; msgColor = .cyan
        case "bathroom":
            energyGain = GameConstants.energyFromBathroom
            score = max(0, score - 200)
            message = "🚻 Bathroom break! -200 pts but +\(Int(energyGain))💧"
            msgColor = UIColor(red:0.4,green:0.6,blue:1,alpha:1)
            scoreGain = 0
            soundName = "flush"
            showBathroomAnimation()
        case "trashCan":
            energyGain = GameConstants.energyFromTrash
            score = max(0, score - 150)
            message = "🗑 Threw up! -150 pts but +\(Int(energyGain))💧"
            msgColor = UIColor(red:0.6,green:0.8,blue:0.3,alpha:1)
            scoreGain = 0
            soundName = "bleh"
            showTrashAnimation(node: node)
        default: break
        }

        energy = min(GameConstants.energyMax, energy + energyGain)
        score += scoreGain
        hud.showMessage(message, color: msgColor)
        playSound(soundName)
        popPickup(node: node)

        terrainManager.pickupNodes.removeAll { $0 == node }
    }

    private func collectAidStation(node: SKNode, index: Int) {
        guard aidStationsReached == index else { return } // Must collect in order
        aidStationsReached += 1

        isCelebrating = true
        currentSpeed = 0

        // Full restore at aid station
        energy = GameConstants.energyMax
        score += GameConstants.pointsPerAidStation + Int(1000.0 / (elapsedTime / Double(aidStationsReached)))

        hud.markAidStation(index)
        hud.showMessage("🏕 AID STATION \(index+1)! +\(GameConstants.pointsPerAidStation)", color: UIColor(red:1,green:0.9,blue:0.2,alpha:1))
        player.state = .celebration
        playSound("aidStation")
        showAidStationCelebration(index: index)

        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.5),
            SKAction.run { [weak self] in
                self?.isCelebrating = false
                if let total = self?.levelConfig.aidStations, self?.aidStationsReached == total {
                    self?.finishRace()
                }
            }
        ]))

        terrainManager.pickupNodes.removeAll { $0 == node }
        node.removeFromParent()
    }

    private func showAidStationCelebration(index: Int) {
        let items = ["💧", "⚡", "🐻", "🍌", "🧂", "🥤"]
        for i in 0..<8 {
            let lbl = SKLabelNode(text: items.randomElement()!)
            lbl.fontSize = 28
            lbl.position = CGPoint(x: size.width * 0.4, y: size.height * 0.4)
            lbl.zPosition = 150
            addChild(lbl)
            let angle = CGFloat(i) / 8.0 * .pi * 2
            let dist = CGFloat.random(in: 80...160)
            lbl.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle)*dist, y: sin(angle)*dist, duration: 0.8),
                    SKAction.fadeOut(withDuration: 0.8)
                ]),
                SKAction.removeFromParent()
            ]))
        }

        // Confetti burst
        for _ in 0..<20 {
            let conf = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
            conf.fillColor = UIColor(hue: CGFloat.random(in:0...1), saturation: 0.9, brightness: 0.9, alpha: 1)
            conf.strokeColor = .clear
            conf.position = CGPoint(x: size.width * CGFloat.random(in:0.2...0.8), y: size.height * 0.6)
            conf.zPosition = 140
            addChild(conf)
            conf.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in:-100...100), y: CGFloat.random(in:-150...50), duration: 1.2),
                    SKAction.rotate(byAngle: .pi * 4, duration: 1.2),
                    SKAction.fadeOut(withDuration: 1.2)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func showBathroomAnimation() {
        let emoji = SKLabelNode(text: "🚻")
        emoji.fontSize = 60
        emoji.position = CGPoint(x: size.width/2, y: size.height/2 - 20)
        emoji.zPosition = 200
        emoji.setScale(0.1)
        addChild(emoji)
        emoji.run(SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.1),
            SKAction.wait(forDuration: 1.5),
            SKAction.group([SKAction.scale(to: 0, duration: 0.3), SKAction.fadeOut(withDuration: 0.3)]),
            SKAction.removeFromParent()
        ]))
    }

    private func showTrashAnimation(node: SKNode) {
        let emoji = SKLabelNode(text: "🤢")
        emoji.fontSize = 50
        emoji.position = player.position + CGVector(dx: 0, dy: 50)
        emoji.zPosition = 200
        addChild(emoji)
        emoji.run(SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.2),
            SKAction.wait(forDuration: 0.8),
            SKAction.group([SKAction.moveBy(x: 0, y: 30, duration: 0.4), SKAction.fadeOut(withDuration: 0.4)]),
            SKAction.removeFromParent()
        ]))
    }

    private func finishRace() {
        isAlive = false
        let finalScore = score + Int((1000.0 / elapsedTime) * 1000)

        // Save high score
        var highScores = UserDefaults.standard.array(forKey: "highscores_\(levelIndex)") as? [[String:Any]] ?? []
        let entry: [String:Any] = ["score": finalScore, "time": elapsedTime, "name": "Runner"]
        highScores.append(entry)
        highScores.sort { ($0["score"] as! Int) > ($1["score"] as! Int) }
        if highScores.count > 10 { highScores = Array(highScores.prefix(10)) }
        UserDefaults.standard.set(highScores, forKey: "highscores_\(levelIndex)")

        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                let scene = GameOverScene(size: self.size)
                scene.scaleMode = .aspectFill
                scene.finalScore = finalScore
                scene.elapsedTime = self.elapsedTime
                scene.levelIndex = self.levelIndex
                scene.levelName = self.levelConfig.name
                self.view?.presentScene(scene, transition: SKTransition.fade(withDuration: 1.0))
            }
        ]))
    }

    // MARK: - Effects
    private func popPickup(node: SKNode) {
        node.physicsBody = nil
        node.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.6, duration: 0.15),
                SKAction.fadeOut(withDuration: 0.15)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func flashPlayer() {
        let flash = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.1),
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
        ])
        player.run(SKAction.repeat(flash, count: 3))
    }

    private func shakeScreen() {
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 8, y: 4, duration: 0.05),
            SKAction.moveBy(x: -16, y: -8, duration: 0.05),
            SKAction.moveBy(x: 12, y: 6, duration: 0.05),
            SKAction.moveBy(x: -10, y: -5, duration: 0.05),
            SKAction.moveBy(x: 6, y: 3, duration: 0.05),
            SKAction.moveBy(x: 0, y: 0, duration: 0.05)
        ])
        run(shake)
    }

    private func spawnJumpEffect() {
        for _ in 0..<6 {
            let puff = SKShapeNode(circleOfRadius: CGFloat.random(in:3...7))
            puff.fillColor = UIColor.white.withAlphaComponent(0.7)
            puff.strokeColor = .clear
            puff.position = CGPoint(x: player.position.x + CGFloat.random(in:-15...15),
                                     y: GameConstants.groundHeight + 5)
            puff.zPosition = 18
            addChild(puff)
            puff.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in:-25...25), y: CGFloat.random(in:-10...20), duration: 0.4),
                    SKAction.fadeOut(withDuration: 0.4),
                    SKAction.scale(to: 0.2, duration: 0.4)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private var particleAccum: CGFloat = 0
    private func spawnParticleTrail(dt: CGFloat) {
        guard let lc = levelConfig else { return }
        particleAccum += dt
        if particleAccum < 0.05 { return }
        particleAccum = 0

        guard player.state != .jumping && isOnGround else { return }
        let puff = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
        puff.fillColor = lc.particleColor.withAlphaComponent(CGFloat.random(in:0.3...0.6))
        puff.strokeColor = .clear
        puff.position = CGPoint(x: player.position.x - 15, y: GameConstants.groundHeight + 3)
        puff.zPosition = 9
        addChild(puff)
        puff.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: CGFloat.random(in:-20...(-5)), y: CGFloat.random(in: 0...15), duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.scale(to: 0.3, duration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Sounds (System sounds mapped to game events)
    private func playSound(_ name: String) {
        // Map game events to system sound IDs for built-in audio feedback
        var soundID: SystemSoundID = 0
        switch name {
        case "jump":      soundID = 1057  // Swoosh
        case "pickup":    soundID = 1054  // Tock
        case "water":     soundID = 1052
        case "slurp":     soundID = 1306
        case "munch":     soundID = 1057
        case "hit":       soundID = 4095  // Vibrate
        case "flush":     soundID = 1020
        case "bleh":      soundID = 1073
        case "aidStation":soundID = 1025  // Cha-ching style
        default:          soundID = 1054
        }
        if soundID == 4095 {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        } else {
            AudioServicesPlaySystemSound(soundID)
        }
    }
}

extension CGPoint {
    static func +(lhs: CGPoint, rhs: CGVector) -> CGPoint {
        CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }
}
