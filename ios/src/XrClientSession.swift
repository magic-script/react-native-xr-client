//
//  MLXrClientSession.swift
//  RNMagicScript
//
//  Created by Pawel Leszkiewicz on 17/07/2019.
//  Copyright © 2019 MagicLeap. All rights reserved.
//

import Foundation
import ARKit
import CoreLocation
import MLXRInternal

extension ARCamera.TrackingState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .normal: return "Normal"
        case .limited(let reason):
            switch reason {
            case .initializing: return "Limited(initializing)"
            case .excessiveMotion: return "Limited(excessiveMotion)"
            case .insufficientFeatures: return "Limited(insufficientFeatures)"
            case .relocalizing: return "Limited(relocalizing)"
            default: return "Limited(unknown)"
            }
        case .notAvailable: return "NA"
        }
    }
}

@objc(XrClientSession)
class XrClientSession: NSObject {

    static public weak var arView: ARSCNView?
    static fileprivate let locationManager = CLLocationManager()
    static fileprivate var statusLabel: UILabel?
    
    fileprivate var xrClientSession: MLXRSession?
    fileprivate var internalLocation: CLLocation!
    fileprivate let internalLocationQueue: DispatchQueue = DispatchQueue(label: "internalLocationQueue")
    fileprivate var lastLocation: CLLocation? {
        get {
            return internalLocationQueue.sync { internalLocation }
        }
        set (newLocation) {
            internalLocationQueue.sync { internalLocation = newLocation }
        }
    }
    
    fileprivate var arSessionInterrupted = false
    fileprivate var arSessionRelocationTimer: Timer?

    
    public override init() {
        super.init()
        setupLocationManager()
    }
    
    deinit {
        // NOTE: Due to the following warning:
        // "Failure to deallocate CLLocationManager on the same runloop as its creation
        // may result in a crash"
        // locationManager is a static member and we only stop updating location in deinit.
        XrClientSession.locationManager.stopUpdatingLocation()
        XrClientSession.locationManager.delegate = nil
    }
    
    fileprivate func setupLocationManager() {
        XrClientSession.locationManager.delegate = self
        XrClientSession.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        XrClientSession.locationManager.requestWhenInUseAuthorization()
        XrClientSession.locationManager.startUpdatingLocation()
    }

    @objc
    static public func registerARSCNView(_ arView: ARSCNView) {
        DispatchQueue.main.async {
            XrClientSession.arView = arView

            statusLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 24))
            statusLabel!.textAlignment = .left
            statusLabel!.font = UIFont.systemFont(ofSize: 14)
            statusLabel!.translatesAutoresizingMaskIntoConstraints = false
            arView.addSubview(statusLabel!)
            statusLabel!.topAnchor.constraint(equalTo: arView.topAnchor, constant: 5).isActive = true
            statusLabel!.leftAnchor.constraint(equalTo: arView.leftAnchor, constant: 15).isActive = true
        }
    }

    @objc
    public func connect(_ address: String, deviceId: String, token: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                reject("code", "ARSession does not exist.", nil)
                return
            }
            
            guard let arSession = XrClientSession.arView?.session else {
                reject("code", "ARSession does not exist.", nil)
                return
            }
            
            self.xrClientSession = MLXRSession(0, arSession)
            if let xrSession = self.xrClientSession {
                let result: Bool = xrSession.connect(address, deviceId, token)
                if (arSession.delegate == nil) {
                    let worldOriginAnchor = ARAnchor(name: "WorldAnchor", transform: matrix_identity_float4x4)
                    arSession.add(anchor: worldOriginAnchor)
                    arSession.delegate = self;
                }
                resolve(result)
            } else {
                reject("code", "XrClientSession has not been initialized!", nil)
            }
        }
    }
    
    @objc
    public func setUpdateInterval(_ interval: TimeInterval, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        resolve(true)
    }
    
    fileprivate func update() {
        guard let xrSession = xrClientSession else {
            print("no mlxr session avaiable")
            return
        }
        
        guard let currentLocation = lastLocation else {
            print("current location is not available")
            return
        }
        
        guard let frame = XrClientSession.arView?.session.currentFrame else {
            print("no ar frame available")
            return
        }
        //print("[XrClientSession] TrackingState:", XrClientSession.arView?.session.currentFrame?.camera.trackingState ?? "Unknown");
        let _ = xrSession.update(frame, currentLocation)
    }
    
    @objc
    public func getAllAnchors(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let xrSession = self.xrClientSession else {
                reject("code", "XrClientSession has not been initialized!", nil)
                return
            }
            let allAnchors: [MLXRAnchor] = xrSession.getAllAnchors()
            let uniqueAnchors: [XrClientAnchorData] = allAnchors.map { XrClientAnchorData($0) }
            
            // Remove current local anchors
            if let currentAnchors = XrClientSession.arView?.session.currentFrame?.anchors {
                for anchor in currentAnchors {
                    XrClientSession.arView?.session.remove(anchor: anchor)
                }
            }
            
            let bvs = xrSession.getAllBoundedVolumes()
            print("[XrClientSession] getAllBoundedVolumes:" + String(bvs.count))

            for bv in bvs {
                if let pcfID = bv.getId(), let sdkAncror = xrSession.getAnchorByPcfId(pcfID), let bvMatrix = bv.getPose() {
                    let xrAnchor = XrClientAnchorData(sdkAncror);
                    let pose: simd_float4x4 = xrAnchor.getPose() * bvMatrix.pose;
                    XrClientSession.arView?.session.add(anchor: ARAnchor(name: xrAnchor.getAnchorId(), transform: pose))
                }
            }
            
            let results: [[String: Any]] = uniqueAnchors.map { $0.getJsonRepresentation() }
            self.updateStatusUI()
            resolve(results)
        }
    }
    
    @objc
    public func getAnchorByPcfId(pcfId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                reject("code", "Bad state", nil)
                return
            }
            guard let uuid = UUID(uuidString: pcfId) else {
                reject("code", "Incorrect PCF id", nil)
                return
            }
            
            guard let xrSession = self.xrClientSession else {
                reject("code", "XrClientSession has not been initialized!", nil)
                return
            }
            
            guard let anchorData = xrSession.getAnchorByPcfId(uuid) else {
                // Achor data does not exist for given PCF id
                resolve(nil)
                return
            }
            
            let result: [String : Any] = XrClientAnchorData(anchorData).getJsonRepresentation()
            resolve(result)
        }
    }
    
    @objc
    public func getLocalizationStatus(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                reject("code", "Bad state", nil)
                return
            }
            guard let xrSession = self.xrClientSession else {
                reject("code", "XrClientSession has not been initialized!", nil)
                return
            }
            
            let status: XrClientLocalization = XrClientLocalization(localizationStatus: xrSession.getLocalizationStatus()?.status ?? MLXRLocalizationStatus_LocalizationFailed)
            resolve(status.rawValue)
        }
    }
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc
    public func getAllBoundedVolumes(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                reject("code", "Bad state", nil)
                return
            }
            guard let xrSession = self.xrClientSession else {
                reject("code", "XrClientSession has not been initialized!", nil)
                return
            }
            let volumes = xrSession.getAllBoundedVolumes()
            let uniqueVolumes: [[String:Any]] = volumes.map { XrClientBoundedVolume($0).getJsonRepresentation() }
            resolve(uniqueVolumes)
        }
        
    }
    
    private func updateStatusUI() {
        var stringState: String
        if let trackingState = XrClientSession.arView?.session.currentFrame?.camera.trackingState {
            stringState = "AR: " + trackingState.description
        } else {
            stringState = "AR: unknown"
        }
        if arSessionInterrupted {
            stringState += " - Interrupted"
        }
        if let xrLocalizationStatus = self.xrClientSession?.getLocalizationStatus()?.status {
            stringState += ", XR: " + XrClientLocalization(localizationStatus: xrLocalizationStatus).rawValue
        } else {
            stringState += ", XR: unknown"
        }
        XrClientSession.statusLabel?.text = stringState
    }
}

// CLLocationManagerDelegate
extension XrClientSession: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
}

extension XrClientSession: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        self.update();
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("[XrClientSession] ARSession was interrupted")
        arSessionInterrupted = true
        startRelocalizationTimer()
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("[XrClientSession] ARSession interruption ended")
        arSessionInterrupted = false
        stopRelocalizationTimer()
    }
    
    private func startRelocalizationTimer() {
        stopRelocalizationTimer()
        arSessionRelocationTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false, block: {[weak self] _ in
            if let session = XrClientSession.arView?.session, let self = self, self.arSessionInterrupted, let config = session.configuration {
                print("[XrClientSession] giving up ARSession relocalization")
                session.run(config, options: .resetTracking)
            }
        })
        print("[XrClientSession] started ARSession relocalization timer")
    }
    
    private func stopRelocalizationTimer() {
        if let timer = arSessionRelocationTimer {
            timer.invalidate()
            arSessionRelocationTimer = nil
            print("[XrClientSession] stopped ARSession relocalization timer")
        }
    }
}
