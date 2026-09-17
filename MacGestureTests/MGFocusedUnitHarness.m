#import <Cocoa/Cocoa.h>
#import "MGLinkGestureContext.h"
#import "MGLinkActionExecutor.h"
#import "../MacGesture/Models/RulesList.h"

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

    NSString *javascript = MGArcHoveredLinkJavaScript();
    NSCAssert([javascript containsString:@"document.querySelectorAll(':hover')"],
        @"Arc must query the hover chain");
    NSCAssert([javascript containsString:@"elements.length-1"]
        && [javascript containsString:@"closest('a[href]')"],
        @"Arc must search the deepest hovered anchor first");
    NSString *source = MGArcAppleScriptSourceForJavaScript(
        @"const value = \"a\\b\";\nreturn value;");
    NSCAssert([source containsString:@"const value = \\\"a\\\\b\\\";\\nreturn value;"],
        @"JavaScript must be escaped inside the AppleScript string");

    __block NSUInteger accessibilityCalls = 0;
    NSURL *arcURL = MGResolveLinkURLAtPoint(CGPointZero, MGArcBrowserBundleIdentifier,
        ^NSString *(NSString *scriptSource, NSError **error) {
            return @"https://example.com/hovered";
        }, ^NSURL *(CGPoint point) {
            accessibilityCalls++;
            return [NSURL URLWithString:@"https://example.com/accessibility"];
        });
    NSCAssert([arcURL.absoluteString isEqualToString:@"https://example.com/hovered"]
        && accessibilityCalls == 0, @"A valid Arc result must win");

    NSArray<MGArcScriptExecutor> *failedExecutors = @[
        ^NSString *(NSString *scriptSource, NSError **error) { return @""; },
        ^NSString *(NSString *scriptSource, NSError **error) { return @"not a URL"; },
        ^NSString *(NSString *scriptSource, NSError **error) {
            if (error != NULL) *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
            return @"https://example.com/ignored-because-of-error";
        },
    ];
    for (MGArcScriptExecutor executor in failedExecutors) {
        accessibilityCalls = 0;
        NSURL *fallbackURL = MGResolveLinkURLAtPoint(CGPointZero, MGArcBrowserBundleIdentifier,
            executor, ^NSURL *(CGPoint point) {
                accessibilityCalls++;
                return [NSURL URLWithString:@"https://example.com/accessibility"];
            });
        NSCAssert(accessibilityCalls == 1
            && [fallbackURL.absoluteString isEqualToString:@"https://example.com/accessibility"],
            @"Arc failure must fall back to Accessibility");
    }

    __block NSUInteger scriptCalls = 0;
    NSURL *nonArcURL = MGResolveLinkURLAtPoint(CGPointZero, @"com.apple.Safari",
        ^NSString *(NSString *scriptSource, NSError **error) {
            scriptCalls++;
            return @"https://example.com/arc";
        }, ^NSURL *(CGPoint point) {
            return [NSURL URLWithString:@"https://example.com/accessibility"];
        });
    NSCAssert(scriptCalls == 0
        && [nonArcURL.absoluteString isEqualToString:@"https://example.com/accessibility"],
        @"Non-Arc apps must use Accessibility directly");

    MGLinkGestureContext *context = [MGLinkGestureContext new];
    NSURL *initialURL = arcURL;
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

static void TestRulesAndActions(void) {
    NSDictionary *oldRule = @{
        @"direction": @"L", @"filter": @"*", @"filterType": @(FILTER_TYPE_WILDCARD),
        @"actionType": @(ACTION_TYPE_SHORTCUT), @"enabled": @YES,
    };
    NSData *oldData = [NSKeyedArchiver archivedDataWithRootObject:@[ oldRule ]];
    RulesList *importedRules = [[RulesList alloc] initWithNsData:oldData];
    NSCAssert([importedRules contextScopeAtIndex:0] == CONTEXT_SCOPE_ANY,
        @"An old archived rule must default to any context");

    RulesList *rules = [RulesList new];
    [rules addRuleWithDirection:@"R" filter:@"*" filterType:FILTER_TYPE_WILDCARD
        contextScope:CONTEXT_SCOPE_LINK actionType:ACTION_TYPE_COPY_LINK_URL
        shortcutKeyCode:0 shortcutFlag:0 appleScriptId:nil note:@"link"];
    [rules addRuleWithDirection:@"R" filter:@"*" filterType:FILTER_TYPE_WILDCARD
        actionType:ACTION_TYPE_SHORTCUT shortcutKeyCode:0 shortcutFlag:0
        appleScriptId:nil note:@"fallback"];
    NSCAssert([rules suitedRuleWithGesture:@"R" frontBundle:@"browser" linkURL:nil
        isLastGesture:YES] == 1, @"No URL must skip the link rule");
    NSCAssert([rules suitedRuleWithGesture:@"R" frontBundle:@"browser"
        linkURL:[NSURL URLWithString:@"https://example.com"] isLastGesture:YES] == 0,
        @"A URL must make the first link rule applicable");

    NSMutableArray<NSString *> *calls = [NSMutableArray array];
    MGLinkActionExecutor *executor = [[MGLinkActionExecutor alloc]
        initWithCopyHandler:^BOOL(NSString *value) {
            [calls addObject:[@"copy:" stringByAppendingString:value]]; return YES;
        } openHandler:^BOOL(NSURL *url) {
            [calls addObject:[@"open:" stringByAppendingString:url.absoluteString]]; return YES;
        } newWindowHandler:^BOOL(NSURL *url, NSString *bundleIdentifier) {
            (void)bundleIdentifier;
            [calls addObject:[@"new:" stringByAppendingString:url.absoluteString]]; return YES;
        }];
    NSURL *url = [NSURL URLWithString:@"https://example.com/link"];
    NSCAssert([executor performAction:MGLinkURLActionCopy URL:url sourceBundleIdentifier:@"browser"], @"Copy failed");
    NSCAssert([executor performAction:MGLinkURLActionOpen URL:url sourceBundleIdentifier:@"browser"], @"Open failed");
    NSCAssert([executor performAction:MGLinkURLActionOpenInNewWindow URL:url sourceBundleIdentifier:@"browser"], @"New window failed");
    NSCAssert(calls.count == 3, @"All URL actions must dispatch once");
}

int main(void) {
    @autoreleasepool {
        TestLinkContext();
        TestRulesAndActions();
        NSLog(@"Focused unit harness passed");
    }
    return 0;
}
