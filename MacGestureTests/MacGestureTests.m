#import <XCTest/XCTest.h>
#import "MGGestureEventRouter.h"
#import "MGLinkGestureContext.h"
#import "MGLinkActionExecutor.h"
#import "../MacGesture/Models/RulesList.h"

@interface MacGestureTests : XCTestCase
@end

static NSString *MGGestureFromTapEvents(const CGEventType *events, NSUInteger count) {
    MGLeftChordState chord = {0};
    BOOL sessionActive = NO;
    NSMutableString *gesture = [NSMutableString string];
    const double threshold = 20;
    for (NSUInteger i = 0; i < count; i++) {
        switch (events[i]) {
            case kCGEventLeftMouseDown:
                MGLeftChordSetButtonDown(&chord, YES);
                if (sessionActive && MGLeftChordConsumeZ(&chord)) {
                    MGAppendGestureCharacter(gesture, 'Z', YES);
                }
                break;
            case kCGEventLeftMouseUp:
                MGLeftChordSetButtonDown(&chord, NO);
                break;
            case kCGEventRightMouseDown:
                sessionActive = YES;
                if (MGLeftChordConsumeZ(&chord)) {
                    MGAppendGestureCharacter(gesture, 'Z', YES);
                }
                break;
            case kCGEventRightMouseUp:
                sessionActive = NO;
                MGLeftChordClearSession(&chord);
                break;
            case kCGEventLeftMouseDragged:
                if (!MGShouldUpdateGestureFromLeftMouseDrag(sessionActive, sessionActive)) {
                    break;
                }
                MGAppendGestureCharacter(gesture, MGDirectionForMovement(0, 40, threshold), NO);
                break;
            case kCGEventRightMouseDragged:
                if (!sessionActive) {
                    break;
                }
                MGAppendGestureCharacter(gesture, MGDirectionForMovement(0, 40, threshold), NO);
                break;
            default:
                break;
        }
    }
    return [gesture copy];
}

@implementation MacGestureTests

- (void)testEventTapMaskIncludesLeftMouseDraggedAndExistingEvents {
    CGEventMask mask = MGGestureEventTapMask();
    XCTAssertTrue((mask & CGEventMaskBit(kCGEventRightMouseDown)) != 0);
    XCTAssertTrue((mask & CGEventMaskBit(kCGEventRightMouseDragged)) != 0);
    XCTAssertTrue((mask & CGEventMaskBit(kCGEventRightMouseUp)) != 0);
    XCTAssertTrue((mask & CGEventMaskBit(kCGEventLeftMouseDown)) != 0);
    XCTAssertTrue((mask & CGEventMaskBit(kCGEventLeftMouseUp)) != 0);
    XCTAssertTrue((mask & CGEventMaskBit(kCGEventLeftMouseDragged)) != 0);
    XCTAssertTrue((mask & CGEventMaskBit(kCGEventScrollWheel)) != 0);
}

- (void)testOrdinaryLeftDragDoesNotUpdateGesture {
    XCTAssertFalse(MGShouldUpdateGestureFromLeftMouseDrag(NO, NO));
    XCTAssertFalse(MGShouldUpdateGestureFromLeftMouseDrag(NO, YES));
    XCTAssertFalse(MGShouldUpdateGestureFromLeftMouseDrag(YES, NO));
}

- (void)testLeftDragUpdatesGestureOnlyWhileRightButtonSessionIsActive {
    XCTAssertTrue(MGShouldUpdateGestureFromLeftMouseDrag(YES, YES));
}

- (void)testChordThenUpwardLeftDragProducesZU {
    NSMutableString *gesture = [NSMutableString string];
    XCTAssertTrue(MGAppendGestureCharacter(gesture, 'Z', YES));
    XCTAssertEqualObjects(gesture, @"Z");

    unichar dir = MGDirectionForMovement(0, 40, 20);
    XCTAssertEqual(dir, (unichar)'U');
    XCTAssertTrue(MGAppendGestureCharacter(gesture, dir, NO));
    XCTAssertEqualObjects(gesture, @"ZU");
}

- (void)testLeftFirstChordThenUpwardDragProducesZU {
    const CGEventType events[] = {
        kCGEventLeftMouseDown,
        kCGEventRightMouseDown,
        kCGEventLeftMouseDragged,
    };
    XCTAssertEqualObjects(MGGestureFromTapEvents(events, 3), @"ZU");
}

- (void)testRightFirstChordThenUpwardDragProducesZU {
    const CGEventType events[] = {
        kCGEventRightMouseDown,
        kCGEventLeftMouseDown,
        kCGEventLeftMouseDragged,
    };
    XCTAssertEqualObjects(MGGestureFromTapEvents(events, 3), @"ZU");
}

- (void)testLeftFirstChordSeedsOnlyOneZ {
    const CGEventType events[] = {
        kCGEventLeftMouseDown,
        kCGEventRightMouseDown,
        kCGEventLeftMouseDown,
        kCGEventLeftMouseDragged,
    };
    XCTAssertEqualObjects(MGGestureFromTapEvents(events, 4), @"ZU");
}

- (void)testLeftUpClearsChordSoLaterRightOnlyGestureHasNoZ {
    const CGEventType events[] = {
        kCGEventLeftMouseDown,
        kCGEventLeftMouseUp,
        kCGEventRightMouseDown,
        kCGEventRightMouseDragged,
    };
    XCTAssertEqualObjects(MGGestureFromTapEvents(events, 4), @"U");
}

- (void)testShortMovementDoesNotAppendDirection {
    XCTAssertEqual(MGDirectionForMovement(3, 4, 20), (unichar)0);
    NSMutableString *gesture = [NSMutableString stringWithString:@"Z"];
    XCTAssertFalse(MGAppendGestureCharacter(gesture, 0, NO));
    XCTAssertEqualObjects(gesture, @"Z");
}

- (void)testRepeatedDirectionIsIgnoredUnlessAllowed {
    NSMutableString *gesture = [NSMutableString stringWithString:@"U"];
    XCTAssertFalse(MGAppendGestureCharacter(gesture, 'U', NO));
    XCTAssertEqualObjects(gesture, @"U");
    XCTAssertTrue(MGAppendGestureCharacter(gesture, 'U', YES));
    XCTAssertEqualObjects(gesture, @"UU");
}

- (void)testNestedAccessibilityChildResolvesParentLinkURL {
    NSDictionary *link = @{ @"role": @"AXLink", @"url": @"https://example.com/path" };
    NSDictionary *child = @{ @"role": @"AXStaticText", @"parent": link };

    NSURL *url = MGLinkURLFromAccessibilityElement(child, ^id(NSDictionary *element, NSString *attribute) {
        return element[attribute];
    });

    XCTAssertEqualObjects(url.absoluteString, @"https://example.com/path");
}

- (void)testNonLinkAccessibilityElementHasNoURL {
    NSDictionary *element = @{ @"role": @"AXButton", @"url": @"https://example.com/not-a-link" };

    NSURL *url = MGLinkURLFromAccessibilityElement(element, ^id(NSDictionary *item, NSString *attribute) {
        return item[attribute];
    });

    XCTAssertNil(url);
}

- (void)testArcHoveredLinkJavaScriptSearchesDeepestFirstAndAppleScriptEscapesIt {
    NSString *javascript = MGArcHoveredLinkJavaScript();
    XCTAssertTrue([javascript containsString:@"document.querySelectorAll(':hover')"]);
    XCTAssertTrue([javascript containsString:@"elements.length-1"]);
    XCTAssertTrue([javascript containsString:@"closest('a[href]')"]);
    XCTAssertTrue([javascript containsString:@"link.href"]);
    XCTAssertTrue([javascript containsString:@"return ''"]);

    NSString *source = MGArcAppleScriptSourceForJavaScript(
        @"const value = \"a\\b\";\nreturn value;");
    XCTAssertTrue([source containsString:@"tell application id \"company.thebrowser.Browser\""]);
    XCTAssertTrue([source containsString:@"execute active tab of front window javascript"]);
    XCTAssertTrue([source containsString:@"const value = \\\"a\\\\b\\\";\\nreturn value;"]);
}

- (void)testValidArcResultBecomesFrozenLinkContext {
    __block NSUInteger accessibilityCalls = 0;
    NSURL *url = MGResolveLinkURLAtPoint(CGPointZero, MGArcBrowserBundleIdentifier,
        ^NSString *(NSString *source, NSError **error) {
            XCTAssertTrue([source containsString:@"querySelectorAll"]);
            return @"https://example.com/hovered";
        }, ^NSURL *(CGPoint point) {
            accessibilityCalls++;
            return [NSURL URLWithString:@"https://example.com/accessibility"];
        });

    MGLinkGestureContext *context = [MGLinkGestureContext new];
    [context beginWithLinkURL:url];
    [context beginWithLinkURL:[NSURL URLWithString:@"https://example.com/moved"]];

    XCTAssertEqual(accessibilityCalls, (NSUInteger)0);
    XCTAssertEqualObjects(context.linkURL.absoluteString, @"https://example.com/hovered");
}

- (void)testEmptyInvalidAndErrorArcResultsFallBackToAccessibility {
    NSArray<MGArcScriptExecutor> *executors = @[
        ^NSString *(NSString *source, NSError **error) { return @""; },
        ^NSString *(NSString *source, NSError **error) { return @"not a URL"; },
        ^NSString *(NSString *source, NSError **error) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
            }
            return @"https://example.com/ignored-because-of-error";
        },
    ];

    for (MGArcScriptExecutor executor in executors) {
        __block NSUInteger accessibilityCalls = 0;
        NSURL *url = MGResolveLinkURLAtPoint(CGPointZero, MGArcBrowserBundleIdentifier,
            executor, ^NSURL *(CGPoint point) {
                accessibilityCalls++;
                return [NSURL URLWithString:@"https://example.com/accessibility"];
            });
        XCTAssertEqual(accessibilityCalls, (NSUInteger)1);
        XCTAssertEqualObjects(url.absoluteString, @"https://example.com/accessibility");
    }
}

- (void)testNonArcApplicationUsesAccessibilityWithoutRunningScript {
    __block NSUInteger scriptCalls = 0;
    __block NSUInteger accessibilityCalls = 0;
    NSURL *url = MGResolveLinkURLAtPoint(CGPointZero, @"com.apple.Safari",
        ^NSString *(NSString *source, NSError **error) {
            scriptCalls++;
            return @"https://example.com/arc";
        }, ^NSURL *(CGPoint point) {
            accessibilityCalls++;
            return [NSURL URLWithString:@"https://example.com/accessibility"];
        });

    XCTAssertEqual(scriptCalls, (NSUInteger)0);
    XCTAssertEqual(accessibilityCalls, (NSUInteger)1);
    XCTAssertEqualObjects(url.absoluteString, @"https://example.com/accessibility");
}

- (void)testGestureContextFreezesInitialLinkUntilCleared {
    MGLinkGestureContext *context = [MGLinkGestureContext new];
    NSURL *initialURL = [NSURL URLWithString:@"https://example.com/initial"];

    [context beginWithLinkURL:initialURL];
    [context beginWithLinkURL:[NSURL URLWithString:@"https://example.com/moved"]];

    XCTAssertEqualObjects(context.linkURL, initialURL);
}

- (void)testGestureContextClearsLinkAndAcceptsNextSession {
    MGLinkGestureContext *context = [MGLinkGestureContext new];
    [context beginWithLinkURL:[NSURL URLWithString:@"https://example.com/first"]];
    [context clear];

    XCTAssertNil(context.linkURL);

    NSURL *nextURL = [NSURL URLWithString:@"https://example.com/next"];
    [context beginWithLinkURL:nextURL];
    XCTAssertEqualObjects(context.linkURL, nextURL);
}

- (void)testGestureContextFreezesMissingInitialLink {
    MGLinkGestureContext *context = [MGLinkGestureContext new];
    [context beginWithLinkURL:nil];
    [context beginWithLinkURL:[NSURL URLWithString:@"https://example.com/moved"]];

    XCTAssertTrue(context.isActive);
    XCTAssertNil(context.linkURL);
}

- (void)testOldRuleDefaultsToAnyContext {
    RulesList *rules = [RulesList new];
    [rules addRuleWithDirection:@"R" filter:@"*" filterType:FILTER_TYPE_WILDCARD
        actionType:ACTION_TYPE_SHORTCUT shortcutKeyCode:0 shortcutFlag:0
        appleScriptId:nil note:@"fallback"];

    XCTAssertEqual([rules contextScopeAtIndex:0], CONTEXT_SCOPE_ANY);
    XCTAssertEqual([rules suitedRuleWithGesture:@"R" frontBundle:@"com.example.browser"
        linkURL:nil isLastGesture:YES], 0);
}

- (void)testArchivedRuleWithoutContextScopeImportsAsAny {
    NSMutableDictionary *oldRule = [@{
        @"direction": @"R", @"filter": @"*", @"filterType": @(FILTER_TYPE_WILDCARD),
        @"actionType": @(ACTION_TYPE_SHORTCUT), @"shortcut_code": @0,
        @"shortcut_flag": @0, @"note": @"old", @"enabled": @YES,
    } mutableCopy];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:
        [NSMutableArray arrayWithObject:oldRule]];

    RulesList *rules = [[RulesList alloc] initWithNsData:data];

    XCTAssertEqual([rules contextScopeAtIndex:0], CONTEXT_SCOPE_ANY);
    XCTAssertNotNil(rules.nsData);
}

- (void)testMissingLinkSkipsLinkRuleAndUsesNormalFallback {
    RulesList *rules = [RulesList new];
    [rules addRuleWithDirection:@"R" filter:@"*" filterType:FILTER_TYPE_WILDCARD
        contextScope:CONTEXT_SCOPE_LINK actionType:ACTION_TYPE_COPY_LINK_URL
        shortcutKeyCode:0 shortcutFlag:0 appleScriptId:nil note:@"copy link"];
    [rules addRuleWithDirection:@"R" filter:@"*" filterType:FILTER_TYPE_WILDCARD
        actionType:ACTION_TYPE_SHORTCUT shortcutKeyCode:0 shortcutFlag:0
        appleScriptId:nil note:@"fallback"];

    XCTAssertEqual([rules suitedRuleWithGesture:@"R" frontBundle:@"com.example.browser"
        linkURL:nil isLastGesture:YES], 1);
}

- (void)testFrozenLinkMakesLinkRuleFirstApplicableRule {
    RulesList *rules = [RulesList new];
    [rules addRuleWithDirection:@"R" filter:@"*" filterType:FILTER_TYPE_WILDCARD
        contextScope:CONTEXT_SCOPE_LINK actionType:ACTION_TYPE_COPY_LINK_URL
        shortcutKeyCode:0 shortcutFlag:0 appleScriptId:nil note:@"copy link"];
    [rules addRuleWithDirection:@"R" filter:@"*" filterType:FILTER_TYPE_WILDCARD
        actionType:ACTION_TYPE_SHORTCUT shortcutKeyCode:0 shortcutFlag:0
        appleScriptId:nil note:@"fallback"];

    XCTAssertEqual([rules suitedRuleWithGesture:@"R" frontBundle:@"com.example.browser"
        linkURL:[NSURL URLWithString:@"https://example.com/link"] isLastGesture:YES], 0);
}

- (void)testThreeLinkActionsDispatchFrozenAbsoluteURL {
    NSMutableArray<NSString *> *calls = [NSMutableArray array];
    MGLinkActionExecutor *executor = [[MGLinkActionExecutor alloc]
        initWithCopyHandler:^BOOL(NSString *value) {
            [calls addObject:[@"copy:" stringByAppendingString:value]];
            return YES;
        } openHandler:^BOOL(NSURL *url) {
            [calls addObject:[@"open:" stringByAppendingString:url.absoluteString]];
            return YES;
        } newWindowHandler:^BOOL(NSURL *url, NSString *bundleIdentifier) {
            [calls addObject:[NSString stringWithFormat:@"new:%@:%@", bundleIdentifier,
                url.absoluteString]];
            return YES;
        }];
    NSURL *url = [NSURL URLWithString:@"https://example.com/a?b=c"];

    XCTAssertTrue([executor performAction:MGLinkURLActionCopy URL:url sourceBundleIdentifier:@"browser"]);
    XCTAssertTrue([executor performAction:MGLinkURLActionOpen URL:url sourceBundleIdentifier:@"browser"]);
    XCTAssertTrue([executor performAction:MGLinkURLActionOpenInNewWindow URL:url sourceBundleIdentifier:@"browser"]);
    XCTAssertEqualObjects(calls, (@[
        @"copy:https://example.com/a?b=c",
        @"open:https://example.com/a?b=c",
        @"new:browser:https://example.com/a?b=c",
    ]));
}

- (void)testNewWindowFallsBackToNormalOpenOutsideArc {
    __block NSUInteger openCount = 0;
    MGLinkActionExecutor *executor = [[MGLinkActionExecutor alloc]
        initWithCopyHandler:^BOOL(NSString *value) { return YES; }
        openHandler:^BOOL(NSURL *url) { openCount++; return YES; }
        newWindowHandler:^BOOL(NSURL *url, NSString *bundleIdentifier) { return NO; }];

    XCTAssertTrue([executor performAction:MGLinkURLActionOpenInNewWindow
        URL:[NSURL URLWithString:@"https://example.com"]
        sourceBundleIdentifier:@"com.apple.Safari"]);
    XCTAssertEqual(openCount, (NSUInteger)1);
}

@end
