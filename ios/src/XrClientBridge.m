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

#import <ARKit/ARKit.h>
#import <CoreLocation/CoreLocation.h>
#import "XrClientBridge.h"
#import "RNXrClient-Swift.h"

@implementation XrClientBridge

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(connect:(NSString *)token resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [XrClientSession.instance connect:token resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(getAllPCFs:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [XrClientSession.instance getAllPCFs:resolve reject:reject];
}

RCT_EXPORT_METHOD(getLocalizationStatus:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [XrClientSession.instance getLocalizationStatus:resolve reject:reject];
}

RCT_EXPORT_METHOD(getSessionStatus:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [XrClientSession.instance getSessionStatus:resolve reject:reject];
}

RCT_EXPORT_METHOD(createAnchor:(NSString *)anchorId position:(NSArray *)position resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [XrClientSession.instance createAnchor:anchorId position:position resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(removeAnchor:(NSString *)anchorId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [XrClientSession.instance removeAnchor:anchorId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(removeAllAnchors:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [XrClientSession.instance removeAllAnchors:resolve reject:reject];
}

@end
