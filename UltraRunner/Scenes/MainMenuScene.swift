import SpriteKit

class MainMenuScene: SKScene {

    override func didMove(to view: SKView) {
        setupUI()
        animateBackground()
    }

    private func setupUI() {
        backgroundColor = UIColor(red:0.05,green:0.05,blue:0.1,alpha:1)

        // Animated gradient bg
        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = UIColor(red:0.05,green:0.08,blue:0.18,alpha:1)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
        bg.zPosition = 0
        addChild(bg)

        // Title
        let titleBg = SKShapeNode(rectOf: CGSize(width: size.width * 0.7, height: 90), cornerRadius: 16)
        titleBg.fillColor = UIColor(red:0.1,green:0.15,blue:0.3,alpha:0.8)
        titleBg.strokeColor = UIColor(red:0.3,green:0.6,blue:1,alpha:0.5)
        titleBg.lineWidth = 2
        titleBg.position = CGPoint(x: size.width/2, y: size.height * 0.82)
        titleBg.zPosition = 10
        addChild(titleBg)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "🏃 ULTRA RUNNER"
        title.fontSize = 46
        title.fontColor = UIColor(red:1,green:0.85,blue:0.2,alpha:1)
        title.position = CGPoint(x: size.width/2, y: size.height * 0.8)
        title.zPosition = 11
        addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Bold")
        subtitle.text = "Trail & Ultra Running Adventure"
        subtitle.fontSize = 18
        subtitle.fontColor = UIColor(red:0.7,green:0.85,blue:1,alpha:0.9)
        subtitle.position = CGPoint(x: size.width/2, y: size.height * 0.73)
        subtitle.zPosition = 11
        addChild(subtitle)

        // Play button
        makeButton(text: "▶  PLAY", at: CGPoint(x: size.width/2, y: size.height * 0.55),
                   color: UIColor(red:0.2,green:0.7,blue:0.3,alpha:1), name: "play")

        // High Scores button
        makeButton(text: "🏆 HIGH SCORES", at: CGPoint(x: size.width/2, y: size.height * 0.41),
                   color: UIColor(red:0.6,green:0.4,blue:0.1,alpha:1), name: "scores")

        // How to play
        makeButton(text: "❓ HOW TO PLAY", at: CGPoint(x: size.width/2, y: size.height * 0.27),
                   color: UIColor(red:0.2,green:0.3,blue:0.6,alpha:1), name: "help")

        // Decorative runners
        for i in 0..<4 {
            let runner = SKLabelNode(text: "🏃")
            runner.fontSize = CGFloat.random(in: 20...40)
            runner.position = CGPoint(x: CGFloat(i) * size.width / 3, y: size.height * 0.14)
            runner.zPosition = 5
            addChild(runner)
            let run = SKAction.repeatForever(SKAction.sequence([
                SKAction.moveBy(x: size.width, y: 0, duration: Double.random(in: 3...6)),
                SKAction.moveBy(x: -size.width, y: 0, duration: 0)
            ]))
            runner.run(run)
        }

        // Version
        let ver = SKLabelNode(fontNamed: "AvenirNext-Regular")
        ver.text = "v1.0 • Made for Trail Runners"
        ver.fontSize = 11
        ver.fontColor = UIColor.white.withAlphaComponent(0.4)
        ver.position = CGPoint(x: size.width/2, y: 14)
        ver.zPosition = 10
        addChild(ver)
    }

    private func makeButton(text: String, at pos: CGPoint, color: UIColor, name: String) {
        let btn = SKShapeNode(rectOf: CGSize(width: 280, height: 52), cornerRadius: 14)
        btn.fillColor = color
        btn.strokeColor = UIColor.white.withAlphaComponent(0.25)
        btn.lineWidth = 1.5
        btn.position = pos
        btn.zPosition = 10
        btn.name = name

        let lbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        lbl.text = text
        lbl.fontSize = 22
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)

        addChild(btn)
        // Subtle pulse
        btn.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.02, duration: 1.0),
            SKAction.scale(to: 0.98, duration: 1.0)
        ])))
    }

    private func animateBackground() {
        // Stars
        for _ in 0..<50 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
            star.fillColor = UIColor.white.withAlphaComponent(CGFloat.random(in:0.2...0.8))
            star.strokeColor = .clear
            star.position = CGPoint(x: CGFloat.random(in:0...size.width), y: CGFloat.random(in: size.height*0.3...size.height))
            star.zPosition = 1
            addChild(star)
            star.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.1, duration: Double.random(in:0.5...2.0)),
                SKAction.fadeAlpha(to: 0.8, duration: Double.random(in:0.5...2.0))
            ])))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let nodes = nodes(at: loc)
        for node in nodes {
            switch node.name {
            case "play":
                let scene = LevelSelectScene(size: size)
                scene.scaleMode = .aspectFill
                view?.presentScene(scene, transition: SKTransition.push(with: .left, duration: 0.4))
                node.run(SKAction.scale(to: 0.9, duration: 0.1))
            case "scores":
                showHighScores()
                node.run(SKAction.scale(to: 0.9, duration: 0.1))
            case "help":
                showHelp()
                node.run(SKAction.scale(to: 0.9, duration: 0.1))
            case "close_overlay":
                removeChildren(in: nodes(at: CGPoint(x: size.width/2, y: size.height/2)).filter { $0.name == "overlay" })
                childNode(withName: "overlay")?.removeFromParent()
            default: break
            }
        }
    }

    private func showHighScores() {
        let overlay = makeOverlay(title: "🏆 HIGH SCORES")

        var yOff: CGFloat = 100
        for (lIdx, level) in ALL_LEVELS.enumerated() {
            let scores = UserDefaults.standard.array(forKey: "highscores_\(lIdx)") as? [[String:Any]] ?? []
            if scores.isEmpty { continue }

            let lbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            lbl.text = level.name
            lbl.fontSize = 14
            lbl.fontColor = UIColor(red:1,green:0.85,blue:0.2,alpha:1)
            lbl.position = CGPoint(x: 0, y: yOff)
            overlay.addChild(lbl)
            yOff -= 20

            for (rank, entry) in scores.prefix(3).enumerated() {
                let sc = entry["score"] as? Int ?? 0
                let t  = entry["time"]  as? Double ?? 0
                let mins = Int(t)/60, secs = Int(t)%60
                let rankLbl = SKLabelNode(fontNamed: "AvenirNext-Regular")
                rankLbl.text = "\(rank+1). \(sc) pts — \(mins)m\(secs)s"
                rankLbl.fontSize = 12
                rankLbl.fontColor = .white
                rankLbl.position = CGPoint(x: 0, y: yOff)
                overlay.addChild(rankLbl)
                yOff -= 17
            }
            yOff -= 8
            if yOff < -150 { break }
        }

        if overlay.children.count <= 2 {
            let empty = SKLabelNode(text: "No scores yet — go run! 🏃")
            empty.fontName = "AvenirNext-Regular"
            empty.fontSize = 16
            empty.fontColor = UIColor.white.withAlphaComponent(0.7)
            empty.position = CGPoint(x: 0, y: 40)
            overlay.addChild(empty)
        }
    }

    private func showHelp() {
        let overlay = makeOverlay(title: "❓ HOW TO PLAY")
        let lines = [
            "👆 TAP — Jump over obstacles",
            "👇 HOLD — Sprint (drains energy fast!)",
            "⚡ Energy bar — depletes when running",
            "🚶 When empty — you walk to recover",
            "💧⚡🐻 Collect items to restore energy",
            "🏕 Reach all Aid Stations to finish!",
            "🚻 Bathroom — lose time, gain energy",
            "🗑 Trash can — barf, lose time, gain energy",
            "⭐ Points: speed + collectibles + aid stations",
        ]
        for (i, line) in lines.enumerated() {
            let lbl = SKLabelNode(fontNamed: "AvenirNext-Regular")
            lbl.text = line
            lbl.fontSize = 13
            lbl.fontColor = .white
            lbl.position = CGPoint(x: 0, y: 105 - CGFloat(i) * 26)
            overlay.addChild(lbl)
        }
    }

    private func makeOverlay(title: String) -> SKNode {
        childNode(withName: "overlay")?.removeFromParent()

        let overlay = SKNode()
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)
        overlay.zPosition = 300
        overlay.name = "overlay"

        let bg = SKShapeNode(rectOf: CGSize(width: size.width * 0.85, height: size.height * 0.75), cornerRadius: 20)
        bg.fillColor = UIColor(red:0.05,green:0.08,blue:0.18,alpha:0.97)
        bg.strokeColor = UIColor(red:0.3,green:0.6,blue:1,alpha:0.5)
        bg.lineWidth = 2
        overlay.addChild(bg)

        let titleLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLbl.text = title
        titleLbl.fontSize = 24
        titleLbl.fontColor = UIColor(red:1,green:0.85,blue:0.2,alpha:1)
        titleLbl.position = CGPoint(x: 0, y: size.height * 0.75/2 - 40)
        overlay.addChild(titleLbl)

        let closeBtn = SKShapeNode(rectOf: CGSize(width: 100, height: 36), cornerRadius: 10)
        closeBtn.fillColor = UIColor(red:0.7,green:0.1,blue:0.1,alpha:1)
        closeBtn.strokeColor = .clear
        closeBtn.position = CGPoint(x: 0, y: -(size.height * 0.75/2 - 30))
        closeBtn.name = "close_overlay"
        let closeLbl = SKLabelNode(text: "✕ Close")
        closeLbl.fontName = "AvenirNext-Bold"
        closeLbl.fontSize = 16
        closeLbl.fontColor = .white
        closeLbl.verticalAlignmentMode = .center
        closeLbl.isUserInteractionEnabled = false
        closeBtn.addChild(closeLbl)
        overlay.addChild(closeBtn)

        addChild(overlay)
        return overlay
    }
}
