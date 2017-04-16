//
//  RNProduct.m
//
//  Created by Hans Knöchel on 16.04.17.
//  Copyright © 2017 Hans Knöchel. All rights reserved.
//

#import "RNProduct.h"

@implementation RNProduct

RCT_EXPORT_MODULE()

- (id)initWithProduct:(SKProduct *)_product
{
  if (self = [super init]) {
    product = _product;
  }
  
  return self;
}

- (SKProduct *)product
{
  return product;
}

@end
