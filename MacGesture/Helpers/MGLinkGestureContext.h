#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef id _Nullable (^MGAccessibilityValueProvider)(id element, NSString *attribute);

FOUNDATION_EXPORT NSString *const MGAccessibilityRoleAttribute;
FOUNDATION_EXPORT NSString *const MGAccessibilityURLAttribute;
FOUNDATION_EXPORT NSString *const MGAccessibilityParentAttribute;

/// Walks from an accessibility element to its parents and returns the first AXLink URL.
FOUNDATION_EXPORT NSURL * _Nullable MGLinkURLFromAccessibilityElement(
    id _Nullable element,
    MGAccessibilityValueProvider valueProvider);

/// Finds the accessible element at a global pointer position and resolves its link URL.
FOUNDATION_EXPORT NSURL * _Nullable MGCopyLinkURLAtPoint(CGPoint point);

/// Session-scoped context. The first captured value, including nil, stays frozen until clear.
@interface MGLinkGestureContext : NSObject

+ (instancetype)sharedContext;

@property (nonatomic, readonly, nullable) NSURL *linkURL;
@property (nonatomic, readonly, getter=isActive) BOOL active;

- (void)beginWithLinkURL:(NSURL * _Nullable)linkURL;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
