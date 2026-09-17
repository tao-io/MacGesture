#import <Cocoa/Cocoa.h>
#import "MGLinkGestureContext.h"

static void TestLinkContext(void) {
    NSDictionary *link = @{ @"role": @"AXLink", @"url": @"https://example.com/path" };
    NSDictionary *child = @{ @"role": @"AXStaticText", @"parent": link };
    MGAccessibilityValueProvider provider = ^id(NSDictionary *element, NSString *attribute) {
        return element[attribute];
    };

    NSCAssert([MGLinkURLFromAccessibilityElement(child, provider).absoluteString
        isEqualToString:@"https://example.com/path"], @"A nested link must resolve");
    NSCAssert(MGLinkURLFromAccessibilityElement(@{ @"role": @"AXButton" }, provider) == nil,
        @"A non-link must not resolve");

    MGLinkGestureContext *context = [MGLinkGestureContext new];
    NSURL *initialURL = [NSURL URLWithString:@"https://example.com/initial"];
    [context beginWithLinkURL:initialURL];
    [context beginWithLinkURL:[NSURL URLWithString:@"https://example.com/moved"]];
    NSCAssert([context.linkURL isEqual:initialURL], @"The first URL must stay frozen");

    [context clear];
    NSCAssert(context.linkURL == nil, @"Clear must remove the URL");

    [context beginWithLinkURL:nil];
    [context beginWithLinkURL:[NSURL URLWithString:@"https://example.com/late"]];
    NSCAssert(context.isActive && context.linkURL == nil,
        @"A missing initial URL must also stay frozen");
}

int main(void) {
    @autoreleasepool {
        TestLinkContext();
        NSLog(@"Focused unit harness passed");
    }
    return 0;
}
