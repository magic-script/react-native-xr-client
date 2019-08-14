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
import mlxr_ios_client_internal

@objc(XrClientSession)
class XrClientSession: NSObject {

    static fileprivate weak var arSession: ARSession?
    static fileprivate let locationManager = CLLocationManager()
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
    public func registerARSession(arSession: ARSession, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        print(arSession);
        XrClientSession.arSession = arSession
        resolve(true);
    }
    
    @objc
    public func connect(_ address: String, deviceId: String, token: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
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
        print("TrackingState: %s", XrClientSession.arSession?.currentFrame?.camera.trackingState ?? "UNKNOWND_MXS");
        _ = xrSession.update(frame, currentLocation)
    }
    
    @objc
    public func getAllAnchors(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
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
            var pcfToPPMap: [String: String] = [
                "9A90E918-A696-7018-A7C7-0242C0A8FE0D": "1870D08E-BADA-FCD1-C140-25569291A885", // Mira
                "9A90D1EE-A696-7018-B29F-0242C0A8FE0D": "1870BD54-5445-E5C7-5EF2-D474D84755B3", // Hyperion
                "9A90DD4C-A696-7018-9254-0242C0A8FE0D": "18708D47-B1C8-97A4-765A-1DFE0C2DB896", // Titon
                "9A90BA7E-A696-7018-BE4E-0242C0A8FE0D": "187006F3-74D0-04D0-7C76-833B59D91CB3", // Calypso
                "FE355392-A76C-7018-A067-0242C0A8FE0B": "1870199D-CF24-49D9-6B8E-28A7EA37B88D", // Io
                "FE3530BA-A76C-7018-AF50-0242C0A8FE0B": "187000B1-3211-FA4E-9350-ADA5CBCCE3A3", // Atlas
                "940A834A-A69D-7018-84BD-0242C0A8FE0D": "1870BEA4-AD6F-7833-72CC-8D0FE6C84196", // Antares
                //                "940A834A-A69D-7018-84BD-0242C0A8FE0D": "1870BEA4-AD6F-7833-72CC-8D0FE6C84196", // Electra
                "C4763982-A79E-7018-8D51-0242C0A8FE0B": "18701E96-609C-BA2E-0D9D-272EE0985C9F"  // Triton
            ];
            
            for bv in bvs {
                if let ppid = pcfToPPMap[bv.getId()!.uuidString], let pcfID: UUID = UUID.init(uuidString: ppid), let sdkAncror = xrSession.getAnchorByPcfId(pcfID), let bvMatrix = bv.getPose() {
                    let xrAnchor = XrClientAnchorData(sdkAncror);
                    let pose: simd_float4x4 = xrAnchor.getMagicPose() * bvMatrix.pose;
                    let testAnchor = ARAnchor(name: xrAnchor.getAnchorId(), transform: pose)
                    XrClientSession.arSession?.add(anchor: testAnchor)
                }
            }
            
            let results: [[String: Any]] = uniqueAnchors.map { $0.getJsonRepresentation() }
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
}
