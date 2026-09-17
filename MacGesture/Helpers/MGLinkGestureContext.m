#import "MGLinkGestureContext.h"
#import <ApplicationServices/ApplicationServices.h>

NSString *const MGAccessibilityRoleAttribute = @"role";
NSString *const MGAccessibilityURLAttribute = @"url";
NSString *const MGAccessibilityParentAttribute = @"parent";
NSString *const MGArcBrowserBundleIdentifier = @"company.thebrowser.Browser";

NSString *MGArcHoveredLinkJavaScript(void) {
    return @"(()=>{const elements=document.querySelectorAll(':hover');"
        "for(let i=elements.length-1;i>=0;i--){"
        "const link=elements[i].closest('a[href]');"
        "if(link){return link.href||'';}}return '';})()";
}

static NSString *MGAppleScriptQuotedString(NSString *value) {
    NSString *escaped = [value stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    return [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
}

NSString *MGArcAppleScriptSourceForJavaScript(NSString *javascript) {
    return [NSString stringWithFormat:
        @"tell application id \"%@\"\n"
         "return execute active tab of front window javascript \"%@\"\n"
         "end tell",
        MGArcBrowserBundleIdentifier, MGAppleScriptQuotedString(javascript)];
}

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

static NSURL *MGUsableURLFromString(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *trimmed = [value stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return nil;
    }
    NSURL *url = [[NSURL URLWithString:trimmed] absoluteURL];
    return url.scheme.length > 0 && url.absoluteString.length > 0 ? url : nil;
}

NSURL *MGResolveLinkURLAtPoint(
    CGPoint point,
    NSString *bundleIdentifier,
    MGArcScriptExecutor scriptExecutor,
    MGLinkAtPointResolver accessibilityResolver) {
    if ([bundleIdentifier isEqualToString:MGArcBrowserBundleIdentifier]
        && scriptExecutor != nil) {
        NSError *error = nil;
        NSString *value = scriptExecutor(
            MGArcAppleScriptSourceForJavaScript(MGArcHoveredLinkJavaScript()), &error);
        NSURL *url = error == nil ? MGUsableURLFromString(value) : nil;
        if (url != nil) {
            return url;
        }
    }
    return accessibilityResolver != nil ? accessibilityResolver(point) : nil;
}

static NSString *MGExecuteArcAppleScript(NSString *source, NSError **error) {
    NSDictionary *errorInfo = nil;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    NSAppleEventDescriptor *result = [script executeAndReturnError:&errorInfo];
    if (errorInfo != nil) {
        if (error != NULL) {
            NSInteger code = [errorInfo[NSAppleScriptErrorNumber] integerValue];
            *error = [NSError errorWithDomain:@"MGArcAppleScriptError"
                code:code userInfo:errorInfo];
        }
        return nil;
    }
    return result.stringValue;
}

NSURL *MGCopyLinkURLAtPointForApplication(CGPoint point, NSString *bundleIdentifier) {
    return MGResolveLinkURLAtPoint(point, bundleIdentifier,
        ^NSString *(NSString *source, NSError **error) {
            return MGExecuteArcAppleScript(source, error);
        }, ^NSURL *(CGPoint accessibilityPoint) {
            return MGCopyLinkURLAtPoint(accessibilityPoint);
        });
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
