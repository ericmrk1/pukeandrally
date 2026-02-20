import SpriteKit

class GameOverScene: SKScene {

    var finalScore: Int = 0
    var elapsedTime: Double = 0
    var levelIndex: Int = 0
    var levelName: String = ""

    override func didMove(to view: SKView) {
        setupUI()
        celebrate()
    }

    private func setupUI() {
        let level = levelIndex < ALL_LEVELS.count ? ALL_LEVELS[levelIndex] : ALL_LEVELS[0]
        backgroundColor = UIColor(red:0.05,green:0.05,blue:0.12,alpha:1)

        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = level.skyTop.withAlphaComponent(0.3)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(bg)

        // Trophy
        let trophy = SKLabelNode(text: medal(for: finalScore))
        trophy.fontSize = 70
        trophy.position = CGPoint(x: size.width/2, y: size.height * 0.83)
        trophy.zPosition = 10
        addChild(trophy)
        trophy.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.7),
            SKAction.scale(to: 0.95, duration: 0.7)
        ])))

        let finishLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        finishLbl.text = "RACE COMPLETE! 🎉"
        finishLbl.fontSize = 36
        finishLbl.fontColor = UIColor(red:1,green:0.85,blue:0.2,alpha:1)
        finishLbl.position = CGPoint(x: size.width/2, y: size.height * 0.72)
        finishLbl.zPosition = 10
        addChild(finishLbl)

        let levelLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        levelLbl.text = levelName
        levelLbl.fontSize = 20
        levelLbl.fontColor = UIColor.white.withAlphaComponent(0.9)
        levelLbl.position = CGPoint(x: size.width/2, y: size.height * 0.64)
        levelLbl.zPosition = 10
        addChild(levelLbl)

        // Score card
        let card = SKShapeNode(rectOf: CGSize(width: size.width * 0.6, height: 160), cornerRadius: 18)
        card.fillColor = UIColor.black.withAlphaComponent(0.55)
        card.strokeColor = UIColor.white.withAlphaComponent(0.2)
        card.lineWidth = 1.5
        card.position = CGPoint(x: size.width/2, y: size.height * 0.47)
        card.zPosition = 10
        addChild(card)

        let mins = Int(elapsedTime)/60
        let secs = Int(elapsedTime)%60
        let rows: [(String, String)] = [
            ("⭐ FINAL SCORE", String(format: "%,d", finalScore).replacingOccurrences(of: ",", with: ",")),
            ("⏱ FINISH TIME", String(format: "%d:%02d", mins, secs)),
            ("🏅 GRADE", grade(for: finalScore))
        ]

        for (i, (key, val)) in rows.enumerated() {
            let y = 50.0 - Double(i) * 48.0
            let kLbl = SKLabelNode(fontNamed: "AvenirNext-Regular")
            kLbl.text = key
            kLbl.fontSize = 14
            kLbl.fontColor = UIColor.white.withAlphaComponent(0.7)
            kLbl.horizontalAlignmentMode = .left
            kLbl.position = CGPoint(x: -110, y: y - 8)
            card.addChild(kLbl)

            let vLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            vLbl.text = val
            vLbl.fontSize = i == 0 ? 28 : 20
            vLbl.fontColor = i == 0 ? UIColor(red:1,green:0.85,blue:0.2,alpha:1) : .white
            vLbl.horizontalAlignmentMode = .right
            vLbl.position = CGPoint(x: 110, y: y - 8)
            card.addChild(vLbl)
        }

        // Best score comparison
        let scores = UserDefaults.standard.array(forKey: "highscores_\(levelIndex)") as? [[String:Any]] ?? []
        if let best = scores.first, let bestSc = best["score"] as? Int, bestSc == finalScore {
            let newBest = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            newBest.text = "🆕 NEW PERSONAL BEST!"
            newBest.fontSize = 16
            newBest.fontColor = UIColor(red:0.3,green:1,blue:0.5,alpha:1)
            newBest.position = CGPoint(x: size.width/2, y: size.height * 0.34)
            newBest.zPosition = 10
            addChild(newBest)
            newBest.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.4, duration: 0.4),
                SKAction.fadeAlpha(to: 1.0, duration: 0.4)
            ])))
        }

        // Buttons
        makeButton(text: "▶  PLAY AGAIN", at: CGPoint(x: size.width/2 - 155, y: size.height * 0.18),
                   color: UIColor(red:0.2,green:0.65,blue:0.3,alpha:1), name: "again", w: 240)
        makeButton(text: "🗺 COURSES", at: CGPoint(x: size.width/2 + 55, y: size.height * 0.18),
                   color: UIColor(red:0.2,green:0.3,blue:0.7,alpha:1), name: "levels", w: 180)
        makeButton(text: "🏠 MENU", at: CGPoint(x: size.width/2 + 220, y: size.height * 0.18),
                   color: UIColor(red:0.35,green:0.35,blue:0.45,alpha:1), name: "menu", w: 150)
    }

    private func makeButton(text: String, at pos: CGPoint, color: UIColor, name: String, w: CGFloat) {
        let btn = SKShapeNode(rectOf: CGSize(width: w, height: 46), cornerRadius: 13)
        btn.fillColor = color
        btn.strokeColor = UIColor.white.withAlphaComponent(0.2)
        btn.lineWidth = 1
        btn.position = pos
        btn.zPosition = 10
        btn.name = name
        let lbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        lbl.text = text
        lbl.fontSize = 17
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        addChild(btn)
    }

    private func celebrate() {
        for _ in 0..<30 {
            let conf = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in:6...14), height: CGFloat.random(in:6...14)), cornerRadius: 2)
            conf.fillColor = UIColor(hue: CGFloat.random(in:0...1), saturation: 0.9, brightness: 0.9, alpha: 1)
            conf.strokeColor = .clear
            conf.position = CGPoint(x: CGFloat.random(in:0...size.width), y: size.height + 10)
            conf.zPosition = 150
            addChild(conf)
            conf.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in:-80...80), y: -size.height - 20, duration: Double.random(in:2...4)),
                    SKAction.rotate(byAngle: .pi * CGFloat.random(in:4...10), duration: Double.random(in:2...4))
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func medal(for score: Int) -> String {
        if score > 5000 { return "🥇" }
        if score > 3000 { return "🥈" }
        if score > 1500 { return "🥉" }
        return "🏅"
    }

    private func grade(for score: Int) -> String {
        if score > 5000 { return "ELITE 🌟" }
        if score > 3500 { return "ULTRA 💪" }
        if score > 2000 { return "TRAIL PRO 🏔" }
        if score > 1000 { return "FINISHER 🎽" }
        return "PARTICIPANT 🏃"
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        for node in nodes(at: loc) {
            switch node.name {
            case "again":
                let scene = GameScene(size: size)
                scene.scaleMode = .aspectFill
                scene.levelConfig = ALL_LEVELS[levelIndex]
                scene.levelIndex = levelIndex
                view?.presentScene(scene, transition: SKTransition.doorway(withDuration: 0.5))
            case "levels":
                let scene = LevelSelectScene(size: size)
                scene.scaleMode = .aspectFill
                view?.presentScene(scene, transition: SKTransition.push(with: .right, duration: 0.4))
            case "menu":
                let scene = MainMenuScene(size: size)
                scene.scaleMode = .aspectFill
                view?.presentScene(scene, transition: SKTransition.fade(withDuration: 0.5))
            default: break
            }
        }
    }
}
