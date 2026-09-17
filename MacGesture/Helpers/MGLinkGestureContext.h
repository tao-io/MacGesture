#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef id _Nullable (^MGAccessibilityValueProvider)(id element, NSString *attribute);
typedef NSString * _Nullable (^MGArcScriptExecutor)(NSString *source, NSError **error);
typedef NSURL * _Nullable (^MGLinkAtPointResolver)(CGPoint point);

FOUNDATION_EXPORT NSString *const MGAccessibilityRoleAttribute;
FOUNDATION_EXPORT NSString *const MGAccessibilityURLAttribute;
FOUNDATION_EXPORT NSString *const MGAccessibilityParentAttribute;
FOUNDATION_EXPORT NSString *const MGArcBrowserBundleIdentifier;

/// JavaScript that returns the deepest hovered anchor's absolute href, or an empty string.
FOUNDATION_EXPORT NSString *MGArcHoveredLinkJavaScript(void);

/// Wraps JavaScript in Arc's AppleScript bridge and escapes it for an AppleScript string.
FOUNDATION_EXPORT NSString *MGArcAppleScriptSourceForJavaScript(NSString *javascript);

/// Walks from an accessibility element to its parents and returns the first AXLink URL.
FOUNDATION_EXPORT NSURL * _Nullable MGLinkURLFromAccessibilityElement(
    id _Nullable element,
    MGAccessibilityValueProvider valueProvider);

/// Finds the accessible element at a global pointer position and resolves its link URL.
FOUNDATION_EXPORT NSURL * _Nullable MGCopyLinkURLAtPoint(CGPoint point);

/// Resolves an Arc hovered link first, then falls back to Accessibility when needed.
FOUNDATION_EXPORT NSURL * _Nullable MGResolveLinkURLAtPoint(
    CGPoint point,
    NSString *bundleIdentifier,
    MGArcScriptExecutor scriptExecutor,
    MGLinkAtPointResolver accessibilityResolver);

/// Resolves the link under the pointer for the front application.
FOUNDATION_EXPORT NSURL * _Nullable MGCopyLinkURLAtPointForApplication(
    CGPoint point,
    NSString *bundleIdentifier);

/// Session-scoped context. The first captured value, including nil, stays frozen until clear.
@interface MGLinkGestureContext : NSObject

+ (instancetype)sharedContext;

@property (nonatomic, readonly, nullable) NSURL *linkURL;
@property (nonatomic, readonly, getter=isActive) BOOL active;

- (void)beginWithLinkURL:(NSURL * _Nullable)linkURL;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
