import SpriteKit
import UIKit

class LevelSelectScene: SKScene {

    override func didMove(to view: SKView) {
        setupUI()
    }

    private func setupUI() {
        backgroundColor = UIColor(red:0.06,green:0.06,blue:0.12,alpha:1)

        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = UIColor(red:0.06,green:0.07,blue:0.15,alpha:1)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(bg)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "SELECT COURSE"
        title.fontSize = 34
        title.fontColor = UIColor(red:1,green:0.85,blue:0.2,alpha:1)
        title.position = CGPoint(x: size.width/2, y: size.height - 45)
        title.zPosition = 10
        addChild(title)

        // Back button
        let backBtn = SKShapeNode(rectOf: CGSize(width: 90, height: 36), cornerRadius: 10)
        backBtn.fillColor = UIColor(red:0.3,green:0.3,blue:0.4,alpha:1)
        backBtn.strokeColor = .clear
        backBtn.position = CGPoint(x: 60, y: size.height - 40)
        backBtn.zPosition = 10
        backBtn.name = "back"
        let backLbl = SKLabelNode(text: "← Back")
        backLbl.fontName = "AvenirNext-Bold"
        backLbl.fontSize = 14
        backLbl.fontColor = .white
        backLbl.verticalAlignmentMode = .center
        backLbl.isUserInteractionEnabled = false
        backBtn.addChild(backLbl)
        addChild(backBtn)

        // Level grid
        let cols = 4
        let cardW: CGFloat = size.width * 0.22
        let cardH: CGFloat = size.height * 0.35
        let hPad: CGFloat = size.width * 0.025
        let totalW = CGFloat(cols) * cardW + CGFloat(cols-1) * hPad
        let startX = (size.width - totalW) / 2 + cardW/2

        for (i, level) in ALL_LEVELS.enumerated() {
            let row = i / cols
            let col = i % cols
            let x = startX + CGFloat(col) * (cardW + hPad)
            let y = size.height * 0.62 - CGFloat(row) * (cardH + 14)

            let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 14)
            card.fillColor = level.skyBottom.withAlphaComponent(0.85)
            card.strokeColor = UIColor.white.withAlphaComponent(0.3)
            card.lineWidth = 1.5
            card.position = CGPoint(x: x, y: y)
            card.zPosition = 10
            card.name = "level_\(i)"
            addChild(card)

            // Sky gradient overlay
            let skyTop = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH * 0.5), cornerRadius: 0)
            skyTop.fillColor = level.skyTop.withAlphaComponent(0.7)
            skyTop.strokeColor = .clear
            skyTop.position = CGPoint(x: 0, y: cardH * 0.25)
            card.addChild(skyTop)

            // Ground strip
            let ground = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH * 0.28))
            ground.fillColor = level.groundColor
            ground.strokeColor = .clear
            ground.position = CGPoint(x: 0, y: -cardH * 0.38)
            card.addChild(ground)

            // Level name
            let nameLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            nameLbl.text = level.name
            nameLbl.fontSize = 12
            nameLbl.fontColor = .white
            nameLbl.numberOfLines = 2
            nameLbl.preferredMaxLayoutWidth = cardW - 10
            nameLbl.position = CGPoint(x: 0, y: cardH*0.35)
            nameLbl.verticalAlignmentMode = .top
            card.addChild(nameLbl)

            // Subtitle
            let sub = SKLabelNode(fontNamed: "AvenirNext-Regular")
            sub.text = level.subtitle
            sub.fontSize = 9
            sub.fontColor = UIColor.white.withAlphaComponent(0.8)
            sub.position = CGPoint(x: 0, y: cardH*0.18)
            card.addChild(sub)

            // Distance badge
            let distBg = SKShapeNode(rectOf: CGSize(width: cardW - 10, height: 20), cornerRadius: 6)
            distBg.fillColor = UIColor.black.withAlphaComponent(0.4)
            distBg.strokeColor = .clear
            distBg.position = CGPoint(x: 0, y: -cardH*0.4 + 12)
            card.addChild(distBg)

            let distLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
            distLbl.text = "\(level.distanceKm)km • \(level.aidStations) Aid Stations"
            distLbl.fontSize = 9
            distLbl.fontColor = UIColor(red:0.8,green:1,blue:0.8,alpha:1)
            distLbl.verticalAlignmentMode = .center
            distBg.addChild(distLbl)

            // Best score
            let scores = UserDefaults.standard.array(forKey: "highscores_\(i)") as? [[String:Any]] ?? []
            if let best = scores.first, let sc = best["score"] as? Int {
                let scoreLbl = SKLabelNode(fontNamed: "AvenirNext-Regular")
                scoreLbl.text = "⭐ \(sc)"
                scoreLbl.fontSize = 10
                scoreLbl.fontColor = UIColor(red:1,green:0.85,blue:0.2,alpha:1)
                scoreLbl.position = CGPoint(x: 0, y: -cardH*0.22)
                card.addChild(scoreLbl)
            }

            // Hover effect
            card.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.01, duration: Double.random(in:1.5...2.5)),
                SKAction.scale(to: 0.99, duration: Double.random(in:1.5...2.5))
            ])))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let nodes = nodes(at: loc)
        for node in nodes {
            guard let name = node.name else { continue }
            if name == "back" {
                let scene = MainMenuScene(size: size)
                scene.scaleMode = .aspectFill
                view?.presentScene(scene, transition: SKTransition.push(with: .right, duration: 0.4))
                return
            }
            if name.hasPrefix("level_") {
                let idx = Int(name.replacingOccurrences(of: "level_", with: "")) ?? 0
                node.run(SKAction.sequence([
                    SKAction.scale(to: 0.93, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.1),
                    SKAction.run { [weak self] in
                        guard let self = self else { return }
                        let scene = GameScene(size: self.size)
                        scene.scaleMode = .aspectFill
                        scene.levelConfig = ALL_LEVELS[idx]
                        scene.levelIndex = idx
                        self.view?.presentScene(scene, transition: SKTransition.doorway(withDuration: 0.6))
                    }
                ]))
                return
            }
        }
    }
}
