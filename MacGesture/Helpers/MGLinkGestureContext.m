#import "MGLinkGestureContext.h"
#import <ApplicationServices/ApplicationServices.h>

NSString *const MGAccessibilityRoleAttribute = @"role";
NSString *const MGAccessibilityURLAttribute = @"url";
NSString *const MGAccessibilityParentAttribute = @"parent";

static NSURL *MGURLFromAccessibilityValue(id value) {
    NSURL *url = nil;
    if ([value isKindOfClass:[NSURL class]]) {
        url = [(NSURL *)value absoluteURL];
    } else if ([value isKindOfClass:[NSString class]]) {
        url = [[NSURL URLWithString:(NSString *)value] absoluteURL];
    }
    return url.scheme.length > 0 ? url : nil;
}

NSURL *MGLinkURLFromAccessibilityElement(id element, MGAccessibilityValueProvider valueProvider) {
    if (element == nil || valueProvider == nil) {
        return nil;
    }

    id current = element;
    for (NSUInteger depth = 0; current != nil && depth < 32; depth++) {
        NSString *role = valueProvider(current, MGAccessibilityRoleAttribute);
        if ([role isEqualToString:@"AXLink"]) {
            NSURL *url = MGURLFromAccessibilityValue(
                valueProvider(current, MGAccessibilityURLAttribute));
            if (url != nil && url.absoluteString.length > 0) {
                return url;
            }
        }
        current = valueProvider(current, MGAccessibilityParentAttribute);
    }
    return nil;
}

static id MGCopyAccessibilityValue(id element, NSString *attribute) {
    CFStringRef axAttribute = NULL;
    if ([attribute isEqualToString:MGAccessibilityRoleAttribute]) {
        axAttribute = kAXRoleAttribute;
    } else if ([attribute isEqualToString:MGAccessibilityURLAttribute]) {
        axAttribute = kAXURLAttribute;
    } else if ([attribute isEqualToString:MGAccessibilityParentAttribute]) {
        axAttribute = kAXParentAttribute;
    }
    if (axAttribute == NULL) {
        return nil;
    }

    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(
        (__bridge AXUIElementRef)element, axAttribute, &value);
    if (error != kAXErrorSuccess || value == NULL) {
        return nil;
    }
    return CFBridgingRelease(value);
}

NSURL *MGCopyLinkURLAtPoint(CGPoint point) {
    AXUIElementRef systemWideElement = AXUIElementCreateSystemWide();
    AXUIElementRef element = NULL;
    AXError error = AXUIElementCopyElementAtPosition(
        systemWideElement, (float)point.x, (float)point.y, &element);
    CFRelease(systemWideElement);
    if (error != kAXErrorSuccess || element == NULL) {
        return nil;
    }

    NSURL *url = MGLinkURLFromAccessibilityElement(
        CFBridgingRelease(element), ^id(id item, NSString *attribute) {
            return MGCopyAccessibilityValue(item, attribute);
        });
    return url;
}

@interface MGLinkGestureContext ()

@property (nonatomic, readwrite, nullable) NSURL *linkURL;
@property (nonatomic, readwrite, getter=isActive) BOOL active;

@end

@implementation MGLinkGestureContext

+ (instancetype)sharedContext {
    static MGLinkGestureContext *context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [MGLinkGestureContext new];
    });
    return context;
}

- (void)beginWithLinkURL:(NSURL *)linkURL {
    if (self.active) {
        return;
    }
    self.active = YES;
    self.linkURL = [linkURL copy];
}

- (void)clear {
    self.linkURL = nil;
    self.active = NO;
}

@end
