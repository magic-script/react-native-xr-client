//
//  MLXrClientAnchorData.swift
//  RNMagicScript
//
//  Created by Pawel Leszkiewicz on 17/07/2019.
//  Copyright © 2019 MagicLeap. All rights reserved.
//

import Foundation
import SceneKit
import MLXRInternal

class XrClientAnchorData: NSObject {
    fileprivate let anchorData: MLXRAnchor!

    public init(_ anchorData: MLXRAnchor) {
        self.anchorData = anchorData
    }

    public func getState() -> String {
        if let state = anchorData.getState(), state.tracked {
            return "tracked"
        } else {
            return "notTracked"
        }
    }

    public func getConfidence() -> [String: Any] {
        guard let confidence = anchorData.getConfidence() else {
            return [:]
        }
        return [
            "confidence": confidence.confidence,
            "validRadiusM": confidence.validRadiusM,
            "rotationErrDeg": confidence.rotationErrDeg,
            "translationErrM": confidence.translationErrM
        ]
    }

    public func getFlatPose() -> [Float] {
        let pose = getPose()
        return [
            pose[0][0], pose[1][0], pose[2][0], pose[3][0],
            pose[0][1], pose[1][1], pose[2][1], pose[3][1],
            pose[0][2], pose[1][2], pose[2][2], pose[3][2],
            pose[0][3], pose[1][3], pose[2][3], pose[3][3]
        ]
    }

    public func getPose() -> simd_float4x4 {
        return anchorData.getPose()?.pose ?? matrix_identity_float4x4
    }

    public func getAnchorId() -> String {
        return anchorData.getId()?.uuidString ?? "DEFAULT"
    }

    @objc public func getJsonRepresentation() -> [String: Any] {
        return [
            "state": getState(),
            "confidence": getConfidence(),
            "pose": getFlatPose(),
            "anchorId": getAnchorId()
        ]
    }
    
    public static func mat4FromFlatArray(_ flat: [Float]) -> simd_float4x4? {
        if (flat.count != 16) {
            return nil
        }
        return simd_float4x4(simd_float4(flat[0..<4]), simd_float4(flat[4..<8]), simd_float4(flat[8..<12]), simd_float4(flat[12..<16]))
    }
}
