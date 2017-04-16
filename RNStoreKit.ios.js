/**
 * @providesModule RNStoreKit
 * @flow
 */
'use strict';

var NativeRNStoreKit = require('NativeModules').RNStoreKit;

/**
 * High-level docs for the RNStoreKit iOS API can be written here.
 */

var RNStoreKit = {
  test: function() {
    NativeRNStoreKit.test();
  }
};

module.exports = RNStoreKit;
