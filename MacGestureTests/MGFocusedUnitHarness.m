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
