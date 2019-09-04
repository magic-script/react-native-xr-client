// %BANNER_BEGIN%
// ---------------------------------------------------------------------
// %COPYRIGHT_BEGIN%
//
// Copyright (c) 2019 Magic Leap, Inc. (COMPANY) All Rights Reserved.
// Magic Leap, Inc. Confidential and Proprietary
//
// NOTICE: All information contained herein is, and remains the property
// of COMPANY. The intellectual and technical concepts contained herein
// are proprietary to COMPANY and may be covered by U.S. and Foreign
// Patents, patents in process, and are protected by trade secret or
// copyright law. Dissemination of this information or reproduction of
// this material is strictly forbidden unless prior written permission is
// obtained from COMPANY. Access to the source code contained herein is
// hereby forbidden to anyone except current COMPANY employees, managers
// or contractors who have executed Confidentiality and Non-disclosure
// agreements explicitly covering such access.
//
// The copyright notice above does not evidence any actual or intended
// publication or disclosure of this source code, which includes
// information that is confidential and/or proprietary, and is a trade
// secret, of COMPANY. ANY REPRODUCTION, MODIFICATION, DISTRIBUTION,
// PUBLIC PERFORMANCE, OR PUBLIC DISPLAY OF OR THROUGH USE OF THIS
// SOURCE CODE WITHOUT THE EXPRESS WRITTEN CONSENT OF COMPANY IS
// STRICTLY PROHIBITED, AND IN VIOLATION OF APPLICABLE LAWS AND
// INTERNATIONAL TREATIES. THE RECEIPT OR POSSESSION OF THIS SOURCE
// CODE AND/OR RELATED INFORMATION DOES NOT CONVEY OR IMPLY ANY RIGHTS
// TO REPRODUCE, DISCLOSE OR DISTRIBUTE ITS CONTENTS, OR TO MANUFACTURE,
// USE, OR SELL ANYTHING THAT IT MAY DESCRIBE, IN WHOLE OR IN PART.
// %COPYRIGHT_END%
// ---------------------------------------------------------------------
// %BANNER_END%
#import <Foundation/Foundation.h>
#import "MLXRSession.h"
#import "MLXRBoundedVolume.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MLXRSessionDelegateInternal;

@interface MLXRSession (MLXRSessionInternal)
/// Connects to the local cloud server.
///
/// @param gatewayAddress Address of the MQTT server to connect to.
/// @param pwAddress Address of the gRPC server to connect to.
/// @param deviceId Device ID.
/// @param appId Application instance ID.
/// @param token Authentication token.
///
/// @return @c true if successfully connected, @c false otherwise.
- (BOOL)connect:(NSString *)gatewayAddress :(NSString *)pwAddress :(NSString *)deviceId :(NSString *)appId :(NSString *) token;

/// Gets all Bounded Volumes found in the scene.
///
/// @sa @c MLXRBoundedVolume for the properties of each Bounded Volume.
///
/// @return An array of Bounded Volumes found in the scene.
- (NSArray<MLXRBoundedVolume *> *)getAllBoundedVolumes;

/// A delegate to receive MLXRAnchor updates.
@property (nonatomic, weak, nullable) id<MLXRSessionDelegateInternal> delegateInternal;

@end

/// Methods that can be called when MLXRAnchor and MLXRBoundedVolume objects are updated.
@protocol MLXRSessionDelegateInternal <MLXRSessionDelegate>

/// Called when MLXRBoundedVolume objects are added.
/// @param session The MLXR client session.
/// @param anchors The MLXRBoundedVolume objects that are added.
@optional
- (void)session:(MLXRSession *)session didAddBoundedVolumes:(NSArray<MLXRBoundedVolume *> *)boundedVolumes;

/// Called when MLXRBoundedVolume objects are removed.
/// @param session The MLXR client session.
/// @param anchors The MLXRBoundedVolume objects that are removed.
@optional
- (void)session:(MLXRSession *)session didRemoveBoundedVolumes:(NSArray<MLXRBoundedVolume *> *)boundedVolumes;

/// Called when MLXRBoundedVolume objects are updated.
/// @param session The MLXR client session.
/// @param anchors The MLXRBoundedVolume objects that are updated.
@optional
- (void)session:(MLXRSession *)session didUpdateBoundedVolumes:(NSArray<MLXRBoundedVolume *> *)boundedVolumes;

@end

NS_ASSUME_NONNULL_END
