#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MGLinkURLAction) {
    MGLinkURLActionCopy,
    MGLinkURLActionOpen,
    MGLinkURLActionOpenInNewWindow,
};

typedef BOOL (^MGCopyURLHandler)(NSString *absoluteURLString);
typedef BOOL (^MGOpenURLHandler)(NSURL *url);
typedef BOOL (^MGOpenURLInNewWindowHandler)(NSURL *url, NSString *sourceBundleIdentifier);

@interface MGLinkActionExecutor : NSObject

- (instancetype)initWithCopyHandler:(MGCopyURLHandler)copyHandler
                         openHandler:(MGOpenURLHandler)openHandler
                    newWindowHandler:(MGOpenURLInNewWindowHandler)newWindowHandler
    NS_DESIGNATED_INITIALIZER;

- (BOOL)performAction:(MGLinkURLAction)action
                  URL:(NSURL *)url
sourceBundleIdentifier:(NSString *)sourceBundleIdentifier;

@end

NS_ASSUME_NONNULL_END
