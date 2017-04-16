//
//  RNTransaction.m
//
//  Created by Hans Knöchel on 16.04.17.
//  Copyright © 2017 Hans Knöchel. All rights reserved.
//

#import "RNTransaction.h"

@implementation RNTransaction

RCT_EXPORT_MODULE()

- (instancetype)initWithTransaction:(SKPaymentTransaction *)_transaction
{
  if (self = [super init]) {
    transaction = _transaction;
  }
  
  return self;
}

RCT_EXPORT_METHOD(finish)
{
  NSLog(@"[DEBUG] Transaction finished %@",transaction);

  if (!transaction) {
    return;
  }

  [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

@end
