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
import MLXRInternal

@objc public enum XrClientLocalization : Int {
    case awaitingLocation
    case scanningLocation
    case localized
    case localizationFailed

    public typealias RawValue = String

    public var rawValue: RawValue {
        switch self {
        case .awaitingLocation:
            return "awaitingLocation"
        case .scanningLocation:
            return "scanningLocation"
        case .localized:
            return "localized"
        case .localizationFailed:
            return "localizationFailed"
        }
    }

    public init?(rawValue: RawValue) {
        switch rawValue {
        case "awaitingLocation":
            self = .awaitingLocation
        case "scanningLocation":
            self = .scanningLocation
        case "localized":
            self = .localized
        case "localizationFailed":
            self = .localizationFailed
        default:
            return nil
        }
    }

    public init(localizationStatus: MLXRLocalizationStatus) {
        switch localizationStatus {
        case MLXRLocalizationStatus_AwaitingLocation:
            self = .awaitingLocation
        case MLXRLocalizationStatus_ScanningLocation:
            self = .scanningLocation
        case MLXRLocalizationStatus_Localized:
            self = .localized
        case MLXRLocalizationStatus_LocalizationFailed:
            self = .localizationFailed
        default:
            self = .localizationFailed
        }
    }
}
