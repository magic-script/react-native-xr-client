//
//  XrClient.m
//  RNXrClient
//
//  Created by Tim Caswell on 8/15/19.
//  Copyright © 2019 Magic Leap. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <RNXrClient-Swift.h>
#import "XrClient.h"

@implementation XrClient : NSObject

+ (void)registerARSCNView:(ARSCNView*)arView {
    [XrClientSession registerARSCNView:arView];
}

@end
