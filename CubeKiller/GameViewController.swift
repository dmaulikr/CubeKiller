//
//  GameViewController.swift
//  CubeKiller
//
//  Created by ltebean on 7/27/17.
//  Copyright © 2017 ltebean. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit

class GameViewController: UIViewController {
    
    enum ColliderCategory: Int {
        case gamer  = 0b0001
        case bullet = 0b0010
        case target = 0b0100
        case floor = 0b1000

    }

    @IBOutlet weak var scnView: SCNView!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var pauseButton: UIButton!
    
    var score = 0 {
        didSet {
            DispatchQueue.main.async {
                self.scoreLabel.text = "SCORE: \(self.score)"
            }
        }
    }
    
    var spawnTime: TimeInterval = 0
    var gamerNode: SCNNode!
    var targetNode: SCNNode!
    var floorNode: SCNNode!

    var cameraNode: SCNNode!
    var boxNode: SCNNode!
    
    var scene: SCNScene!
    
    var needsShootBullet = false
    var fieldNode: SCNNode!
    
    var isPlaying = true

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create a new scene
        scene = SCNScene(named: "art.scnassets/Game.scn")!
        scnView.scene = scene
        scnView.antialiasingMode = .multisampling4X
        scnView.delegate = self

        scene.physicsWorld.contactDelegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        gamerNode = scene.rootNode.childNode(withName: "gamer", recursively: true)
        fieldNode = scene.rootNode.childNode(withName: "field", recursively: true)
        floorNode = scene.rootNode.childNode(withName: "floor", recursively: true)

        targetNode = scene.rootNode.childNode(withName: "targetBox", recursively: true)
        targetNode.isHidden = true
        cameraNode = scene.rootNode.childNode(withName: "camera", recursively: true)
        boxNode = scene.rootNode.childNode(withName: "gamerBox", recursively: true)
        boxNode.physicsBody?.categoryBitMask = ColliderCategory.gamer.rawValue
        boxNode.physicsBody?.collisionBitMask = ColliderCategory.target.rawValue

        floorNode.physicsBody?.categoryBitMask = ColliderCategory.floor.rawValue
        floorNode.physicsBody?.collisionBitMask = ColliderCategory.target.rawValue | ColliderCategory.gamer.rawValue


        score = 0
        
        fieldNode.isHidden = true

        (1...10).forEach({ _ in
            self.spawnTarget()
        })
        recalutateMove()
        
        GameHelper.shared.loadSound(name: "explode", fileNamed: "art.scnassets/Sound/Paddle.wav")
        GameHelper.shared.loadSound(name: "jump", fileNamed: "art.scnassets/Sound/Jump.wav")
        GameHelper.shared.loadSound(name: "shoot", fileNamed: "art.scnassets/Sound/Barrier.wav")
        GameHelper.shared.loadSound(name: "supercharge", fileNamed: "art.scnassets/Sound/Powerup.wav")

    }
    
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        guard gestureRecognize.state == .ended else { return }
        jumpForward(distance: 8)
    }
    
    func jumpForward(distance: Float) {
        let duration = 0.3
        let bounceUpAction = SCNAction.moveBy(x: 0, y: 0.5, z: 0, duration:
            duration * 0.5)
        let bounceDownAction = SCNAction.moveBy(x: 0, y: -0.5, z: 0, duration:
            duration * 0.5)
        
        let targetPosition = gamerNode.convertPosition(targetNode.position, to: scnView.scene!.rootNode)
        let currentPosition = gamerNode.position
        
        let by = targetPosition - currentPosition
        
        let forwardAction = SCNAction.move(by: by * distance, duration: duration)
        gamerNode.runAction(forwardAction)
        boxNode.runAction(SCNAction.sequence([bounceUpAction, bounceDownAction]))
        GameHelper.shared.playSound(node: gamerNode, name: "jump")

    }
    
    func spawnTarget() {
        let position = gamerNode.position
        let target = SCNNode(geometry: SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0))
        target.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        
        let randomX = Float(Int.random(min: -16, max: 16))
        let randomZ = Float(Int.random(min: -16, max: 16))
        let randomY = Float.random(min: 0, max: 2)

        target.position = position + SCNVector3(x: randomX, y: randomY, z: randomZ)
        target.physicsBody?.isAffectedByGravity = true
        target.name = "target"
        target.physicsBody?.categoryBitMask = ColliderCategory.target.rawValue
        target.physicsBody?.contactTestBitMask = ColliderCategory.gamer.rawValue | ColliderCategory.bullet.rawValue | ColliderCategory.target.rawValue
        target.physicsBody?.collisionBitMask = ColliderCategory.gamer.rawValue | ColliderCategory.bullet.rawValue | ColliderCategory.target.rawValue | ColliderCategory.floor.rawValue
        scene.rootNode.addChildNode(target)
        
        target.geometry?.materials[0].diffuse.contents = UIColor.random()
        target.opacity = 0
        target.eulerAngles.y = Float.random(min: 0, max: 3.14)
        let action = SCNAction.fadeIn(duration: 1)
        target.runAction(action)
    }
    
    @IBAction func blackHoleButtonPressed(_ sender: Any) {
        guard fieldNode.isHidden else { return }
        fieldNode.isHidden = false
        
        let targetPosition = gamerNode.convertPosition(targetNode.position, to: scnView.scene!.rootNode)
        let currentPosition = gamerNode.position
        let by = targetPosition - currentPosition
        
        fieldNode.position = currentPosition + by * 6 + SCNVector3(x: 0, y: 3, z: 0)
        let action = SCNAction.move(by: by * 50, duration: 5)
        fieldNode.runAction(action, completionHandler: {
            self.fieldNode.isHidden = true
        })
        GameHelper.shared.playSound(node: gamerNode, name: "supercharge", rate: 0.1)

    }
    
    @IBAction func pauseButtonPressed(_ sender: Any) {
        scene.isPaused = !scene.isPaused
        pauseButton.setTitle(scene.isPaused ? "RESUME" : "PAUSE", for: .normal)
        pauseButton.setImage(UIImage(named: scene.isPaused ? "icon-play" : "icon-pause"), for: .normal)
    }
    
    @IBAction func shootButtonPressed(_ sender: Any) {
        needsShootBullet = true
    }
    
    func shoot() {
        let targetPosition = gamerNode.convertPosition(targetNode.position, to: scnView.scene!.rootNode)
        let currentPosition = gamerNode.position
        let by = targetPosition - currentPosition
        let bullet = SCNNode(geometry: SCNSphere(radius: 0.1))
        bullet.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        bullet.position = currentPosition
        bullet.physicsBody?.categoryBitMask = ColliderCategory.bullet.rawValue
        bullet.physicsBody?.collisionBitMask = ColliderCategory.target.rawValue
        bullet.physicsBody?.velocity = by * 8
        bullet.physicsBody?.isAffectedByGravity = false
        bullet.name = "bullet"
        scene.rootNode.addChildNode(bullet)
        
        bullet.wait(forDuation: 2, thenRun: { node in
            node.physicsBody?.type = .static
            node.removeAllAnimations()
            node.removeFromParentNode()
        })
        GameHelper.shared.playSound(node: boxNode, name: "shoot")
    }
    
    func recalutateMove() {
        let targetPosition = gamerNode.convertPosition(targetNode.position, to: scnView.scene!.rootNode)
        let currentPosition = gamerNode.position
        let by = targetPosition - currentPosition
        let action = SCNAction.move(by: by, duration: 0.4)
        gamerNode.removeAction(forKey: "move")
        gamerNode.runAction(SCNAction.repeatForever(action), forKey: "move")
    }
    
    func handlePan(_ gesture: UIPanGestureRecognizer) {
        let tx = gesture.translation(in: gesture.view).x
        var angles = gamerNode.eulerAngles
        angles.y -= Float(CGFloat(M_PI) / 360 * tx)
        gamerNode.eulerAngles = angles
        gesture.setTranslation(CGPoint.zero, in: gesture.view)
        recalutateMove()
    }
    
    
    func explode(node: SCNNode) {
        GameHelper.shared.playSound(node: boxNode, name: "explode")

        let geometry = node.geometry!
        let position = node.presentation.position
        let rotation = node.presentation.rotation
        let explosion = SCNParticleSystem(named: "art.scnassets/Explode.scnp", inDirectory: nil)!
        explosion.particleColor = geometry.materials[0].diffuse.contents as! UIColor
        explosion.emitterShape = geometry
        explosion.birthLocation = .surface
        let rotationMatrix = SCNMatrix4MakeRotation(rotation.w, rotation.x, rotation.y, rotation.z)
        let translationMatrix = SCNMatrix4MakeTranslation(position.x, position.y, position.z)
        let transformMatrix = SCNMatrix4Mult(rotationMatrix, translationMatrix)
        scene.addParticleSystem(explosion, transform: transformMatrix)
        node.removeFromParentNode()
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    
}

extension GameViewController: SCNSceneRendererDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time:
        TimeInterval) {
        guard isPlaying else { return }
        if time > spawnTime {
            spawnTarget()
            spawnTime = time + 0.5
        }
        if needsShootBullet {
            shoot()
            needsShootBullet = false
        }
    }
    
}


extension GameViewController: SCNPhysicsContactDelegate {

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        var target: SCNNode!
        var node: SCNNode!
        if contact.nodeA.name == "target" {
            target = contact.nodeA
            node = contact.nodeB
        } else {
            target = contact.nodeB
            node = contact.nodeA
        }
        if node.name == "ground" {
            return
        }
        if node.name == "bullet" {
            target.wait(forDuation: 0.5, thenRun: { node in
                self.explode(node: node)
                self.score += 10
            })
        } else if node.name == "gamerBox" {
            target.wait(forDuation: 0.5, thenRun: { node in
                self.explode(node: node)
                self.score += 20
            })
        } else {
            node.wait(forDuation: 0.5, thenRun: { node in
                self.explode(node: node)
                self.score += 30
            })
            target.wait(forDuation: 0.5, thenRun: { node in
                self.explode(node: node)
                self.score += 30
            })
        }

    }
}
