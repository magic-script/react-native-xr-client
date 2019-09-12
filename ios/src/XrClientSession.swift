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
    public func connect(_ gatewayAddress: String,
                        pwAddress: String,
                        deviceId: String,
                        appId: String,
                        token: String,
                        resolve: @escaping RCTPromiseResolveBlock,
                        reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async { [weak self] in
            guard let self = self else {
                reject("code", "XrClientSession does not exist", nil)
                return
            }
            
            guard let arSession = XrClientSession.arSession else {
                reject("code", "ARSession does not exist", nil)
                return
            }
            
            self.xrClientSession = MLXRSession(token, arSession)
            if let xrSession = self.xrClientSession {
                let result: Bool = xrSession.connect(gatewayAddress, pwAddress, deviceId, appId, token)
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
        print("TrackingState:", XrClientSession.arSession?.currentFrame?.camera.trackingState ?? "Unknown");
        _ = xrSession.update(frame, currentLocation)
    }
    
    @objc
    public func getAllPCFs(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async { [weak self] in
            guard let xrSession = self?.xrClientSession else {
                reject("code", "XrClientSession has not been initialized!", nil)
                return
            }
            let results: [[String: Any]] = xrSession.getAllAnchors().map { XrClientAnchorData($0) }.map { $0.getJsonRepresentation() }
            resolve(results)
        }
    }
    
    @objc
    public func getPCFById(_ pcfId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async { [weak self] in
            guard let self = self else {
                reject("code", "XrClientSession does not exist", nil)
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
            
            guard let anchorData = xrSession.getAnchorBy(uuid) else {
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
                reject("code", "XrClientSession does not exist", nil)
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
                reject("code", "XrClientSession does not exist", nil)
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
    
    @objc
    public func createAnchor(_ anchorId: String, position: NSArray, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async {
            guard let arSession = XrClientSession.arSession else {
                reject("code", "ARSession has not been initialized!", nil)
                return
            }
            var transform: simd_float4x4?
            if let position = position as? [NSNumber] {
                transform = XrClientAnchorData.mat4FromColumnMajorFlatArray(position.map{$0.floatValue})
            } else if let position = position as? [Float] {
                transform = XrClientAnchorData.mat4FromColumnMajorFlatArray(position)
            }
            if let transform = transform {
                arSession.add(anchor: ARAnchor(name: anchorId, transform: transform))
                resolve("success")
            } else {
                reject("code", "position should be a array of 16 float elements", nil)
            }
        }
    }
    
    @objc
    public func removeAnchor(_ anchorId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async {
            if let anchors = XrClientSession.arSession?.currentFrame?.anchors {
                for anchor in anchors {
                    if let name = anchor.name, name == anchorId {
                        XrClientSession.arSession?.remove(anchor: anchor)
                    }
                }
            }
        }
        resolve("success")
    }
    
    @objc
    public func removeAllAnchors(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async {
            if let anchors = XrClientSession.arSession?.currentFrame?.anchors {
                for anchor in anchors {
                    XrClientSession.arSession?.remove(anchor: anchor)
                }
            }
            resolve("success")
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
