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
import MLXR

@objc
public class XrClientSession: NSObject {

    @objc public static let instance = XrClientSession()
    static fileprivate let locationManager = CLLocationManager()
    fileprivate weak var arSession: ARSession?
    fileprivate let mlxrSession = MLXRSession()
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

    private func findArSession(view: UIView) -> ARSession? {
        if let arSceneView = view as? ARSCNView {
            return arSceneView.session
        }
        for subview in view.subviews {
            if let arSession = findArSession(view: subview) {
                return arSession
            }
        }
        return nil
    }

    private func findArSession() -> ARSession? {
        var arSession: ARSession? = nil
        DispatchQueue.main.sync {
            let viewController = UIApplication.shared.keyWindow!.rootViewController
            if let view = viewController?.view {
                arSession = findArSession(view: view)
            }
        }
        return arSession
    }

    private func waitForArSession() -> ARSession? {
        for _ in 1...30 {
            guard let arSession = findArSession() else {
                // Sleep for 200ms
                usleep(200 * 1000)
                continue;
            }
            return arSession
        }
        return nil
    }

    @objc
    public func connect(_ token: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async { [weak self] in
            guard let self = self else {
                reject("code", "XrClientSession does not exist", nil)
                return
            }

            guard let arSession = self.waitForArSession() else {
                reject("code", "ARSession does not exist", nil)
                return
            }

            self.arSession = arSession

            if (self.mlxrSession.start(token)) {
                if (arSession.delegate == nil) {
                    let worldOriginAnchor = ARAnchor(name: "WorldAnchor", transform: matrix_identity_float4x4)
                    arSession.add(anchor: worldOriginAnchor)
                    arSession.delegate = self;
                }

                let status: XrClientSessionStatus = XrClientSessionStatus(sessionStatus: self.mlxrSession.getStatus()?.status ?? MLXRSessionStatus_Disconnected)
                resolve(status.rawValue)
            } else {
                reject("code", "XrClientSession could not be initialized!", nil)
            }
        }
    }

    fileprivate func update() {
        guard let currentLocation = lastLocation else {
            print("current location is not available")
            return
        }

        guard let frame = self.arSession?.currentFrame else {
            print("no ar frame available")
            return
        }

        if let previuosTrackingState = trackingState,
            let currentTrackingState = self.arSession?.currentFrame?.camera.trackingState,
            previuosTrackingState != currentTrackingState {
            print("TrackingState: ", currentTrackingState.description);
        }

        trackingState = self.arSession?.currentFrame?.camera.trackingState

        _ = mlxrSession.update(frame, currentLocation)
    }

    @objc
    public func getAllPCFs(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async { [weak self] in
            guard let xrSession = self?.mlxrSession else {
                reject("code", "XrClientSession has not been initialized!", nil)
                return
            }
            let results: [[String: Any]] = xrSession.getAllAnchors().map { XrClientAnchorData($0) }.map { $0.getJsonRepresentation() }
            resolve(results)
        }
    }

    @objc
    public func getSessionStatus(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async { [weak self] in
            guard let self = self else {
                reject("code", "XrClientSession does not exist", nil)
                return
            }

            let status: XrClientSessionStatus = XrClientSessionStatus(sessionStatus: self.mlxrSession.getStatus()?.status ?? MLXRSessionStatus_Disconnected)
            resolve(status.rawValue)
        }
    }

    @objc
    public func getLocalizationStatus(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async { [weak self] in
            guard let self = self else {
                reject("code", "XrClientSession does not exist", nil)
                return
            }

            let status: XrClientLocalization = XrClientLocalization(localizationStatus: self.mlxrSession.getLocalizationStatus()?.status ?? MLXRLocalizationStatus_LocalizationFailed)
            resolve(status.rawValue)
        }
    }

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }

    @objc
    public func createAnchor(_ anchorId: String, position: NSArray, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async {
            guard let arSession = self.arSession else {
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
            if let anchors = self.arSession?.currentFrame?.anchors {
                for anchor in anchors {
                    if let name = anchor.name, name == anchorId {
                        self.arSession?.remove(anchor: anchor)
                    }
                }
            }
            resolve("success")
        }
    }

    @objc
    public func removeAllAnchors(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        xrQueue.async {
            if let anchors = self.arSession?.currentFrame?.anchors {
                for anchor in anchors {
                    self.arSession?.remove(anchor: anchor)
                }
            }
            resolve("success")
        }
    }
}

// CLLocationManagerDelegate
extension XrClientSession: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        xrQueue.async { [weak self] in
            if let self = self {
                self.lastLocation = locations.last
            }
        }
    }
}

extension XrClientSession: ARSessionDelegate {
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
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
