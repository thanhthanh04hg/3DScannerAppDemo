//
//  ViewController.swift
//  3DScannerAppDemo
//
//  Created by Macbook on 02/04/2021.
//


import UIKit
import Metal
import MetalKit
import ARKit
import RealityKit


// DAT TEN FILE PHAI DUA TREN TEN CUA MAN HINH
//MOI MAN HINH CHO RIENG RA 1 FOLDER GOM : - 1 VIEWCONTROLLER - 1 STORYBOARD
// TRONG IOS  VIEW VA CONTROLLER LA VIEWCONTROLLER
// FOLDER VIEWCONTROLLER CHUA 2 THANH PHAN NAY


class ScanViewController: UIViewController ,ARSessionDelegate{
    
    /*first variables*/
    @IBOutlet var EndBtn: UIButton!
    //KHONG DUOC VIET HOA CHU CAI DAU CUA VARIABLE VA FUNC
    // PHAI VIET THEO FORM VD : isDog , coachingOverlay,modelsForClassification
    //TEN BIEN VA TEN FUNC PHAI THE HIEN RO CHUC NANG CUA NO - DAI CUNG DUOC NHUNG OHAI DUNG CHUC NANG VA NHIM VU CUA NO TRONG CODE
    
    @IBOutlet var BTVBtn: UIButton! // sua thanh btnBTV
    @IBOutlet var arView: ARView!
    let shapeLayer = CAShapeLayer()
    let tapGesture = UITapGestureRecognizer()
    let config = ARWorldTrackingConfiguration()
    
    /*second variables*/
    let coachingOverlay = ARCoachingOverlayView()
    /*Cache for 3D text geometries representing the classification values.*/
    var modelsForClassification: [ARMeshClassification: ModelEntity] = [:]

    
    /*first code*/
    //MARK: override view
    override func viewDidLoad() {
        super.viewDidLoad()
        arView.session.delegate = self

        createProgressCircle()

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    //MARK: create circle progress // KO COMMENT THE NAY
    //MARK:- UI
    fileprivate func createProgressCircle(){
        let position = UIView(frame: CGRect(x: self.view.bounds.width/2, y: self.view.bounds.height*4/5, width: 20, height: 20)).center
        let circularPath = UIBezierPath(arcCenter: position, radius: 20, startAngle: 0, endAngle: 2*CGFloat.pi, clockwise: true)
        shapeLayer.path = circularPath.cgPath
        shapeLayer.fillColor = UIColor.red.cgColor
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = 3
        shapeLayer.lineCap = .round
        shapeLayer.strokeEnd = 0
        
        view.layer.addSublayer(shapeLayer)
        self.view.addGestureRecognizer(tapGesture)
        tapGesture.addTarget(self, action: #selector(handleTap))
        
    }
    
    @objc private func handleTap(){
        let basicAnimation = CABasicAnimation(keyPath: "strokeEnd")
        basicAnimation.toValue = 1
        basicAnimation.duration = 2
        basicAnimation.fillMode = .forwards
        basicAnimation.isRemovedOnCompletion = false
        shapeLayer.add(basicAnimation, forKey: "urSoBasic")
        
        
        //MARK: setting mesh
        
        setupCoachingOverlay()

        arView.environment.sceneUnderstanding.options = []

        // Turn on occlusion from the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.occlusion)

        // Turn on physics for the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.physics)

        // Display a debug visualization of the mesh.
        arView.debugOptions.insert(.showSceneUnderstanding)

        // For performance, disable render options that are not required for this app.
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]

        // Manually configure what kind of AR session to run since
        // ARView on its own does not turn on mesh classification.
        arView.automaticallyConfigureSession = false
        config.sceneReconstruction = .meshWithClassification
        config.environmentTexturing = .automatic
        arView.session.run(config)

        
    }
    
    
    
    //MARK: all funcs // LAM GI CO ALL FUNS
    //PHAI PHAN CHIA NHIEM VU CUA CAC FUNC THANH NHOM VA CO COMMENT MARK O FUNC BAT DAU NHOM NHIEM VU DO
    //COMMENT CO MARK PHAI DUA THEO CHUC NANG CHUNG CUA 1 NHOM FUNC
    //VD MARK:- UI ,MARK:- EVENT
    //FUNC NAO CHI DUNG NOI BO TRONG CLASS THI PHAI THEM FILEPRIVATE O DAU
    //CALL HAY PASSDATA GIUA 2 CLASS VOI NHAU PHAI THONG QUA PROTOCAL
    
    
    func nearbyFaceWithClassification(to location: SIMD3<Float>, completionBlock: @escaping (SIMD3<Float>?, ARMeshClassification) -> Void) {
        guard let frame = arView.session.currentFrame else {
            completionBlock(nil, .none)
            return
        }
    
        var meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
        
        // Sort the mesh anchors by distance to the given location and filter out
        // any anchors that are too far away (4 meters is a safe upper limit).
        let cutoffDistance: Float = 4.0
        meshAnchors.removeAll { distance($0.transform.position, location) > cutoffDistance }
        meshAnchors.sort { distance($0.transform.position, location) < distance($1.transform.position, location) }

        // Perform the search asynchronously in order not to stall rendering.
        DispatchQueue.global().async {
            for anchor in meshAnchors {
                for index in 0..<anchor.geometry.faces.count {
                    // Get the center of the face so that we can compare it to the given location.
                    let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)
                    
                    // Convert the face's center to world coordinates.
                    var centerLocalTransform = matrix_identity_float4x4
                    centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.0, geometricCenterOfFace.1, geometricCenterOfFace.2, 1)
                    let centerWorldPosition = (anchor.transform * centerLocalTransform).position
                     
                    // We're interested in a classification that is sufficiently close to the given location––within 5 cm.
                    let distanceToFace = distance(centerWorldPosition, location)
                    if distanceToFace <= 0.05 {
                        // Get the semantic classification of the face and finish the search.
                        let classification: ARMeshClassification = anchor.geometry.classificationOf(faceWithIndex: index)
                        completionBlock(centerWorldPosition, classification)
                        return
                    }
                }
            }
            
            // Let the completion block know that no result was found.
            completionBlock(nil, .none)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
//                self.resetButtonPressed(self)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
        
    func model(for classification: ARMeshClassification) -> ModelEntity {
        // Return cached model if available
        if let model = modelsForClassification[classification] {
            model.transform = .identity
            return model.clone(recursive: true)
        }
        
        // Generate 3D text for the classification
        let lineHeight: CGFloat = 0.05
        let font = MeshResource.Font.systemFont(ofSize: lineHeight)
        let textMesh = MeshResource.generateText(classification.description, extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMaterial = SimpleMaterial(color: classification.color, isMetallic: true)
        let model = ModelEntity(mesh: textMesh, materials: [textMaterial])
        // Move text geometry to the left so that its local origin is in the center
        model.position.x -= model.visualBounds(relativeTo: nil).extents.x / 2
        // Add model to cache
        modelsForClassification[classification] = model
        return model
    }
    
    func sphere(radius: Float, color: UIColor) -> ModelEntity {
        let sphere = ModelEntity(mesh: .generateSphere(radius: radius), materials: [SimpleMaterial(color: color, isMetallic: false)])
        // Move sphere up by half its diameter so that it does not intersect with the mesh
        sphere.position.y = radius
        return sphere
    }

}


//DUNG EXTENSION KO NEN CHO RA KHOI FILE CHUA NO
extension ScanViewController: ARCoachingOverlayViewDelegate {
    
//    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
//        hideMeshButton.isHidden = true
//        resetButton.isHidden = true
//        planeDetectionButton.isHidden = true
//    }
//
//    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
//        hideMeshButton.isHidden = false
//        resetButton.isHidden = false
//        planeDetectionButton.isHidden = false
//    }
//
//    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
//        resetButtonPressed(self)
//    }

    func setupCoachingOverlay() {
        // Set up coaching view
//        coachingOverlay.session = arView.session
        coachingOverlay.delegate = self
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlay)
        
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor)
            ])
    }
}


