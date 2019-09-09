//
//  MLXrClientSession.m
//  RNMagicScript
//
//  Created by Pawel Leszkiewicz on 17/07/2019.
//  Copyright © 2019 MagicLeap. All rights reserved.
//

#import <React/RCTBridgeModule.h>
#import <MLXRInternal/MLXRInternal.h>

@interface RCT_EXTERN_MODULE(XrClientSession, NSObject)

RCT_EXTERN_METHOD(connect:(NSString *)gatewayAddress pwAddress:(NSString *)pwAddress deviceId:(NSString *)deviceId appId:(NSString *)appId token:(NSString *)token resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(setUpdateInterval:(NSTimeInterval)interval resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(getAllPCFs:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(getPCFById:(NSString *)pcfId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(getLocalizationStatus:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(getAllBoundedVolumes:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(createAnchor:(NSString *)anchorId position:(NSArray*)position resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(removeAnchor:(NSString *)anchorId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(removeAllAnchors:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

@end
