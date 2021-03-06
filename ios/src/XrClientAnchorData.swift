//
//  Copyright (c) 2019 Magic Leap, Inc. All Rights Reserved
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import SceneKit
import MLXR

@objc public class XrClientAnchorData: NSObject {
    fileprivate let anchorData: MLXRAnchor!

    public init(_ anchorData: MLXRAnchor) {
        self.anchorData = anchorData
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
            "confidence": getConfidence(),
            "pose": getFlatPose(),
            "anchorId": getAnchorId()
        ]
    }

    public static func mat4FromColumnMajorFlatArray(_ flat: [Float]) -> simd_float4x4? {
        if (flat.count != 16) {
            return nil
        }
        return simd_float4x4(simd_float4(flat[0], flat[4], flat[8], flat[12]),
                             simd_float4(flat[1], flat[5], flat[9], flat[13]),
                             simd_float4(flat[2], flat[6], flat[10], flat[14]),
                             simd_float4(flat[3], flat[7], flat[11], flat[15]))
    }
}
