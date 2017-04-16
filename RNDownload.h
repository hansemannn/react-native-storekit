//
//  RNDownload.h
//
//  Created by Hans Knöchel on 16.04.17.
//  Copyright © 2017 Hans Knöchel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import <React/RCTBridgeModule.h>

@interface RNDownload : NSObject<RCTBridgeModule> {
  SKDownload *download;
}

- (SKDownload *)download;

- (instancetype)initWithDownload:(SKDownload *)_download;

@end
