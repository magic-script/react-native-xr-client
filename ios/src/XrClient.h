//
//  XrClientSession.h
//  RNXrClient
//
//  Created by Tim Caswell on 8/15/19.
//  Copyright © 2019 Magic Leap. All rights reserved.
//

@class ARSession;

@interface XrClient : NSObject

+ (void)registerSession:(ARSession*)session;

@end
