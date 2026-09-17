#import <XCTest/XCTest.h>
#import "MGGestureEventRouter.h"

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

@end
