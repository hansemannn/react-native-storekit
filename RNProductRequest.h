//
//  ProductRequest.h
//
//  Created by Hans Knöchel on 16.04.17.
//  Copyright © 2017 Hans Knöchel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import <React/RCTBridgeModule.h>

@interface RNProductRequest : NSObject<RCTBridgeModule, SKProductsRequestDelegate> {
  SKProductsRequest *request;
  RCTResponseSenderBlock callback;
}

- (id)initWithProductIdentifiers:(NSSet *)set callback:(RCTResponseSenderBlock)_callback;

@end
