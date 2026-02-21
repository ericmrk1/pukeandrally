import UIKit
import SpriteKit

class GameViewController: UIViewController {
    private var hasPresentedScene = false

    override func loadView() {
        view = SKView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let skView = view as? SKView else { return }
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let skView = view as? SKView, !hasPresentedScene else { return }
        let size = skView.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        hasPresentedScene = true
        let scene = MainMenuScene(size: size)
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
}
