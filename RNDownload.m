//
//  RNDownload.m
//
//  Created by Hans Knöchel on 16.04.17.
//  Copyright © 2017 Hans Knöchel. All rights reserved.
//

#import "RNDownload.h"

@implementation RNDownload

RCT_EXPORT_MODULE()

- (instancetype)initWithDownload:(SKDownload *)_download
{
  if (self = [super init]) {
    download = _download;
  }
  
  return self;
}

- (SKDownload *)download
{
  return download;
}

@end
