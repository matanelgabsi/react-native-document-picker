#import "RNDocumentPicker.h"

#if __has_include(<React/RCTConvert.h>)
#import <React/RCTConvert.h>
#import <React/RCTBridge.h>
#else // back compatibility for RN version < 0.40
#import "RCTConvert.h"
#import "RCTBridge.h"
#endif

#define IDIOM    UI_USER_INTERFACE_IDIOM()
#define IPAD     UIUserInterfaceIdiomPad

@interface RNDocumentPicker () <UIDocumentMenuDelegate,UIDocumentPickerDelegate>
@end


@implementation RNDocumentPicker {
  NSMutableArray *_composeCallbacks;
}

@synthesize bridge = _bridge;

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(showAsync:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock) resolve
                  rejecter:(RCTPromiseRejectBlock) reject) {
  [[self composeCallbacks] addObject:@{@"resolver": resolve, @"rejecter": reject}];
  [self show:options];
}

RCT_EXPORT_METHOD(show:(NSDictionary *)options
                  callback:(RCTResponseSenderBlock)callback) {
  [[self composeCallbacks] addObject:callback];
  [self show:options];
}

- (void) show: (NSDictionary *) options {
  NSArray *allowedUTIs = [RCTConvert NSArray:options[@"filetype"]];
  UIDocumentMenuViewController *documentPicker = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:(NSArray *)allowedUTIs inMode:UIDocumentPickerModeImport];
  
  
  
  
  documentPicker.delegate = self;
  documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
  
  UIViewController *rootViewController = [[[[UIApplication sharedApplication]delegate] window] rootViewController];
  while (rootViewController.presentedViewController) {
    rootViewController = rootViewController.presentedViewController;
  }
  
  if ( IDIOM == IPAD ) {
    NSNumber *top = [RCTConvert NSNumber:options[@"top"]];
    NSNumber *left = [RCTConvert NSNumber:options[@"left"]];
    [documentPicker.popoverPresentationController setSourceRect: CGRectMake([left floatValue], [top floatValue], 0, 0)];
    [documentPicker.popoverPresentationController setSourceView: rootViewController.view];
  }
  
  if (options[@"additionalItems"]) {
    for (NSString *item in options[@"additionalItems"]) {
      [documentPicker addOptionWithTitle:item image:nil order:UIDocumentMenuOrderLast handler:[self handlerForItem: item]];
    }
  }
  
  [rootViewController presentViewController:documentPicker animated:YES completion:nil];
}

- (void (^)(void)) handlerForItem: (NSString *) item {
  __weak typeof(self) weakSelf = self;
  return ^{
    id callback = [[weakSelf composeCallbacks] lastObject];
    [[weakSelf composeCallbacks] removeLastObject];
    if (callback) {
      if ([callback isKindOfClass:[NSDictionary class]]) {
        RCTPromiseResolveBlock resolve = [callback objectForKey: @"resolver"];
        resolve(item);
      } else {
        ((RCTResponseSenderBlock)callback)(@[[NSNull null], item]);
      }
    }
  };
}

- (void)documentMenuWasCancelled:(UIDocumentMenuViewController *)documentMenu {
  RCTResponseSenderBlock callback = [[self composeCallbacks] lastObject];
  [[self composeCallbacks] removeLastObject];
  if ([callback isKindOfClass:[NSDictionary class]]) {
    RCTPromiseResolveBlock resolve = [callback objectForKey: @"resolver"];
    resolve(nil);
  } else {
    ((RCTResponseSenderBlock)callback)(@[[NSNull null], [NSNull null]]);
  }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
  RCTResponseSenderBlock callback = [[self composeCallbacks] lastObject];
  [[self composeCallbacks] removeLastObject];
  if ([callback isKindOfClass:[NSDictionary class]]) {
    RCTPromiseResolveBlock resolve = [callback objectForKey: @"resolver"];
    resolve(nil);
  } else {
    ((RCTResponseSenderBlock)callback)(@[[NSNull null], [NSNull null]]);
  }
}


- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker {
  documentPicker.delegate = self;
  documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
  
  UIViewController *rootViewController = [[[[UIApplication sharedApplication]delegate] window] rootViewController];
  
  while (rootViewController.presentedViewController) {
    rootViewController = rootViewController.presentedViewController;
  }
  if ( IDIOM == IPAD ) {
    [documentPicker.popoverPresentationController setSourceRect: CGRectMake(rootViewController.view.frame.size.width/2, rootViewController.view.frame.size.height - rootViewController.view.frame.size.height / 6, 0, 0)];
    [documentPicker.popoverPresentationController setSourceView: rootViewController.view];
  }
  
  [rootViewController presentViewController:documentPicker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
  if (controller.documentPickerMode == UIDocumentPickerModeImport) {
    id callback = [[self composeCallbacks] lastObject];
    [[self composeCallbacks] removeLastObject];
    
    [url startAccessingSecurityScopedResource];
    
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];
    __block NSError *error;
    
    [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingResolvesSymbolicLink error:&error byAccessor:^(NSURL *newURL) {
      NSMutableDictionary* result = [NSMutableDictionary dictionary];
      
      [result setValue:newURL.absoluteString forKey:@"uri"];
      [result setValue:[newURL lastPathComponent] forKey:@"fileName"];
      
      NSString* type;
      NSError* error;
      [url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&error];
      if(type) {
        [result setValue:type forKey:@"type"];
      }
      
      
      NSError *attributesError = nil;
      NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:newURL.path error:&attributesError];
      if(!attributesError) {
        [result setValue:[fileAttributes objectForKey:NSFileSize] forKey:@"fileSize"];
      } else {
        NSLog(@"%@", attributesError);
      }
      
      if ([callback isKindOfClass:[NSDictionary class]]) {
        RCTPromiseResolveBlock resolve = [callback objectForKey: @"resolver"];
        resolve(result);
      } else {
        ((RCTResponseSenderBlock)callback)(@[[NSNull null], result]);
      }
    }];
    
    [url stopAccessingSecurityScopedResource];
  }
}

- (NSMutableArray *)composeCallbacks {
  if(_composeCallbacks == nil) {
    _composeCallbacks = [[NSMutableArray alloc] init];
  }
  return _composeCallbacks;
}

@end
