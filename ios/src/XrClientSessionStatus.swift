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
import MLXR

@objc public enum XrClientSessionStatus: Int {
    case connected
    case connecting
    case disconnected

    public typealias RawValue = String

    public var rawValue: RawValue {
        switch self {
        case .connected:
            return "connected"
        case .connecting:
            return "connecting"
        case .disconnected:
            return "disconnected"
        }
    }

    public init?(rawValue: RawValue) {
        switch rawValue {
        case "connected":
            self = .connected
        case "connecting":
            self = .connecting
        case "disconnected":
            self = .disconnected
        default:
            return nil
        }
    }

    public init(sessionStatus: MLXRSessionStatus) {
        switch sessionStatus {
        case MLXRSessionStatus_Connected:
            self = .connected
        case MLXRSessionStatus_Connecting:
            self = .connecting
        case MLXRSessionStatus_Disconnected:
            self = .disconnected
        default:
            self = .disconnected
        }
    }
}
