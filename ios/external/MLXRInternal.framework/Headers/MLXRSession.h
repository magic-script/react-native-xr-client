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
#import <ARKit/ARKit.h>
#import <CoreLocation/CoreLocation.h>
#import "MLXRAnchor.h"
#import "MLXRLocalization.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MLXRSessionDelegate;

/// Manages the client session for shared experience in the real world.
@interface MLXRSession : NSObject
/// Default @c init is disabled.
- (instancetype)init NS_UNAVAILABLE;

/// Initializes the client session.
///
/// @param autoToken Authentication token.
/// @param session ARSession object acquired from ARKit.
///
/// @return The client session instance, or @c nil if the parameters are not valid.
- (instancetype)initWith:(id)autoToken :(ARSession *)session;

/// Connects to the server.
///
/// @param deviceId Device ID.
/// @param appId Application instance ID.
/// @param token Authentication token.
///
/// @return @c true if successfully connected, @c false otherwise.
- (BOOL)connect:(NSString *)deviceId :(NSString *)appId :(NSString *)token;

/// Updates the authentication token.
///
/// @param token Authentication token.
///
/// @return @c true if successfully updated, @c false otherwise.
- (BOOL)updateToken:(NSString *)token;

/// Updates the camera frame along with the location information to localize into a shared map.
/// Also checks tracking state to force relocalization.
///
/// @param frame ARFrame object captured from the ARSession.
/// @param location CLLocation object containing the geographical location .
///
/// @return @c true if successfully updated, @c false otherwise.
- (BOOL)update:(ARFrame *)frame :(CLLocation *)location;

/// Gets all anchors found in the scene.
///
/// @sa @c MLXRAnchor for the properties of each anchor.
///
/// @return An array of anchors found in the scene.
- (NSArray<MLXRAnchor *> *)getAllAnchors;

/// Gets an anchor by ID.
///
/// @sa @c MLXRAnchor for the properties of the anchor. Call @c getAllAnchors to refresh the anchors in the scene.
///
/// @param anchorId ID of the anchor.
///
/// @return An anchor with the given ID, or @c nil if error occurs.
- (MLXRAnchor * _Nullable)getAnchorById:(NSUUID *)anchorId;

/// Gets the localization result.
///
/// @sa @c MLXRLocalizationResult for the possible status.
///
/// @return Localiation status, or @c nil if error occurs.
- (MLXRLocalizationResult * _Nullable)getLocalizationStatus;

/// A delegate to receive MLXRAnchor updates.
@property (nonatomic, weak, nullable) id<MLXRSessionDelegate> delegate;

@property (readonly) id session_;

@end


/// Methods that can be called when MLXRAnchor objects are updated.
@protocol MLXRSessionDelegate <NSObject>

/// Called when MLXRAnchor objects are added.
/// @param session The MLXR client session.
/// @param anchors The MLXRANchor objects that are added.
@optional
- (void)session:(MLXRSession *)session didAdd:(NSArray<MLXRAnchor *> *)anchors;

/// Called when MLXRAnchor objects are removed.
/// @param session The MLXR client session.
/// @param anchors The MLXRANchor objects that are removed.
@optional
- (void)session:(MLXRSession *)session didRemove:(NSArray<MLXRAnchor *> *)anchors;

/// Called when MLXRAnchor objects are updated.
/// @param session The MLXR client session.
/// @param anchors The MLXRANchor objects that are updated.
@optional
- (void)session:(MLXRSession *)session didUpdate:(NSArray<MLXRAnchor *> *)anchors;

@end

NS_ASSUME_NONNULL_END
