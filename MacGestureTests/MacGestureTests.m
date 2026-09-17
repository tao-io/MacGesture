#import <XCTest/XCTest.h>
#import "MGGestureEventRouter.h"

@interface MacGestureTests : XCTestCase
@end

@implementation MacGestureTests

- (void)testEventTapMaskIncludesLeftMouseDraggedAndExistingEvents {
    CGEventMask mask = MGGestureEventTapMask();
    XCTAssertTrue((mask & CGEventMaskBit(kCGEventRightMouseDown)) != 0);
    XCTAssertTrue((mask & CGEventMaskBit(kCGEventRightMouseDragged)) != 0);
    XCTAssertTrue((mask & CGEventMaskBit(kCGEventRightMouseUp)) != 0);
    XCTAssertTrue((mask & CGEventMaskBit(kCGEventLeftMouseDown)) != 0);
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
