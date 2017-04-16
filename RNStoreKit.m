//
//  StoreKitManager.m
//
//  Created by Hans Knöchel on 16.04.17.
//  Copyright © 2017 Hans Knöchel. All rights reserved.
//

#import <React/RCTConvert.h>

#import "RNStoreKit.h"
#import "RNProductRequest.h"
#import "RNProduct.h"
#import "RNDownload.h"
#import "RNTransaction.h"

@implementation RNStoreKit

- (instancetype)init
{
    if (self = [super init]) {
        receiptVerificationSandbox = NO;
        transactionObserverSet = NO;
        autoFinishTransactions = YES;
    }
    
    return self;
}

- (void)dealloc
{
    [self removeTransactionObserver];
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[
             @"transactionState",
             @"updatedDownloads",
             @"restoredCompletedTransactions"
    ];
}

RCT_EXPORT_MODULE();

#pragma mark Public API's

RCT_EXPORT_METHOD(refreshReceipt:(NSDictionary *)properties callback:(RCTResponseSenderBlock)callback)
{
    refreshReceiptCallback = callback;
    
    SKReceiptRefreshRequest *request = [[SKReceiptRefreshRequest alloc] initWithReceiptProperties:properties];
    [request setDelegate:self];
    [request start];
}

RCT_EXPORT_METHOD(requestProducts:(NSArray *)ids
                  callback:(RCTResponseSenderBlock)callback
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    if (![SKPaymentQueue canMakePayments]) {
        reject(@"-1", @"In-app purchase is disabled. Please enable it to activate more features.", nil);
        return;
    }
    
    resolve([[RNProductRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:ids] callback:callback]);
}

RCT_EXPORT_METHOD(purchase:(NSDictionary *)args)
{
    RNProduct *product = [args objectForKey:@"product"];
    int quantity = [RCTConvert int:[args objectForKey:@"quantity"]];
    NSString *username = [RCTConvert NSString:[args objectForKey:@"applicationUsername"]];
    
    if (!product) {
        NSLog(@"[ERROR] The 'product' key is required!");
        return;
    }
    
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:[product product]];
    payment.quantity = quantity;
    
    [payment setApplicationUsername:username];
    
    SKPaymentQueue *queue = [SKPaymentQueue defaultQueue];
    [queue addPayment:payment];
    
    if (!transactionObserverSet) {
        [self logAddTransactionObserverFirst:@"purchase"];
    }
}

RCT_EXPORT_METHOD(addTransactionObserver:(id)args)
{
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    transactionObserverSet = YES;
}

RCT_EXPORT_METHOD(removeTransactionObserver)
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    transactionObserverSet = NO;
}

RCT_EXPORT_METHOD(receiptExists:(RCTPromiseResolveBlock)resolve)
{
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    resolve(@[[NSNumber numberWithBool:[[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]]]);
}

RCT_EXPORT_METHOD(canMakePayments:(RCTPromiseResolveBlock)resolve)
{
    resolve(@[[NSNumber numberWithBool:[SKPaymentQueue canMakePayments]]]);
}

RCT_EXPORT_METHOD(startDownloads:(NSArray *)downloads)
{
    if (autoFinishTransactions) {
        NSLog(@"'autoFinishTransactions' must be set to false before using download functionality");
        return;
    }
    
    [[SKPaymentQueue defaultQueue] startDownloads:[self nativeDownloadsFromBridgedDownloads:downloads]];
}

RCT_EXPORT_METHOD(cancelDownloads:(NSArray *)downloads)
{
    if (autoFinishTransactions) {
        NSLog(@"'autoFinishTransactions' must be set to false before using download functionality");
        return;
    }
    
    [[SKPaymentQueue defaultQueue] cancelDownloads:[self nativeDownloadsFromBridgedDownloads:downloads]];
}

RCT_EXPORT_METHOD(pauseDownloads:(NSArray *)downloads)
{
    if (autoFinishTransactions) {
        NSLog(@"'autoFinishTransactions' must be set to false before using download functionality");
        return;
    }
    
    [[SKPaymentQueue defaultQueue] pauseDownloads:[self nativeDownloadsFromBridgedDownloads:downloads]];
}

RCT_EXPORT_METHOD(resumeDownloads:(NSArray *)downloads)
{
    if (autoFinishTransactions) {
        NSLog(@"'autoFinishTransactions' must be set to false before using download functionality");
        return;
    }
    
    [[SKPaymentQueue defaultQueue] resumeDownloads:[self nativeDownloadsFromBridgedDownloads:downloads]];
}

RCT_EXPORT_METHOD(restoreCompletedTransactions:(NSDictionary *)args)
{
    if (args == nil) {
        NSString *username = [args objectForKey:@"username"];
        [[SKPaymentQueue defaultQueue] restoreCompletedTransactionsWithApplicationUsername:username];
    } else {
        [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    }
    
    if (!transactionObserverSet) {
        [self logAddTransactionObserverFirst:@"restoreCompletedTransactions"];
    }
}

RCT_EXPORT_METHOD(setReceiptVerificationSandbox:(BOOL)value)
{
    receiptVerificationSandbox = value;
}

RCT_EXPORT_METHOD(setBundleVersion:(NSString *)_bundleVersion)
{
    bundleVersion = _bundleVersion;
}

RCT_EXPORT_METHOD(setBundleIdentifier:(NSString *)_bundleIdentifier)
{
    bundleIdentifier = _bundleIdentifier;
}

RCT_EXPORT_METHOD(setAutoFinishTransactions:(NSString *)_autoFinishTransactions)
{
    autoFinishTransactions = _autoFinishTransactions;
}

#pragma mark Delegates

- (void)requestDidFinish:(SKRequest *)request
{
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                           @YES,@"success",
                           nil];
    
    refreshReceiptCallback(@[event]);
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                           @NO,@"success",
                           [error localizedDescription],@"error",
                           nil];
    
    refreshReceiptCallback(@[event]);
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        [self handleTransaction:transaction error:transaction.error];
    }
}

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    NSLog(@"[ERROR] Failed to restore all completed transactions: %@", error);
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:[error localizedDescription],@"error",nil];
    
    [self sendEventWithName:@"restoredCompletedTransactions" body:event];
}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    NSLog(@"[INFO] Finished restoring completed transactions!");
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:restoredTransactions,@"transactions",nil];
    
    [self sendEventWithName:@"restoredCompletedTransactions" body:event];
}

// Sent when there is progress with a download
- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads
{
    NSArray *dls = [self brigedDownloadsFromNativeDownloads:downloads];
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:dls, @"downloads", nil];
    
    [self sendEventWithName:@"updatedDownloads" body:event];
}

#pragma mark Utilities

- (void)handleTransaction:(SKPaymentTransaction *)transaction error:(NSError *)error
{
    SKPaymentTransactionState state = transaction.transactionState;
    NSMutableDictionary *event = [self populateTransactionEvent:transaction];
    
    if (state == SKPaymentTransactionStateFailed) {
        NSLog(@"[WARN] Error in transaction: %@", [error localizedDescription]);
        // MOD-1025: Cancelled state is actually determined by the error code
        BOOL cancelled = ([error code] == SKErrorPaymentCancelled);
        [event setObject:cancelled ? @YES : @NO forKey:@"cancelled"];
        if (!cancelled) {
            [event setObject:[error localizedDescription] forKey:@"message"];
        }
    } else if (state == SKPaymentTransactionStateRestored) {
        NSLog(@"[DEBUG] Transaction restored %@",transaction);
        // If this is a restored transaction, add it to the list of restored transactions
        // that will be posted in the event indicating that transactions have been restored.
        if (restoredTransactions == nil) {
            restoredTransactions = [[NSMutableArray alloc] initWithCapacity:1];
        }
        
        [restoredTransactions addObject:[[RNTransaction alloc] initWithTransaction:transaction]];
    }
    // Nothing special to do for SKPaymentTransactionStatePurchased or SKPaymentTransactionStatePurchasing
    
    [self sendEventWithName:@"transactionState" body:event];
    
    if (autoFinishTransactions) {
        // We need to finish the transaction as long as it is not still in progress
        switch (state)
        {
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"[DEBUG] Purchasing for %@",transaction);
                break;
                
            case SKPaymentTransactionStateDeferred:
                NSLog(@"[DEBUG] Deffered transaction for %@",transaction);
                break;
            case SKPaymentTransactionStatePurchased:
            case SKPaymentTransactionStateFailed:
            case SKPaymentTransactionStateRestored:
            {
                NSLog(@"[DEBUG] Calling finish transaction for %@",transaction);
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            }
        }
    }
}

- (NSMutableDictionary *)populateTransactionEvent:(SKPaymentTransaction *)transaction
{
    NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInteger:transaction.transactionState],@"state",
                                  nil];
    
    
    NSData *dataReceipt = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    
    if (dataReceipt != nil) {
        [event setObject:[dataReceipt base64EncodedStringWithOptions:0] forKey:@"receipt"];
    }
    
    if (transaction.transactionDate) {
        [event setObject:transaction.transactionDate forKey:@"date"];
    }
    
    if (transaction.transactionIdentifier) {
        [event setObject:transaction.transactionIdentifier forKey:@"identifier"];
    }
    
    if (transaction.payment) {
        [event setObject:[NSNumber numberWithInteger:transaction.payment.quantity] forKey:@"quantity"];
        if (transaction.payment.productIdentifier) {
            [event setObject:transaction.payment.productIdentifier forKey:@"productIdentifier"];
        }
    }
    
    [event setObject:[self brigedDownloadsFromNativeDownloads:[transaction downloads]] forKey:@"downloads"];
    
    // MOD-1475 -- Restored transactions will include the original transaction. If found in the transaction
    // then we will add it to the event dictionary
    if (transaction.originalTransaction) {
        [event setObject:[[RNTransaction alloc] initWithTransaction:transaction.originalTransaction] forKey:@"originalTransaction"];
    }
    
    [event setObject:[[RNTransaction alloc] initWithTransaction:transaction] forKey:@"transaction"];
    
    return event;
}

- (void)logAddListenerFirst:(NSString *)name
{
    NSLog(@"[WARN] A `%@` event listener should be added before calling `addTransactionObserver` to avoid missing events.", name);
}

- (void)logAddTransactionObserverFirst:(NSString *)name
{
    NSLog(@"[WARN] `addTransactionObserver` should be called before `%@`.", name);
}

- (NSArray *)brigedDownloadsFromNativeDownloads:(NSArray *)_downloads
{
    NSMutableArray *downloads = [NSMutableArray arrayWithCapacity:[_downloads count]];
    for (SKDownload *download in downloads) {
        [downloads addObject:[[RNDownload alloc] initWithDownload:download]];
    }
    
    return downloads;
}


- (NSArray *)nativeDownloadsFromBridgedDownloads:(NSArray *)downloads
{
    NSMutableArray *dls = [NSMutableArray arrayWithCapacity:[downloads count]];
    for (RNDownload *download in downloads) {
        [dls addObject:[download download]];
    }
    return dls;
}

@end
