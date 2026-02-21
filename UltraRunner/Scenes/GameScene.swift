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

    enum SelectedPace { case walk, hike, run }
    private var selectedPace: SelectedPace = .run
    private var isOnGround = false
    private var jumpCount = 0

    private var lastUpdateTime: TimeInterval = 0
    private var currentSpeed: CGFloat = 0
    private var targetSpeed: CGFloat = 0

    private var obstacleHitCount = 0
    private let maxObstacleHits = 3
    private var hitCooldown: CGFloat = 0

    /// DNF after energy hits 0% this many times (each recovery counts as one "strike")
    private var timesEnergyHitZero: Int = 0
    private var wasEnergyAboveZero: Bool = true

    /// When player taps an aid station, we show the tent overlay and store the node until they "Return to race"
    private var tentOverlay: SKNode?
    private var pendingAidNode: SKNode?
    private var pendingAidIndex: Int?

    /// Porta potty: tap stops gameplay and shows bathroom/vomit screen until "Exit potty"
    private var pottyOverlay: SKNode?
    private var pendingPortaPottyNode: SKNode?
    private var pottyChoice: String? = nil  // "poop" or "puke" when selected

    /// Runners we've already shown "On your left" for (so we don't repeat)
    private var passedRunnerIDs: Set<ObjectIdentifier> = []

    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var lastFootstep: CGFloat = 0
    /// Keeps fart engine alive until playback finishes.
    private var fartEngineHolder: (AVAudioEngine, AVAudioPlayerNode)?

    // MARK: - Setup
    override func didMove(to view: SKView) {
        guard let levelConfig = levelConfig else { return }
        physicsWorld.gravity = CGVector(dx: 0, dy: GameConstants.gravityNormal)
        physicsWorld.contactDelegate = self

        setupBackground()
        terrainManager = TerrainManager(scene: self, config: levelConfig)

        // Player
        player = Player()
        player.position = CGPoint(x: size.width / 2, y: GameConstants.groundHeight + 40)
        player.zPosition = 20
        addChild(player)

        // HUD
        hud = HUDNode(size: size, aidStations: levelConfig.aidStations)
        hud.zPosition = 90
        addChild(hud)

        // Bottom bar: Restart & Menu
        setupBottomButtons()

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

    private func setupBottomButtons() {
        let btnW: CGFloat = 76
        let btnH: CGFloat = 40
        let rowSpacing: CGFloat = 48
        let bottomPadding: CGFloat = 28
        let sidePadding: CGFloat = 88

        func makeButton(text: String, name: String, x: CGFloat, y: CGFloat) -> SKNode {
            let container = SKNode()
            container.position = CGPoint(x: x, y: y)
            container.zPosition = 96
            container.name = name
            let bg = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 10)
            bg.fillColor = UIColor.white.withAlphaComponent(0.25)
            bg.strokeColor = UIColor.white.withAlphaComponent(0.5)
            bg.lineWidth = 1
            container.addChild(bg)
            let lbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
            lbl.text = text
            lbl.fontSize = 14
            lbl.fontColor = .white
            lbl.verticalAlignmentMode = .center
            container.addChild(lbl)
            return container
        }

        // Left thumb zone: Walk (bottom), Hike (above)
        let leftX = sidePadding
        addChild(makeButton(text: "🚶 Walk", name: "btn_walk", x: leftX, y: bottomPadding))
        addChild(makeButton(text: "🥾 Hike", name: "btn_hike", x: leftX, y: bottomPadding + rowSpacing))

        // Right thumb zone: Jump (bottom), Run (above)
        let rightX = size.width - sidePadding
        addChild(makeButton(text: "🦘 Jump", name: "btn_jump", x: rightX, y: bottomPadding))
        addChild(makeButton(text: "🏃 Run", name: "btn_run", x: rightX, y: bottomPadding + rowSpacing))

        // Center: Menu & Restart (less frequent)
        let centerY = bottomPadding + rowSpacing / 2
        addChild(makeButton(text: "◀ Menu", name: "btn_menu", x: size.width / 2 - 52, y: centerY))
        addChild(makeButton(text: "🔄 Restart", name: "btn_restart", x: size.width / 2 + 52, y: centerY))
    }

    private func goToMenu() {
        let scene = MainMenuScene(size: size)
        scene.scaleMode = .aspectFill
        view?.presentScene(scene, transition: SKTransition.fade(withDuration: 0.4))
    }

    private func restartLevel() {
        guard let config = levelConfig else { return }
        let scene = GameScene(size: size)
        scene.scaleMode = .aspectFill
        scene.levelConfig = config
        scene.levelIndex = levelIndex
        view?.presentScene(scene, transition: SKTransition.doorway(withDuration: 0.5))
    }

    // MARK: - Touch (only bottom buttons + tap on goodies to collect)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let nodesAtPoint = nodes(at: loc)

        func buttonName(_ node: SKNode) -> String? { node.name ?? node.parent?.name }

        for node in nodesAtPoint {
            guard let name = buttonName(node) else { continue }
            switch name {
            case "btn_menu":
                goToMenu()
                return
            case "btn_restart":
                restartLevel()
                return
            case "btn_walk":
                selectedPace = .walk
                return
            case "btn_hike":
                selectedPace = .hike
                return
            case "btn_run":
                selectedPace = .run
                return
            case "btn_jump":
                if isAlive, !isCelebrating, isOnGround { doJump() }
                return
            default:
                break
            }
        }

        // When in tent, only handle tent buttons
        if tentOverlay != nil {
            for node in nodesAtPoint {
                let name = tentButtonName(from: node)
                if let n = name, n.hasPrefix("tent_") {
                    if n != "tent_return" {
                        showTentOptionFeedback(optionName: n)
                    }
                    leaveTentAndContinue()
                    return
                }
            }
            return
        }

        // When in porta potty, only handle potty buttons
        if pottyOverlay != nil {
            for node in nodesAtPoint {
                let name = node.name ?? node.parent?.name ?? ""
                if name.hasPrefix("potty_") {
                    if name == "potty_poop" {
                        pottyChoice = "poop"
                        playFartSound()
                        showPottyEmojiFeedback(emoji: "💩", text: "Much better!")
                        leavePortaPotty()
                    } else if name == "potty_puke" {
                        pottyChoice = "puke"
                        playFeelBetterSound()
                        showPottyEmojiFeedback(emoji: "🤮", text: "Feeling lighter!")
                        leavePortaPotty()
                    }
                    return
                }
            }
            return
        }

        // Tap on another runner – show a supportive/funny phrase right away
        if findOtherRunnerNode(in: nodesAtPoint) != nil {
            let phrase = GameScene.tapPhrases.randomElement() ?? "Way to go!"
            hud.showMessage(phrase, color: UIColor(red:1,green:0.85,blue:0.3,alpha:1))
            return
        }

        // Tap on goodies (pickups / aid stations / portapotty) to collect or enter
        if let pickupNode = findPickupOrAidNode(in: nodesAtPoint) {
            handlePickup(pickupNode)
        }
    }

    private func findOtherRunnerNode(in nodes: [SKNode]) -> SKNode? {
        for node in nodes {
            var n: SKNode? = node
            while let current = n {
                if current.name == "otherRunner" { return current }
                n = current.parent
            }
        }
        return nil
    }

    private func tentButtonName(from node: SKNode) -> String? {
        var n: SKNode? = node
        while let current = n {
            if let name = current.name, name.hasPrefix("tent_") { return name }
            n = current.parent
        }
        return nil
    }

    private func findPickupOrAidNode(in nodes: [SKNode]) -> SKNode? {
        for node in nodes {
            if let name = node.name, name.hasPrefix("pickup_") || name.hasPrefix("aidstation_") || name == "portapotty" {
                return node
            }
            var p: SKNode? = node.parent
            while let parent = p {
                if let name = parent.name, name.hasPrefix("pickup_") || name.hasPrefix("aidstation_") || name == "portapotty" {
                    return parent
                }
                p = parent.parent
            }
        }
        return nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}

    private func doJump() {
        guard isOnGround else { return }
        physicsWorld.gravity = CGVector(dx: 0, dy: GameConstants.gravityJump)
        player.jump()
        isOnGround = false
        playSound("jump")
        spawnJumpEffect()
    }

    // MARK: - Update
    override func update(_ currentTime: TimeInterval) {
        if tentOverlay != nil { return } // Paused inside aid station tent
        if pottyOverlay != nil { return } // Paused inside porta potty
        guard isAlive else { return }
        let dt: CGFloat = lastUpdateTime == 0 ? 0.016 : CGFloat(min(currentTime - lastUpdateTime, 0.05))
        lastUpdateTime = currentTime
        elapsedTime += Double(dt)

        clampPlayerToScreen()
        updateEnergy(dt: dt)
        checkZeroEnergyDNF()
        updatePlayerState(dt: dt)
        updateSpeed(dt: dt)
        terrainManager.update(scrollSpeed: currentSpeed, dt: dt)
        updateHUD()
        updateHitCooldown(dt: dt)
        checkAidStationProgress()
        spawnParticleTrail(dt: dt)
        checkPassedAnyRunner()
    }

    /// Shown automatically when you pass any runner
    private static let passMessage = "On your left"

    /// Shown when you tap a runner (supportive, funny, Goggins-style)
    private static let tapPhrases = [
        "Way to go!",
        "Out of the way, slowpoke!",
        "Stay hard!",
        "Who's gonna carry the boats?!",
        "You don't know me!",
        "Can't hurt me!",
        "They don't know me son!",
        "Stay hard or go home!",
        "Nobody's coming to save you!",
        "Take souls!",
        "You're a different breed!",
        "Embrace the suck!",
        "Don't stop when you're tired.",
        "Do it when they're sleeping!",
        "No rep left behind!",
        "Nice pace… said nobody.",
        "My grandma runs faster!",
        "See you at the finish!",
        "Looking strong!",
        "Let's go!",
    ]

    private func checkPassedAnyRunner() {
        let playerCenterX = size.width / 2
        let currentRunnerIDs = Set(terrainManager.otherRunnerNodes.map { ObjectIdentifier($0) })
        passedRunnerIDs = passedRunnerIDs.intersection(currentRunnerIDs)

        for runner in terrainManager.otherRunnerNodes {
            guard runner.parent != nil, runner.position.x < playerCenterX else { continue }
            let id = ObjectIdentifier(runner)
            guard !passedRunnerIDs.contains(id) else { continue }
            passedRunnerIDs.insert(id)
            hud.showMessage(GameScene.passMessage, color: UIColor(red:1,green:0.85,blue:0.3,alpha:1))
            break
        }
    }

    private func updateEnergy(dt: CGFloat) {
        let drain: CGFloat
        if currentSpeed <= GameConstants.playerWalkSpeed * 1.1 {
            drain = -GameConstants.energyRestoreWalk * dt
        } else if currentSpeed <= GameConstants.playerHikeSpeed * 1.05 {
            drain = GameConstants.energyDrainRun * 0.5 * dt
        } else {
            drain = GameConstants.energyDrainRun * dt
        }
        energy = max(0, min(GameConstants.energyMax, energy - drain))
        hud.energy = energy
    }

    private func checkZeroEnergyDNF() {
        guard isAlive else { return }
        if energy <= 0 {
            if wasEnergyAboveZero {
                timesEnergyHitZero += 1
                wasEnergyAboveZero = false
                if timesEnergyHitZero >= 3 {
                    triggerDNF()
                    return
                }
                hud.showMessage("⚠️ \(timesEnergyHitZero)/3 — Energy empty!", color: UIColor(red: 1, green: 0.7, blue: 0.2, alpha: 1))
                hud.showMessage("DNF!", color: UIColor(red: 1, green: 0.7, blue: 0.2, alpha: 1))

            }
        } else {
            wasEnergyAboveZero = true
        }
    }

    private func triggerDNF() {
        isAlive = false
        currentSpeed = 0
        targetSpeed = 0
        player.state = .dead
        hud.showMessage("DNF — Did Not Finish", color: UIColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1))
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                self?.goToMenu()
            }
        ]))
    }

    private func updatePlayerState(dt: CGFloat) {
        let isJumping = !(player.physicsBody?.velocity.dy ?? 0 < 5 && isOnGround)

        if isJumping && !isOnGround {
            player.state = .jumping
        } else if energy <= 0 {
            player.state = .walking
        } else {
            switch selectedPace {
            case .walk:  player.state = .walking
            case .hike:  player.state = .hiking
            case .run:   player.state = .running
            }
        }
        hud.updateStateLabel(state: player.state, energy: energy)
    }

    private func updateSpeed(dt: CGFloat) {
        let target: CGFloat
        if energy <= 0 {
            target = GameConstants.playerWalkSpeed
        } else {
            switch selectedPace {
            case .walk: target = GameConstants.playerWalkSpeed
            case .hike: target = GameConstants.playerHikeSpeed
            case .run:  target = GameConstants.playerRunSpeed
            }
        }
        targetSpeed = target
        currentSpeed += (targetSpeed - currentSpeed) * min(dt * 5, 1.0)
    }

    private func updateHUD() {
        let kmTraveled = terrainManager.totalDistance / GameConstants.distanceUnitsPerKm
        hud.score = score
        hud.dnfStrikes = timesEnergyHitZero
        hud.updateDistance(kmTraveled, total: levelConfig.distanceKm)
        // Points for time bonus
        score = max(0, score + Int(GameConstants.pointsPerSecond * 0.016))

        // Race over when distance is complete – stop scrolling and finish
        if kmTraveled >= CGFloat(levelConfig.distanceKm) {
            currentSpeed = 0
            targetSpeed = 0
            finishRace()
        }
    }

    private func clampPlayerToScreen() {
        let centerX = size.width / 2
        let horizontalMargin: CGFloat = 100
        if isOnGround {
            // If we landed ahead of center (e.g. from a jump), advance the world so we land in front of takeoff
            if player.position.x > centerX {
                terrainManager.advanceWorld(by: player.position.x - centerX)
            }
            player.position.x = centerX
            player.physicsBody?.velocity.dx = 0
        } else {
            // During jump: allow parabolic path but keep on screen
            player.position.x = min(max(player.position.x, centerX - horizontalMargin), centerX + horizontalMargin)
            if player.position.x <= centerX - horizontalMargin || player.position.x >= centerX + horizontalMargin {
                player.physicsBody?.velocity.dx = 0
            }
        }
        let maxY = size.height - 55
        if player.position.y > maxY {
            player.position.y = maxY
            player.physicsBody?.velocity.dy = min(player.physicsBody?.velocity.dy ?? 0, 0)
        }
        // Keep runner on floor if he ever falls through (safety net)
        let minY = GameConstants.groundHeight + 25
        if player.position.y < minY {
            player.position.y = minY
            player.physicsBody?.velocity.dy = 0
            physicsWorld.gravity = CGVector(dx: 0, dy: GameConstants.gravityNormal)
            isOnGround = true
        }
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
            physicsWorld.gravity = CGVector(dx: 0, dy: GameConstants.gravityNormal)
            isOnGround = true
            // Advance world so we land in front of our takeoff (handled in clampPlayerToScreen next frame)
            player.alpha = 1.0
            if player.state == .jumping { player.state = .running }
        }

        // Player hit obstacle: deduct points & energy but never block (obstacles have no collision)
        if (a.categoryBitMask == PhysicsCategory.player && b.categoryBitMask == PhysicsCategory.obstacle) ||
           (b.categoryBitMask == PhysicsCategory.player && a.categoryBitMask == PhysicsCategory.obstacle) {
            handleObstacleHit(contact)
        }

        // Pickups are collected only by tapping (not by running into them)
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

    /// Penalty for hitting an obstacle. Runner is never blocked (obstacles have no collision); he always keeps moving right.
    /// River crossings (waterCross) make you wet instead of a big penalty.
    private func handleObstacleHit(_ contact: SKPhysicsContact) {
        guard hitCooldown <= 0 else { return }
        let obstacleNode = contact.bodyA.categoryBitMask == PhysicsCategory.obstacle ? contact.bodyA.node : contact.bodyB.node
        let isRiverCrossing = (obstacleNode?.name ?? "").contains("waterCross")

        if isRiverCrossing {
            hitCooldown = 0.8
            energy = max(0, energy - 5)
            score = max(0, score - 25)
            player.removeAction(forKey: "wetDuration")
            player.setWetForDuration(5.0)
            playSound("water")
            hud.showMessage("💦 Soaked! River crossing! -25 pts", color: UIColor(red:0.3,green:0.6,blue:1,alpha:1))
            spawnWaterSplash()
        } else {
            hitCooldown = 1.5
            energy = max(0, energy - 20)
            score = max(0, score - 100)
            playSound("hit")
            shakeScreen()
            hud.showMessage("💥 OUCH! -100 pts", color: UIColor(red:1,green:0.3,blue:0.3,alpha:1))
            flashPlayer()
        }
    }

    private func spawnWaterSplash() {
        for _ in 0..<10 {
            let drop = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 4...10), height: CGFloat.random(in: 6...14)))
            drop.fillColor = UIColor(red:0.4,green:0.7,blue:1,alpha:0.7)
            drop.strokeColor = .clear
            drop.position = CGPoint(x: player.position.x + CGFloat.random(in: -20...20), y: GameConstants.groundHeight + CGFloat.random(in: 10...50))
            drop.zPosition = 19
            addChild(drop)
            drop.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: 20...60), duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.scale(to: 0.2, duration: 0.5)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func handlePickup(_ node: SKNode?) {
        guard let node = node, let name = node.name else { return }

        if name == "portapotty" {
            enterPortaPotty(node: node)
            return
        }
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

        isCelebrating = true
        currentSpeed = 0
        pendingAidNode = node
        pendingAidIndex = index
        playSound("aidStation")
        showTentOverlay(index: index)
    }

    private func showTentOverlay(index: Int) {
        tentOverlay?.removeFromParent()
        let overlay = SKNode()
        overlay.zPosition = 500
        overlay.name = "tent_overlay"

        let dim = SKShapeNode(rectOf: CGSize(width: size.width * 1.5, height: size.height * 1.5))
        dim.fillColor = UIColor.black.withAlphaComponent(0.65)
        dim.strokeColor = .clear
        dim.position = CGPoint(x: size.width/2, y: size.height/2)
        overlay.addChild(dim)

        let panelW: CGFloat = min(size.width - 40, 340)
        let panelH: CGFloat = 380
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 16)
        panel.fillColor = UIColor(red:0.25,green:0.15,blue:0.08,alpha:0.98)
        panel.strokeColor = UIColor(red:0.9,green:0.4,blue:0.2,alpha:1)
        panel.lineWidth = 3
        panel.position = CGPoint(x: size.width/2, y: size.height/2)
        overlay.addChild(panel)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "🏕 AID STATION \(index + 1)"
        title.fontSize = 22
        title.fontColor = UIColor(red:1,green:0.9,blue:0.5,alpha:1)
        title.position = CGPoint(x: size.width/2, y: size.height/2 + panelH/2 - 36)
        overlay.addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-Medium")
        sub.text = "Pick one thing — then you're out!"
        sub.fontSize = 14
        sub.fontColor = UIColor.white.withAlphaComponent(0.85)
        sub.position = CGPoint(x: size.width/2, y: size.height/2 + panelH/2 - 58)
        overlay.addChild(sub)

        let options: [(name: String, emoji: String, label: String)] = [
            ("tent_ice", "🧊", "ICE on head"),
            ("tent_gel", "⚡", "Gels"),
            ("tent_bathroom", "🚻", "Bathroom"),
            ("tent_chicken", "🍗", "Chicken wings"),
            ("tent_chips", "🍟", "Potato chips"),
            ("tent_banana", "🍌", "Banana"),
            ("tent_cola", "🥤", "Cola"),
            ("tent_pretzel", "🥨", "Pretzels"),
        ]
        let cols = 4
        let btnSize: CGFloat = 68
        let spacing: CGFloat = 76
        let startX = size.width/2 - (CGFloat(cols - 1) * spacing / 2)
        let row1Y = size.height/2 + 20
        let row2Y = size.height/2 - 55
        for (i, opt) in options.enumerated() {
            let col = i % cols
            let row = i / cols
            let x = startX + CGFloat(col) * spacing
            let y = row == 0 ? row1Y : row2Y
            let btn = makeTentOptionButton(name: opt.name, emoji: opt.emoji, label: opt.label, size: btnSize)
            btn.position = CGPoint(x: x, y: y)
            overlay.addChild(btn)
        }

        addChild(overlay)
        tentOverlay = overlay
    }

    private func makeTentOptionButton(name: String, emoji: String, label: String, size: CGFloat) -> SKNode {
        let btn = SKNode()
        btn.name = name
        let bg = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 10)
        bg.fillColor = UIColor(red:0.35,green:0.22,blue:0.12,alpha:1)
        bg.strokeColor = UIColor(red:0.9,green:0.6,blue:0.2,alpha:0.9)
        bg.lineWidth = 1.5
        btn.addChild(bg)
        let em = SKLabelNode(text: emoji)
        em.fontSize = 28
        em.verticalAlignmentMode = .center
        em.position = CGPoint(x: 0, y: 8)
        btn.addChild(em)
        let lbl = SKLabelNode(fontNamed: "AvenirNext-Medium")
        lbl.text = label
        lbl.fontSize = 9
        lbl.fontColor = UIColor.white.withAlphaComponent(0.9)
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: -18)
        lbl.horizontalAlignmentMode = .center
        btn.addChild(lbl)
        return btn
    }

    private func showTentOptionFeedback(optionName: String) {
        let messages: [String: String] = [
            "tent_ice": "🧊 So refreshing!",
            "tent_gel": "⚡ Powered up!",
            "tent_bathroom": "🚻 Much better!",
            "tent_chicken": "🍗 Tasty!",
            "tent_chips": "🍟 Salty goodness!",
            "tent_banana": "🍌 Perfect!",
            "tent_cola": "🥤 Ahhh!",
            "tent_pretzel": "🥨 Crunch!",
        ]
        let text = messages[optionName] ?? "Yum!"
        playSound("pickup")
        hud.showMessage(text, color: UIColor(red:0.4,green:0.9,blue:0.5,alpha:1))
    }

    private func leaveTentAndContinue() {
        guard let node = pendingAidNode, let idx = pendingAidIndex else { return }

        tentOverlay?.removeFromParent()
        tentOverlay = nil
        pendingAidNode = nil
        pendingAidIndex = nil

        aidStationsReached += 1
        energy = GameConstants.energyMax
        score += GameConstants.pointsPerAidStation + Int(1000.0 / (elapsedTime / Double(max(1, aidStationsReached))))

        hud.markAidStation(idx)
        hud.showMessage("🏕 AID STATION \(idx+1)! +\(GameConstants.pointsPerAidStation)", color: UIColor(red:1,green:0.9,blue:0.2,alpha:1))
        player.state = .celebration
        playSound("aidStation")
        showAidStationCelebration(index: idx)

        terrainManager.pickupNodes.removeAll { $0 == node }
        node.removeFromParent()

        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.5),
            SKAction.run { [weak self] in
                self?.isCelebrating = false
                if let total = self?.levelConfig.aidStations, self?.aidStationsReached == total {
                    self?.finishRace()
                }
            }
        ]))
    }

    // MARK: - Porta Potty
    private func enterPortaPotty(node: SKNode) {
        currentSpeed = 0
        targetSpeed = 0
        pendingPortaPottyNode = node
        pottyChoice = nil
        playSound("pickup")  // door open
        showPortaPottyOverlay()
    }

    private func showPortaPottyOverlay() {
        pottyOverlay?.removeFromParent()
        let overlay = SKNode()
        overlay.zPosition = 500
        overlay.name = "potty_overlay"

        let dim = SKShapeNode(rectOf: CGSize(width: size.width * 1.5, height: size.height * 1.5))
        dim.fillColor = UIColor(red: 0.1, green: 0.08, blue: 0.2, alpha: 0.75)
        dim.strokeColor = .clear
        dim.position = CGPoint(x: size.width/2, y: size.height/2)
        overlay.addChild(dim)

        let panelW: CGFloat = min(size.width - 40, 320)
        let panelH: CGFloat = 340
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 16)
        panel.fillColor = UIColor(red: 0.12, green: 0.2, blue: 0.45, alpha: 0.98)
        panel.strokeColor = UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.9)
        panel.lineWidth = 3
        panel.position = CGPoint(x: size.width/2, y: size.height/2)
        overlay.addChild(panel)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "🚻 Porta Potty"
        title.fontSize = 24
        title.fontColor = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
        title.position = CGPoint(x: size.width/2, y: size.height/2 + panelH/2 - 40)
        overlay.addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-Medium")
        sub.text = "Pick one — then you're out!"
        sub.fontSize = 14
        sub.fontColor = UIColor.white.withAlphaComponent(0.9)
        sub.position = CGPoint(x: size.width/2, y: size.height/2 + panelH/2 - 68)
        overlay.addChild(sub)

        // 💩 Go to bathroom
        let poopBtn = makePottyButton(name: "potty_poop", emoji: "💩", label: "Go to bathroom", size: 100)
        poopBtn.position = CGPoint(x: size.width/2 - 75, y: size.height/2 + 15)
        overlay.addChild(poopBtn)

        // 🤮 Throw up
        let pukeBtn = makePottyButton(name: "potty_puke", emoji: "🤮", label: "Throw up", size: 100)
        pukeBtn.position = CGPoint(x: size.width/2 + 75, y: size.height/2 + 15)
        overlay.addChild(pukeBtn)

        addChild(overlay)
        pottyOverlay = overlay
    }

    private func makePottyButton(name: String, emoji: String, label: String, size: CGFloat) -> SKNode {
        let btn = SKNode()
        btn.name = name
        let bg = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 14)
        bg.fillColor = UIColor(red: 0.2, green: 0.35, blue: 0.6, alpha: 1)
        bg.strokeColor = UIColor(red: 0.5, green: 0.75, blue: 1, alpha: 0.9)
        bg.lineWidth = 2
        btn.addChild(bg)
        let em = SKLabelNode(text: emoji)
        em.fontSize = 48
        em.verticalAlignmentMode = .center
        em.position = CGPoint(x: 0, y: 12)
        btn.addChild(em)
        let lbl = SKLabelNode(fontNamed: "AvenirNext-Medium")
        lbl.text = label
        lbl.fontSize = 12
        lbl.fontColor = UIColor.white.withAlphaComponent(0.95)
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: -32)
        lbl.horizontalAlignmentMode = .center
        btn.addChild(lbl)
        return btn
    }

    private func showPottyEmojiFeedback(emoji: String, text: String) {
        hud.showMessage("\(emoji) \(text)", color: UIColor(red: 0.5, green: 0.85, blue: 0.6, alpha: 1))
    }

    private func leavePortaPotty() {
        guard let node = pendingPortaPottyNode else { return }

        pottyOverlay?.removeFromParent()
        pottyOverlay = nil
        pendingPortaPottyNode = nil

        let choice = pottyChoice ?? "poop"
        pottyChoice = nil

        if choice == "poop" {
            energy = min(GameConstants.energyMax, energy + GameConstants.energyFromBathroom)
            score = max(0, score - 200)
            hud.showMessage("💩 Bathroom break! -200 pts, +\(Int(GameConstants.energyFromBathroom)) energy", color: UIColor(red: 0.4, green: 0.6, blue: 1, alpha: 1))
            // Fart already played when they tapped 💩
        } else {
            energy = min(GameConstants.energyMax, energy + GameConstants.energyFromTrash)
            score = max(0, score - 150)
            hud.showMessage("🤮 Threw up! -150 pts, +\(Int(GameConstants.energyFromTrash)) energy", color: UIColor(red: 0.5, green: 0.8, blue: 0.4, alpha: 1))
            // Voice already played when they tapped 🤮
        }

        terrainManager.portaPottyNodes.removeAll { $0 == node }
        node.removeFromParent()

        targetSpeed = energy <= 0 ? GameConstants.playerWalkSpeed : GameConstants.playerRunSpeed
        currentSpeed = targetSpeed
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
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2, y: size.height / 2)
        container.zPosition = 300
        addChild(container)
        let greenColor = UIColor(red: 0.25, green: 0.65, blue: 0.2, alpha: 0.95)
        for _ in 0..<8 {
            let blob = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 18...36), height: CGFloat.random(in: 12...24)))
            blob.fillColor = greenColor
            blob.strokeColor = UIColor(red: 0.12, green: 0.45, blue: 0.1, alpha: 1)
            blob.lineWidth = 1
            blob.position = CGPoint(x: CGFloat.random(in: -35...35), y: CGFloat.random(in: -25...25))
            blob.zRotation = CGFloat.random(in: -0.5...0.5)
            container.addChild(blob)
        }
        let emoji = SKLabelNode(text: "🤢")
        emoji.fontSize = 60
        emoji.verticalAlignmentMode = .center
        emoji.zPosition = 1
        container.addChild(emoji)
        container.setScale(0.01)
        let fillScale: CGFloat = max(size.width, size.height) / 50
        container.run(SKAction.sequence([
            SKAction.scale(to: fillScale, duration: 0.175),
            SKAction.wait(forDuration: 0.8),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.scale(to: fillScale * 1.1, duration: 0.5)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func finishRace() {
        isAlive = false
        isCelebrating = true
        let finalScore = score + Int((1000.0 / elapsedTime) * 1000)

        // Celebration: confetti, clapping sound, message
        playSound("finish")
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.15),
            SKAction.run { [weak self] in self?.playSound("finish") },
            SKAction.wait(forDuration: 0.2),
            SKAction.run { [weak self] in self?.playSound("finish") }
        ]))
        hud.showMessage("🏁 FINISH! 👏", color: UIColor(red: 1, green: 0.9, blue: 0.2, alpha: 1))
        showFinishCelebration()

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

    private func showFinishCelebration() {
        // Big confetti burst from center-top
        let centerX = size.width / 2
        let centerY = size.height * 0.55
        for _ in 0..<50 {
            let conf = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 6...12)))
            conf.fillColor = UIColor(hue: CGFloat.random(in: 0...1), saturation: 0.9, brightness: 0.95, alpha: 1)
            conf.strokeColor = .clear
            conf.position = CGPoint(x: centerX + CGFloat.random(in: -40...40), y: centerY)
            conf.zPosition = 150
            conf.zRotation = CGFloat.random(in: 0...(.pi * 2))
            addChild(conf)
            let dx = CGFloat.random(in: -180...180)
            let dy = CGFloat.random(in: 80...220)
            conf.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 1.4),
                    SKAction.rotate(byAngle: .pi * CGFloat.random(in: 2...6), duration: 1.4),
                    SKAction.sequence([
                        SKAction.wait(forDuration: 0.6),
                        SKAction.fadeOut(withDuration: 0.8)
                    ])
                ]),
                SKAction.removeFromParent()
            ]))
        }
        // Clapping hands emoji burst
        let clapEmojis = ["👏", "🎉", "🏁", "🌟"]
        for i in 0..<12 {
            let lbl = SKLabelNode(text: clapEmojis[i % clapEmojis.count])
            lbl.fontSize = CGFloat.random(in: 24...36)
            lbl.position = CGPoint(x: centerX, y: centerY)
            lbl.zPosition = 151
            addChild(lbl)
            let angle = CGFloat(i) / 12.0 * .pi * 2 + CGFloat.random(in: -0.2...0.2)
            let dist = CGFloat.random(in: 60...140)
            lbl.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: 1.0),
                    SKAction.fadeOut(withDuration: 1.0)
                ]),
                SKAction.removeFromParent()
            ]))
        }
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
            SKAction.fadeAlpha(to: 0.3, duration: 0.08),
            SKAction.fadeAlpha(to: 1.0, duration: 0.08)
        ])
        player.run(SKAction.sequence([
            SKAction.repeat(flash, count: 3),
            SKAction.run { [weak player] in player?.alpha = 1.0 }
        ]))
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
    /// Play fart when the player uses the poop emoji in the bathroom.
    /// Uses "fart.wav", "fart.m4a", or "fart.mp3" from the app bundle if present; otherwise plays a procedural fart.
    private func playFartSound() {
        let extensions = ["wav", "m4a", "mp3"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: "fart", withExtension: ext) {
                do {
                    audioPlayers["fart"]?.stop()
                    let player = try AVAudioPlayer(contentsOf: url)
                    audioPlayers["fart"] = player
                    player.play()
                    return
                } catch {}
                break
            }
        }
        playFartSoundProcedural()
    }

    /// Fallback procedural fart if no sound file is bundled.
    private func playFartSoundProcedural() {
        let sampleRate: Double = 44100
        let duration: Double = 0.22
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { return }
        let samples = channelData[0]
        var r: Float = 0.5
        for i in 0..<Int(frameCount) {
            r = r * 0.97 + Float.random(in: -0.15...0.15)
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 12) * (1 - exp(-t * 80))
            samples[i] = r * Float(envelope) * 0.4
        }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let mainMixer = engine.mainMixerNode
        engine.connect(player, to: mainMixer, format: format)
        do {
            try engine.start()
            fartEngineHolder = (engine, player)
            player.scheduleBuffer(buffer, at: nil, options: .interrupts) { [weak self] in
                DispatchQueue.main.async { self?.fartEngineHolder = nil }
            }
            player.play()
        } catch {}
    }

    /// Play "Wow, I feel better" when the player uses the throw-up emoji in the bathroom.
    /// Uses "feel_better.aiff", .wav, .m4a, or .mp3 from the app bundle if present; otherwise plays system "bleh" sound.
    private func playFeelBetterSound() {
        let extensions = ["aiff", "wav", "m4a", "mp3"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: "feel_better", withExtension: ext) {
                do {
                    audioPlayers["feel_better"]?.stop()
                    let player = try AVAudioPlayer(contentsOf: url)
                    audioPlayers["feel_better"] = player
                    player.play()
                    return
                } catch {}
                break
            }
        }
        playSound("bleh")
    }

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
        case "bleh":      soundID = 1304
        case "aidStation":soundID = 1025  // Cha-ching style
        case "finish":    soundID = 1025  // Success / celebration (clapping feel)
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
