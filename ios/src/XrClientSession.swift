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

@objc(XrClientSession)
class XrClientSession: NSObject {

    static public weak var arSession: ARSession?
    static fileprivate let locationManager = CLLocationManager()
    fileprivate var xrClientSession: MLXRSession?
    fileprivate let xrQueue = DispatchQueue(label: "xrQueue")
    fileprivate var lastLocation: CLLocation?
    fileprivate var trackingState: ARCamera.TrackingState?
    
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
    static public func registerARSession(_ arSession: ARSession) {
        XrClientSession.arSession = arSession
    }

    @objc
    public func connect(_ address: String, deviceId: String, token: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async { [weak self] in
            guard let self = self else {
                reject("code", "ARSession does not exist.", nil)
                return
            }
            
            guard let arSession = XrClientSession.arSession else {
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
        
        guard let frame = XrClientSession.arSession?.currentFrame else {
            print("no ar frame available")
            return
        }

        if let previuosTrackingState = trackingState,
            let currentTrackingState = XrClientSession.arSession?.currentFrame?.camera.trackingState,
            previuosTrackingState != currentTrackingState {
            print("TrackingState: ", currentTrackingState.description);
        }
        
        trackingState = XrClientSession.arSession?.currentFrame?.camera.trackingState

        _ = xrSession.update(frame, currentLocation)
    }

    @objc
    public func getAllAnchors(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async { [weak self] in
            guard let xrSession = self?.xrClientSession else {
                reject("code", "XrClientSession has not been initialized!", nil)
                return
            }
            let allAnchors: [MLXRAnchor] = xrSession.getAllAnchors()
            let uniqueAnchors: [XrClientAnchorData] = allAnchors.map { XrClientAnchorData($0) }
            
            // Remove current local anchors
            if let currentAnchors = XrClientSession.arSession?.currentFrame?.anchors {
                for anchor in currentAnchors {
                    XrClientSession.arSession?.remove(anchor: anchor)
                }
            }
            
            let bvs = xrSession.getAllBoundedVolumes()
            print("getAllBoundedVolumes:" + String(bvs.count))

            for bv in bvs {
                if let pcfID = bv.getId(), let sdkAncror = xrSession.getAnchorByPcfId(pcfID), let bvMatrix = bv.getPose() {
                    let xrAnchor = XrClientAnchorData(sdkAncror);
                    let pose: simd_float4x4 = xrAnchor.getPose() * bvMatrix.pose;
                    XrClientSession.arSession?.add(anchor: ARAnchor(name: xrAnchor.getAnchorId(), transform: pose))
                }
            }
            
            let results: [[String: Any]] = uniqueAnchors.map { $0.getJsonRepresentation() }
            resolve(results)
        }
    }
    
    @objc
    public func getAnchorByPcfId(pcfId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async { [weak self] in
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
        xrQueue.async { [weak self] in
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
        xrQueue.async { [weak self] in
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
}

// CLLocationManagerDelegate
extension XrClientSession: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        xrQueue.async { [weak self] in
            if let self = self {
                self.lastLocation = locations.last
            }
        }
    }
}

extension XrClientSession: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        self.update();
    }
}

extension ARCamera.TrackingState {
    var description: String {
        switch self {
        case .notAvailable:
            return "UNAVAILABLE"
        case .normal:
            return "NORMAL"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return "LIMITED: Too much camera movement"
            case .insufficientFeatures:
                return "LIMITED: Not enough surface detail"
            case .initializing:
                return "LIMITED: Initializing"
            case .relocalizing:
                return "LIMITED: Relocalizing"
            @unknown default:
                return "LIMITED: Unknown reason"
            }
        }
    }

    static func == (left: ARCamera.TrackingState, right: ARCamera.TrackingState) -> Bool {
        switch (left, right) {
        case (.notAvailable, .notAvailable):
            return true
        case (.normal, .normal):
            return true
        case let (.limited(a), .limited(b)):
            return a == b
        default:
            return false
        }
    }
    
    static func != (left: ARCamera.TrackingState, right: ARCamera.TrackingState) -> Bool {
        return !(left == right)
    }
}
