import SpriteKit

class TerrainManager {
    weak var scene: SKScene?
    var levelConfig: LevelConfig
    var groundNodes: [SKNode] = []
    var obstacleNodes: [SKNode] = []
    var pickupNodes: [SKNode] = []
    var portaPottyNodes: [SKNode] = []
    var bgNodes: [SKNode] = []
    var decorNodes: [SKNode] = []
    var otherRunnerNodes: [SKNode] = []
    var finishLineNodes: [SKNode] = []
    private var finishLineSpawned = false
    private var lastGroundX: CGFloat = 0
    private var spawnTimer: CGFloat = 0
    private var bgSpawnTimer: CGFloat = 0
    private var obstacleInterval: CGFloat = 3.5
    private var pickupInterval: CGFloat = 5.0
    private var nextPickupX: CGFloat = 600
    private var nextPortaPottyX: CGFloat = 900
    private var nextObstacleX: CGFloat = 500
    private var nextBgX: CGFloat = 100
    private var nextOtherRunnerX: CGFloat = 700
    private var screenH: CGFloat = 0
    private var screenW: CGFloat = 0
    private var groundY: CGFloat = 0
    private var spawnedAidStations = Set<Int>()
    var totalDistance: CGFloat = 0       // total pixels scrolled
    var aidStationPositions: [CGFloat] = []

    init(scene: SKScene, config: LevelConfig) {
        self.scene = scene
        self.levelConfig = config
        self.screenH = scene.size.height
        self.screenW = scene.size.width
        self.groundY = GameConstants.groundHeight
        // Pre-compute aid station pixel positions
        let totalPx: CGFloat = 12000
        let interval = totalPx / CGFloat(config.aidStations + 1)
        for i in 1...config.aidStations {
            aidStationPositions.append(interval * CGFloat(i))
        }
        buildInitialGround()
        spawnBackground(x: 0, extended: true)
    }

    private func buildInitialGround() {
        for i in 0..<8 {
            spawnGroundSegment(at: CGFloat(i) * 200)
        }
    }

    private func spawnGroundSegment(at x: CGFloat) {
        guard let scene = scene else { return }
        let segW: CGFloat = 220
        let seg = SKShapeNode(rectOf: CGSize(width: segW, height: 80))
        seg.fillColor = levelConfig.groundColor
        seg.strokeColor = levelConfig.groundColor.withAlphaComponent(0.5)
        seg.position = CGPoint(x: x + segW/2, y: groundY - 40)
        seg.zPosition = 5

        let physBody = SKPhysicsBody(rectangleOf: CGSize(width: segW, height: 80))
        physBody.isDynamic = false
        physBody.friction = 0.8
        physBody.restitution = 0
        physBody.categoryBitMask = PhysicsCategory.ground
        physBody.collisionBitMask = PhysicsCategory.player
        physBody.contactTestBitMask = PhysicsCategory.player
        seg.physicsBody = physBody

        scene.addChild(seg)
        groundNodes.append(seg)
        lastGroundX = x + segW

        // Ground detail
        let detail = SKShapeNode(rectOf: CGSize(width: segW, height: 8))
        detail.fillColor = levelConfig.accentColor.withAlphaComponent(0.4)
        detail.strokeColor = .clear
        detail.position = CGPoint(x: x + segW/2, y: groundY + 2)
        detail.zPosition = 6
        scene.addChild(detail)
        groundNodes.append(detail)
    }

    /// Advance the world by a horizontal offset (e.g. when landing from a jump ahead of center).
    /// Shifts all scrollable nodes left so the ground under the player stays under center.
    func advanceWorld(by offset: CGFloat) {
        guard offset > 0 else { return }
        totalDistance += offset
        for n in groundNodes       { n.position.x -= offset }
        for n in obstacleNodes     { n.position.x -= offset }
        for n in pickupNodes       { n.position.x -= offset }
        for n in portaPottyNodes   { n.position.x -= offset }
        for n in bgNodes           { n.position.x -= offset * 0.35 }
        for n in decorNodes        { n.position.x -= offset }
        for n in otherRunnerNodes  { n.position.x -= offset }
        for n in finishLineNodes   { n.position.x -= offset }
    }

    func update(scrollSpeed: CGFloat, dt: CGFloat) {
        guard let scene = scene else { return }
        totalDistance += scrollSpeed * dt

        // Scroll everything
        let dx = scrollSpeed * dt
        for n in groundNodes  { n.position.x -= dx }
        for n in obstacleNodes { n.position.x -= dx }
        for n in pickupNodes  { n.position.x -= dx }
        for n in portaPottyNodes { n.position.x -= dx }
        for n in bgNodes      { n.position.x -= dx * 0.35 }
        for n in decorNodes   { n.position.x -= dx }
        for n in otherRunnerNodes {
            guard let r = n as? OtherRunner else { n.position.x -= dx; continue }
            n.position.x -= dx * r.speedFactor
        }
        for n in finishLineNodes { n.position.x -= dx }

        // Remove off-screen
        groundNodes   = groundNodes.filter   { keepOrRemove($0) }
        obstacleNodes = obstacleNodes.filter { keepOrRemove($0) }
        pickupNodes   = pickupNodes.filter   { keepOrRemove($0) }
        portaPottyNodes = portaPottyNodes.filter { keepOrRemove($0) }
        bgNodes       = bgNodes.filter       { keepOrRemoveOffset($0, offset: -400) }
        decorNodes    = decorNodes.filter    { keepOrRemove($0) }
        otherRunnerNodes = otherRunnerNodes.filter { keepOrRemove($0) }

        // Right edge of rightmost ground segment (segment width = 220, center at position.x)
        let segW: CGFloat = 220
        let rightmostEdge = groundNodes
            .filter { $0.physicsBody?.categoryBitMask == PhysicsCategory.ground }
            .map { $0.position.x + segW / 2 }
            .max() ?? 0
        lastGroundX = rightmostEdge

        // Extend ground so there is always floor ahead of the runner (no gaps)
        while lastGroundX < scene.size.width + 500 {
            spawnGroundSegment(at: lastGroundX)
        }

        // Spawn obstacles and pickups
        nextObstacleX -= dx
        nextPickupX   -= dx
        nextPortaPottyX -= dx
        nextBgX       -= dx
        nextOtherRunnerX -= dx

        if nextObstacleX < scene.size.width + 200 {
            spawnObstacle(atX: scene.size.width + CGFloat.random(in: 100...250))
            // Time-based spacing: 5–10 s between obstacles normally; harder levels (lower scale) get 3–6 s
            let baseSeconds: CGFloat = levelConfig.obstacleGapScale <= 1.0
                ? CGFloat.random(in: 3...6)   // harder levels: more frequent
                : CGFloat.random(in: 5...10)  // normal/easy: few obstacles
            let effectiveSeconds = baseSeconds * max(1.0, levelConfig.obstacleGapScale)
            let gap = scrollSpeed * effectiveSeconds
            nextObstacleX = scene.size.width + gap
        }
        if nextPickupX < scene.size.width + 100 {
            spawnPickup(atX: scene.size.width + CGFloat.random(in: 80...200))
            nextPickupX = scene.size.width + CGFloat.random(in: 300...480)
        }
        if nextPortaPottyX < scene.size.width + 200 {
            spawnPortaPotty(atX: scene.size.width + CGFloat.random(in: 120...280))
            nextPortaPottyX = scene.size.width + CGFloat.random(in: 650...950)
        }
        if nextBgX < scene.size.width + 200 {
            spawnBackground(x: scene.size.width + CGFloat.random(in: 100...300), extended: false)
            nextBgX = scene.size.width + CGFloat.random(in: 200...500)
        }
        if nextOtherRunnerX < scene.size.width + 200 {
            spawnOtherRunner(atX: scene.size.width + CGFloat.random(in: 120...280), scrollSpeed: scrollSpeed)
            // ~1 runner every 10 seconds of travel
            let gapSeconds = CGFloat.random(in: 8...12)
            nextOtherRunnerX = scene.size.width + scrollSpeed * gapSeconds
        }

        // Aid stations
        for (i, aidPos) in aidStationPositions.enumerated() {
            if !spawnedAidStations.contains(i) && totalDistance > aidPos - CGFloat(scrollSpeed) * 2 {
                let fromRight = aidPos - totalDistance + scene.size.width
                if fromRight > 0 && fromRight < scene.size.width + 400 {
                    spawnAidStation(atX: max(scene.size.width + 100, fromRight), index: i)
                    spawnedAidStations.insert(i)
                }
            }
        }

        // Finish line: spawn once when near end of race
        let finishDistancePx = CGFloat(levelConfig.distanceKm) * GameConstants.distanceUnitsPerKm
        if !finishLineSpawned && totalDistance >= finishDistancePx - 800 {
            spawnFinishLine(atX: scene.size.width + 350)
            finishLineSpawned = true
        }
    }

    private func keepOrRemove(_ node: SKNode) -> Bool {
        if node.position.x < -300 { node.removeFromParent(); return false }
        return true
    }
    private func keepOrRemoveOffset(_ node: SKNode, offset: CGFloat) -> Bool {
        if node.position.x < offset { node.removeFromParent(); return false }
        return true
    }

    private func spawnObstacle(atX x: CGFloat) {
        guard let scene = scene else { return }
        let type = levelConfig.obstacleTypes.randomElement() ?? .rock
        let node = makeObstacleNode(type: type)
        node.position = CGPoint(x: x, y: groundY + obstacleHeight(type) / 2)
        node.zPosition = 10
        scene.addChild(node)
        obstacleNodes.append(node)

        // Occasional double-obstacle only on harder levels (gap scale <= 1)
        if levelConfig.obstacleGapScale <= 1.0 && Double.random(in: 0...1) < 0.08 {
            let node2 = makeObstacleNode(type: type)
            node2.position = CGPoint(x: x + CGFloat.random(in: 60...90), y: groundY + obstacleHeight(type) / 2)
            node2.zPosition = 10
            scene.addChild(node2)
            obstacleNodes.append(node2)
        }
    }

    private func obstacleHeight(_ t: ObstacleType) -> CGFloat {
        switch t {
        case .rock: return 28
        case .log: return 22
        case .mudPuddle: return 10
        case .cactus: return 55
        case .boulder: return 45
        case .crater: return 14
        case .tree: return 70
        case .vine: return 60
        case .waterCross: return 18
        case .fog: return 40
        case .sandDune: return 30
        case .building: return 80
        case .barrel: return 36
        default: return 28
        }
    }

    private func makeObstacleNode(type: ObstacleType) -> SKNode {
        let container = SKNode()
        switch type {
        case .rock, .root:
            let w = CGFloat.random(in: 28...42), h = CGFloat.random(in: 22...34)
            let shape = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
            shape.fillColor = UIColor(red:0.5,green:0.45,blue:0.4,alpha:1)
            shape.strokeColor = UIColor(red:0.3,green:0.25,blue:0.2,alpha:1)
            shape.lineWidth = 2
            container.addChild(shape)
            let pb = SKPhysicsBody(circleOfRadius: w/2 * 0.8)
            pb.isDynamic = false
            pb.categoryBitMask = PhysicsCategory.obstacle
            pb.contactTestBitMask = PhysicsCategory.player
            pb.collisionBitMask = 0
            container.physicsBody = pb
        case .log:
            let shape = SKShapeNode(rectOf: CGSize(width: 55, height: 20), cornerRadius: 6)
            shape.fillColor = UIColor(red:0.5,green:0.3,blue:0.15,alpha:1)
            shape.strokeColor = UIColor(red:0.3,green:0.15,blue:0.05,alpha:1)
            shape.lineWidth = 2
            container.addChild(shape)
            let pb = SKPhysicsBody(rectangleOf: CGSize(width: 50, height: 18))
            pb.isDynamic = false
            pb.categoryBitMask = PhysicsCategory.obstacle
            pb.contactTestBitMask = PhysicsCategory.player
            pb.collisionBitMask = 0
            container.physicsBody = pb
        case .cactus:
            let trunk = SKShapeNode(rectOf: CGSize(width: 14, height: 50), cornerRadius: 5)
            trunk.fillColor = UIColor(red:0.2,green:0.55,blue:0.2,alpha:1)
            trunk.strokeColor = UIColor(red:0.1,green:0.35,blue:0.1,alpha:1)
            trunk.lineWidth = 2
            container.addChild(trunk)
            let arm = SKShapeNode(rectOf: CGSize(width: 18, height: 10), cornerRadius: 4)
            arm.fillColor = UIColor(red:0.2,green:0.55,blue:0.2,alpha:1)
            arm.strokeColor = .clear
            arm.position = CGPoint(x: 12, y: 10)
            container.addChild(arm)
            let pb = SKPhysicsBody(rectangleOf: CGSize(width: 12, height: 48))
            pb.isDynamic = false
            pb.categoryBitMask = PhysicsCategory.obstacle
            pb.contactTestBitMask = PhysicsCategory.player
            pb.collisionBitMask = 0
            container.physicsBody = pb
        case .boulder:
            let shape = SKShapeNode(circleOfRadius: 22)
            shape.fillColor = UIColor(red:0.45,green:0.4,blue:0.38,alpha:1)
            shape.strokeColor = UIColor(red:0.25,green:0.2,blue:0.18,alpha:1)
            shape.lineWidth = 2
            container.addChild(shape)
            let pb = SKPhysicsBody(circleOfRadius: 20)
            pb.isDynamic = false
            pb.categoryBitMask = PhysicsCategory.obstacle
            pb.contactTestBitMask = PhysicsCategory.player
            pb.collisionBitMask = 0
            container.physicsBody = pb
        case .mudPuddle, .crater:
            let shape = SKShapeNode(ellipseOf: CGSize(width: 70, height: 12))
            let col = type == .mudPuddle ? UIColor(red:0.4,green:0.25,blue:0.1,alpha:0.9) :
                      UIColor(red:0.3,green:0.15,blue:0.1,alpha:0.9)
            shape.fillColor = col
            shape.strokeColor = col.withAlphaComponent(0.5)
            container.addChild(shape)
            let pb = SKPhysicsBody(rectangleOf: CGSize(width: 65, height: 10))
            pb.isDynamic = false
            pb.categoryBitMask = PhysicsCategory.obstacle
            pb.contactTestBitMask = PhysicsCategory.player
            pb.collisionBitMask = 0
            container.physicsBody = pb
        case .waterCross:
            // River crossing: wider strip of water that makes you wet
            let riverW: CGFloat = 90
            let riverH: CGFloat = 18
            let shape = SKShapeNode(ellipseOf: CGSize(width: riverW, height: riverH))
            shape.fillColor = UIColor(red:0.25,green:0.55,blue:0.95,alpha:0.85)
            shape.strokeColor = UIColor(red:0.15,green:0.4,blue:0.8,alpha:0.9)
            shape.lineWidth = 2
            container.addChild(shape)
            // Ripple lines
            for i in 0..<3 {
                let ripple = SKShapeNode(ellipseOf: CGSize(width: riverW - CGFloat(i * 18), height: riverH - CGFloat(i * 4)))
                ripple.fillColor = .clear
                ripple.strokeColor = UIColor.white.withAlphaComponent(0.25 - CGFloat(i) * 0.06)
                ripple.lineWidth = 1
                ripple.zPosition = -0.5
                container.addChild(ripple)
            }
            let pb = SKPhysicsBody(rectangleOf: CGSize(width: riverW - 8, height: riverH - 4))
            pb.isDynamic = false
            pb.categoryBitMask = PhysicsCategory.obstacle
            pb.contactTestBitMask = PhysicsCategory.player
            pb.collisionBitMask = 0
            container.physicsBody = pb
        case .barrel:
            let shape = SKShapeNode(rectOf: CGSize(width: 24, height: 34), cornerRadius: 4)
            shape.fillColor = UIColor(red:0.5,green:0.3,blue:0.1,alpha:1)
            shape.strokeColor = UIColor(red:0.3,green:0.1,blue:0.05,alpha:1)
            shape.lineWidth = 2
            container.addChild(shape)
            let pb = SKPhysicsBody(rectangleOf: CGSize(width: 22, height: 32))
            pb.isDynamic = false
            pb.categoryBitMask = PhysicsCategory.obstacle
            pb.contactTestBitMask = PhysicsCategory.player
            pb.collisionBitMask = 0
            container.physicsBody = pb
        default:
            let shape = SKShapeNode(circleOfRadius: 18)
            shape.fillColor = UIColor.gray
            container.addChild(shape)
            let pb = SKPhysicsBody(circleOfRadius: 16)
            pb.isDynamic = false
            pb.categoryBitMask = PhysicsCategory.obstacle
            pb.contactTestBitMask = PhysicsCategory.player
            pb.collisionBitMask = 0
            container.physicsBody = pb
        }
        container.name = "obstacle_\(type.rawValue)"
        // Danger indicator: red ring for most obstacles; blue "wet" hint for river crossings
        if type == .waterCross {
            let wetRing = SKShapeNode(circleOfRadius: 38)
            wetRing.fillColor = .clear
            wetRing.strokeColor = UIColor(red: 0.2, green: 0.5, blue: 1, alpha: 0.6)
            wetRing.lineWidth = 2
            wetRing.zPosition = -1
            container.addChild(wetRing)
            let wetIcon = SKLabelNode(text: "💦")
            wetIcon.fontSize = 20
            wetIcon.verticalAlignmentMode = .center
            wetIcon.position = CGPoint(x: 0, y: 28)
            wetIcon.zPosition = 10
            container.addChild(wetIcon)
        } else {
            let dangerRing = SKShapeNode(circleOfRadius: 28)
            dangerRing.fillColor = .clear
            dangerRing.strokeColor = UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.9)
            dangerRing.lineWidth = 3
            dangerRing.glowWidth = 2
            dangerRing.zPosition = -1
            container.addChild(dangerRing)
            let warnIcon = SKLabelNode(text: "⚠")
            warnIcon.fontSize = 18
            warnIcon.verticalAlignmentMode = .center
            warnIcon.position = CGPoint(x: 0, y: 22)
            warnIcon.zPosition = 10
            container.addChild(warnIcon)
        }
        return container
    }

    private func spawnPickup(atX x: CGFloat) {
        guard let scene = scene else { return }
        // Random pickup type
        let roll = Int.random(in: 0...9)
        let pickupType: PickupType
        let emoji: String
        switch roll {
        case 0: pickupType = .water;    emoji = "💧"
        case 1: pickupType = .gel;      emoji = "⚡"
        case 2: pickupType = .salt;     emoji = "🧂"
        case 3: pickupType = .gummyBear;emoji = "🐻"
        case 4: pickupType = .banana;   emoji = "🍌"
        case 5: pickupType = .cola;     emoji = "🥤"
        case 6: pickupType = .pretzel;  emoji = "🥨"
        case 7: pickupType = .medkit;   emoji = "🩺"
        case 8: pickupType = .bathroom; emoji = "🚻"
        default: pickupType = .trashCan; emoji = "🗑"
        }

        let bg = SKShapeNode(circleOfRadius: 18)
        bg.fillColor = pickupType == .bathroom ? UIColor(red:0.1,green:0.3,blue:0.8,alpha:0.85) :
                       pickupType == .trashCan ? UIColor(red:0.2,green:0.2,blue:0.2,alpha:0.85) :
                       UIColor(red:0.15,green:0.6,blue:0.3,alpha:0.85)
        bg.strokeColor = UIColor.white.withAlphaComponent(0.6)
        bg.lineWidth = 2
        // Friendly "tap to collect" glow so goodies are clearly helpful
        let helpRing = SKShapeNode(circleOfRadius: 26)
        helpRing.fillColor = UIColor(red: 0.2, green: 1, blue: 0.4, alpha: 0.15)
        helpRing.strokeColor = UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 0.7)
        helpRing.lineWidth = 2
        helpRing.glowWidth = 1
        helpRing.zPosition = -1
        bg.addChild(helpRing)
        helpRing.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.08, duration: 0.6),
            SKAction.fadeAlpha(to: 0.25, duration: 0.6)
        ])))

        let label = SKLabelNode(text: emoji)
        label.fontSize = 22
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        bg.addChild(label)

        bg.position = CGPoint(x: x, y: groundY + 35)
        bg.zPosition = 12
        bg.name = "pickup_\(pickupType)"

        let pb = SKPhysicsBody(circleOfRadius: 16)
        pb.isDynamic = false
        pb.categoryBitMask = PhysicsCategory.pickup
        pb.contactTestBitMask = PhysicsCategory.player
        pb.collisionBitMask = 0
        bg.physicsBody = pb

        // Bob animation
        let bob = SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 8, duration: 0.6),
            SKAction.moveBy(x: 0, y: -8, duration: 0.6)
        ]))
        bg.run(bob)

        scene.addChild(bg)
        pickupNodes.append(bg)
    }

    /// Spawns a non-blocking other runner (visual only, no physics — tap to pass for messages).
    /// Most are slower (player passes them); occasionally one is faster (passes the player).
    private func spawnOtherRunner(atX x: CGFloat, scrollSpeed: CGFloat) {
        guard let scene = scene else { return }
        let runner = OtherRunner()
        // ~12% chance: faster than player (they pass you); rest: slower (you pass them)
        if Double.random(in: 0...1) < 0.12 {
            runner.speedFactor = CGFloat.random(in: 1.05...1.28)
        } else {
            runner.speedFactor = CGFloat.random(in: 0.5...0.92)
        }
        runner.position = CGPoint(x: x, y: groundY + 40)
        runner.zPosition = 18
        scene.addChild(runner)
        otherRunnerNodes.append(runner)
    }

    func spawnAidStation(atX x: CGFloat, index: Int) {
        guard let scene = scene else { return }
        // Tent structure
        let container = SKNode()
        container.position = CGPoint(x: x, y: groundY)
        container.zPosition = 15
        container.name = "aidstation_\(index)"

        let tent = SKShapeNode()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -50, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 65))
        path.addLine(to: CGPoint(x: 50, y: 0))
        path.close()
        tent.path = path.cgPath
        tent.fillColor = UIColor(red:0.9,green:0.2,blue:0.2,alpha:1)
        tent.strokeColor = UIColor.white
        tent.lineWidth = 2.5
        container.addChild(tent)

        let cross = SKLabelNode(text: "🏕")
        cross.fontSize = 30
        cross.position = CGPoint(x: 0, y: 20)
        container.addChild(cross)

        let aidLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        aidLbl.text = "AID \(index+1)"
        aidLbl.fontSize = 14
        aidLbl.fontColor = .white
        aidLbl.position = CGPoint(x: 0, y: 75)
        container.addChild(aidLbl)

        // Glow
        let glow = SKShapeNode(circleOfRadius: 60)
        glow.fillColor = UIColor(red:1,green:0.9,blue:0.2,alpha:0.12)
        glow.strokeColor = UIColor(red:1,green:0.9,blue:0.2,alpha:0.3)
        glow.lineWidth = 2
        glow.zPosition = -1
        container.addChild(glow)
        glow.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.05, duration: 0.8),
            SKAction.fadeAlpha(to: 0.25, duration: 0.8)
        ])))

        // Physics trigger
        let triggerBody = SKPhysicsBody(rectangleOf: CGSize(width: 80, height: 80))
        triggerBody.isDynamic = false
        triggerBody.categoryBitMask = PhysicsCategory.pickup
        triggerBody.contactTestBitMask = PhysicsCategory.player
        triggerBody.collisionBitMask = 0
        container.physicsBody = triggerBody

        scene.addChild(container)
        pickupNodes.append(container)
    }

    func spawnPortaPotty(atX x: CGFloat) {
        guard let scene = scene else { return }
        let container = SKNode()
        container.position = CGPoint(x: x, y: groundY)
        container.zPosition = 14
        container.name = "portapotty"

        // Porta potty shape: blue box with door and roof
        let boxW: CGFloat = 52
        let boxH: CGFloat = 72
        let box = SKShapeNode(rectOf: CGSize(width: boxW, height: boxH), cornerRadius: 4)
        box.fillColor = UIColor(red: 0.15, green: 0.35, blue: 0.75, alpha: 1)
        box.strokeColor = UIColor(red: 0.1, green: 0.25, blue: 0.6, alpha: 1)
        box.lineWidth = 2
        container.addChild(box)

        // Door rectangle (darker)
        let doorW: CGFloat = 22
        let doorH: CGFloat = 50
        let door = SKShapeNode(rectOf: CGSize(width: doorW, height: doorH), cornerRadius: 2)
        door.fillColor = UIColor(red: 0.08, green: 0.2, blue: 0.5, alpha: 1)
        door.strokeColor = UIColor(red: 0.05, green: 0.15, blue: 0.4, alpha: 1)
        door.lineWidth = 1
        door.position = CGPoint(x: -6, y: -2)
        container.addChild(door)

        // Roof / vent
        let roof = SKShapeNode(rectOf: CGSize(width: boxW + 8, height: 12), cornerRadius: 2)
        roof.fillColor = UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1)
        roof.strokeColor = UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1)
        roof.lineWidth = 1
        roof.position = CGPoint(x: 0, y: boxH/2 + 6)
        container.addChild(roof)

        let icon = SKLabelNode(text: "🚻")
        icon.fontSize = 28
        icon.verticalAlignmentMode = .center
        icon.position = CGPoint(x: 8, y: 0)
        container.addChild(icon)

        // Tap hint glow
        let glow = SKShapeNode(rectOf: CGSize(width: boxW + 24, height: boxH + 24), cornerRadius: 8)
        glow.fillColor = UIColor(red: 0.2, green: 0.5, blue: 1, alpha: 0.12)
        glow.strokeColor = UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.5)
        glow.lineWidth = 2
        glow.zPosition = -1
        container.addChild(glow)
        glow.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.06, duration: 0.7),
            SKAction.fadeAlpha(to: 0.22, duration: 0.7)
        ])))

        let triggerBody = SKPhysicsBody(rectangleOf: CGSize(width: boxW + 20, height: boxH + 20))
        triggerBody.isDynamic = false
        triggerBody.categoryBitMask = PhysicsCategory.pickup
        triggerBody.contactTestBitMask = PhysicsCategory.player
        triggerBody.collisionBitMask = 0
        container.physicsBody = triggerBody

        scene.addChild(container)
        portaPottyNodes.append(container)
    }

    func spawnFinishLine(atX x: CGFloat) {
        guard let scene = scene else { return }
        let container = SKNode()
        container.position = CGPoint(x: x, y: groundY)
        container.zPosition = 16
        container.name = "finish_line"

        let poleHeight: CGFloat = 100
        let tapeWidth: CGFloat = 180
        let poleSpacing: CGFloat = 160

        // Left pole
        let leftPole = SKShapeNode(rectOf: CGSize(width: 8, height: poleHeight))
        leftPole.fillColor = UIColor.white
        leftPole.strokeColor = UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1)
        leftPole.lineWidth = 1
        leftPole.position = CGPoint(x: -poleSpacing / 2, y: poleHeight / 2)
        container.addChild(leftPole)

        // Right pole
        let rightPole = SKShapeNode(rectOf: CGSize(width: 8, height: poleHeight))
        rightPole.fillColor = UIColor.white
        rightPole.strokeColor = UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1)
        rightPole.lineWidth = 1
        rightPole.position = CGPoint(x: poleSpacing / 2, y: poleHeight / 2)
        container.addChild(rightPole)

        // Checkered finish tape (horizontal banner)
        let cellSize: CGFloat = 14
        let cols = Int(tapeWidth / cellSize) + 1
        let rows = 4
        for row in 0..<rows {
            for col in 0..<cols {
                let cell = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize))
                let isBlack = (row + col) % 2 == 0
                cell.fillColor = isBlack ? .black : .white
                cell.strokeColor = .clear
                cell.position = CGPoint(
                    x: -tapeWidth / 2 + CGFloat(col) * cellSize + cellSize / 2,
                    y: poleHeight - 8 - CGFloat(row) * cellSize - cellSize / 2
                )
                container.addChild(cell)
            }
        }

        // Finishing flags (triangular) on both poles
        let flagColors: [UIColor] = [
            UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 1),
            UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1),
            UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1),
            UIColor(red: 0.2, green: 0.4, blue: 1, alpha: 1),
        ]
        for (poleX, side) in [(CGFloat(-poleSpacing / 2), CGFloat(1)), (CGFloat(poleSpacing / 2), CGFloat(-1))] {
            for i in 0..<4 {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: side * 22, y: 0))
                path.addLine(to: CGPoint(x: side * 22, y: 18))
                path.close()
                let flag = SKShapeNode(path: path.cgPath)
                flag.fillColor = flagColors[i]
                flag.strokeColor = flag.fillColor.withAlphaComponent(0.8)
                flag.lineWidth = 1
                flag.position = CGPoint(x: poleX + side * 6, y: poleHeight - 20 - CGFloat(i) * 20)
                flag.zRotation = side > 0 ? 0 : .pi
                container.addChild(flag)
            }
        }

        // "FINISH" label
        let finishLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        finishLbl.text = "FINISH"
        finishLbl.fontSize = 20
        finishLbl.fontColor = UIColor(red: 1, green: 0.9, blue: 0.2, alpha: 1)
        finishLbl.position = CGPoint(x: 0, y: poleHeight + 18)
        finishLbl.zPosition = 1
        container.addChild(finishLbl)

        // Subtle glow
        let glow = SKShapeNode(rectOf: CGSize(width: tapeWidth + 60, height: poleHeight + 30))
        glow.fillColor = UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 0.08)
        glow.strokeColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.25)
        glow.lineWidth = 2
        glow.zPosition = -1
        glow.position = CGPoint(x: 0, y: poleHeight / 2 + 10)
        container.addChild(glow)
        glow.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.04, duration: 0.6),
            SKAction.fadeAlpha(to: 0.15, duration: 0.6)
        ])))

        scene.addChild(container)
        finishLineNodes.append(container)
    }

    private func spawnBackground(x: CGFloat, extended: Bool) {
        guard let scene = scene else { return }
        let spread = extended ? 4 : 1
        for _ in 0..<spread {
            let rx = extended ? CGFloat.random(in: 0...scene.size.width) : x + CGFloat.random(in: -50...50)
            for type in levelConfig.bgElements {
                if Double.random(in: 0...1) < 0.5 {
                    makeBgElement(type: type, x: rx, scene: scene)
                }
            }
        }
    }

    private func makeBgElement(type: BgElementType, x: CGFloat, scene: SKScene) {
        switch type {
        case .mountain:
            let h = CGFloat.random(in: 120...250)
            let w = h * CGFloat.random(in: 0.8...1.4)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -w/2, y: 0))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: w/2, y: 0))
            path.close()
            let shape = SKShapeNode(path: path.cgPath)
            shape.fillColor = UIColor(red: CGFloat.random(in:0.3...0.5), green: CGFloat.random(in:0.3...0.5), blue: CGFloat.random(in:0.4...0.6), alpha: CGFloat.random(in: 0.5...0.9))
            shape.strokeColor = .clear
            shape.position = CGPoint(x: x, y: groundY)
            shape.zPosition = 2
            scene.addChild(shape)
            bgNodes.append(shape)
            // Snow cap
            if h > 160 {
                let snowPath = UIBezierPath()
                snowPath.move(to: CGPoint(x: -w*0.15, y: h*0.7))
                snowPath.addLine(to: CGPoint(x: 0, y: h))
                snowPath.addLine(to: CGPoint(x: w*0.15, y: h*0.7))
                snowPath.close()
                let snow = SKShapeNode(path: snowPath.cgPath)
                snow.fillColor = UIColor.white.withAlphaComponent(0.85)
                snow.strokeColor = .clear
                snow.position = CGPoint(x: x, y: groundY)
                snow.zPosition = 3
                scene.addChild(snow)
                bgNodes.append(snow)
            }
        case .tree:
            let h = CGFloat.random(in: 50...100)
            let trunk = SKShapeNode(rectOf: CGSize(width: 8, height: h * 0.4), cornerRadius: 2)
            trunk.fillColor = UIColor(red:0.4,green:0.25,blue:0.1,alpha:0.9)
            trunk.strokeColor = .clear
            trunk.position = CGPoint(x: x, y: groundY + h*0.2)
            trunk.zPosition = 3
            scene.addChild(trunk)
            bgNodes.append(trunk)
            let canopy = SKShapeNode(circleOfRadius: h * 0.35)
            canopy.fillColor = levelConfig.accentColor.withAlphaComponent(CGFloat.random(in:0.6...0.9))
            canopy.strokeColor = .clear
            canopy.position = CGPoint(x: x, y: groundY + h * 0.55)
            canopy.zPosition = 4
            scene.addChild(canopy)
            bgNodes.append(canopy)
        case .cactus:
            let node = SKLabelNode(text: "🌵")
            node.fontSize = CGFloat.random(in: 30...60)
            node.position = CGPoint(x: x, y: groundY)
            node.zPosition = 4
            scene.addChild(node)
            bgNodes.append(node)
        case .building:
            let h = CGFloat.random(in: 80...200)
            let w = CGFloat.random(in: 40...80)
            let bld = SKShapeNode(rectOf: CGSize(width: w, height: h))
            bld.fillColor = UIColor(red: CGFloat.random(in:0.3...0.6), green: CGFloat.random(in:0.3...0.6), blue: CGFloat.random(in:0.35...0.65), alpha: CGFloat.random(in:0.6...0.9))
            bld.strokeColor = UIColor.white.withAlphaComponent(0.15)
            bld.lineWidth = 1
            bld.position = CGPoint(x: x, y: groundY + h/2)
            bld.zPosition = 2
            scene.addChild(bld)
            bgNodes.append(bld)
        case .redwood:
            let h = CGFloat.random(in: 150...300)
            let trunk = SKShapeNode(rectOf: CGSize(width: 18, height: h), cornerRadius: 4)
            trunk.fillColor = UIColor(red:0.45,green:0.25,blue:0.12,alpha:0.85)
            trunk.strokeColor = .clear
            trunk.position = CGPoint(x: x, y: groundY + h/2)
            trunk.zPosition = 3
            scene.addChild(trunk)
            bgNodes.append(trunk)
        case .canyon:
            let h = CGFloat.random(in: 80...180)
            let w: CGFloat = 30
            let wall = SKShapeNode(rectOf: CGSize(width: w, height: h))
            let shade = CGFloat.random(in: 0.1...0.3)
            wall.fillColor = UIColor(red:0.6+shade, green:0.3+shade*0.5, blue:0.1+shade*0.3, alpha: 0.8)
            wall.strokeColor = .clear
            wall.position = CGPoint(x: x, y: groundY + h/2)
            wall.zPosition = 2
            scene.addChild(wall)
            bgNodes.append(wall)
        case .swamp:
            let node = SKLabelNode(text: Bool.random() ? "🌿" : "🪴")
            node.fontSize = CGFloat.random(in: 25...50)
            node.position = CGPoint(x: x, y: groundY)
            node.zPosition = 4
            scene.addChild(node)
            bgNodes.append(node)
        case .crater:
            let r = CGFloat.random(in: 20...50)
            let shape = SKShapeNode(ellipseOf: CGSize(width: r*2, height: r*0.4))
            shape.fillColor = UIColor(red:0.45,green:0.2,blue:0.12,alpha:0.7)
            shape.strokeColor = UIColor(red:0.6,green:0.3,blue:0.15,alpha:0.5)
            shape.lineWidth = 2
            shape.position = CGPoint(x: x, y: groundY - 5)
            shape.zPosition = 2
            scene.addChild(shape)
            bgNodes.append(shape)
        case .sand:
            let dune = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in:80...200), height: CGFloat.random(in:15...35)))
            dune.fillColor = UIColor(red:0.85,green:0.72,blue:0.45,alpha:0.6)
            dune.strokeColor = .clear
            dune.position = CGPoint(x: x, y: groundY - 5)
            dune.zPosition = 4
            scene.addChild(dune)
            bgNodes.append(dune)
        }
    }
}
