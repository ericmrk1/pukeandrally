import UIKit
import SpriteKit

class GameViewController: UIViewController {
    override func loadView() {
        view = SKView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let skView = view as? SKView else { return }
        var size = skView.bounds.size
        if size.width == 0 || size.height == 0 {
            size = UIScreen.main.bounds.size
        }
        let scene = MainMenuScene(size: size)
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
}
