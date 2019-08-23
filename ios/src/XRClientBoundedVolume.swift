//
//  XRClientBoundedVolume.swift
//  RNMagicScript
//
//  Created by Konrad Piascik on 7/28/19.
//  Copyright © 2019 MagicLeap. All rights reserved.
//

import Foundation
import MLXRInternal

class XrClientBoundedVolume: NSObject {
    fileprivate let boundedVolume: MLXRBoundedVolume!
    public init(_ boundedVolume: MLXRBoundedVolume) {
        self.boundedVolume = boundedVolume
    }
    
    public func getAreaId() -> String {
        boundedVolume.getId();
        return boundedVolume.getAreaId()?.uuidString ?? ""
    }
    
    public func getId() -> String {
        return boundedVolume.getId()?.uuidString ?? ""
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
    
    public func getScale() -> [Float] {
        if let scale = boundedVolume.getScale()?.scale {
            return [scale[0], scale[1], scale[2]]
        }
        return [1,1,1]
    }
    
    public func getPose() -> simd_float4x4 {
        return boundedVolume.getPose()?.pose ?? matrix_identity_float4x4
    }
    
    public func getProperties() -> [String:Data] {
        return boundedVolume.getProperties()
    }
    
    @objc public func getJsonRepresentation() -> [String: Any] {
        return [
            "scale": getScale(),
            "properties": getProperties(),
            "pose": getFlatPose(),
            "id": getId(),
            "areaId": getAreaId()
        ]
    }
}
