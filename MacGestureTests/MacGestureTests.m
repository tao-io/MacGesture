#import <XCTest/XCTest.h>
#import <Carbon/Carbon.h>
#import <IOKit/hidsystem/IOLLEvent.h>
#import "MGGestureEventRouter.h"
#import "MGKeyboardShortcut.h"

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

- (void)testOptionCommandCPostsModifierKeyDownsBeforeC {
    CGEventFlags stored = kCGEventFlagMaskAlternate | kCGEventFlagMaskCommand;
    MGKeyStroke strokes[MG_MAX_KEY_STROKES];
    NSUInteger count = MGKeyStrokesForShortcut(kVK_ANSI_C, stored, strokes, MG_MAX_KEY_STROKES);

    XCTAssertEqual(count, (NSUInteger)6);
    XCTAssertEqual(strokes[0].keyCode, (CGKeyCode)kVK_Option);
    XCTAssertTrue(strokes[0].keyDown);
    XCTAssertTrue((strokes[0].flags & kCGEventFlagMaskAlternate) != 0);

    XCTAssertEqual(strokes[1].keyCode, (CGKeyCode)kVK_Command);
    XCTAssertTrue(strokes[1].keyDown);
    XCTAssertTrue((strokes[1].flags & kCGEventFlagMaskAlternate) != 0);
    XCTAssertTrue((strokes[1].flags & kCGEventFlagMaskCommand) != 0);

    XCTAssertEqual(strokes[2].keyCode, (CGKeyCode)kVK_ANSI_C);
    XCTAssertTrue(strokes[2].keyDown);
    XCTAssertTrue((strokes[2].flags & kCGEventFlagMaskAlternate) != 0);
    XCTAssertTrue((strokes[2].flags & kCGEventFlagMaskCommand) != 0);
    XCTAssertTrue((strokes[2].flags & NX_DEVICELALTKEYMASK) != 0);
    XCTAssertTrue((strokes[2].flags & NX_DEVICELCMDKEYMASK) != 0);

    XCTAssertEqual(strokes[3].keyCode, (CGKeyCode)kVK_ANSI_C);
    XCTAssertFalse(strokes[3].keyDown);

    XCTAssertEqual(strokes[4].keyCode, (CGKeyCode)kVK_Command);
    XCTAssertFalse(strokes[4].keyDown);
    XCTAssertEqual(strokes[5].keyCode, (CGKeyCode)kVK_Option);
    XCTAssertFalse(strokes[5].keyDown);
}

- (void)testPlainKeyIsOnlyDownAndUp {
    MGKeyStroke strokes[MG_MAX_KEY_STROKES];
    NSUInteger count = MGKeyStrokesForShortcut(kVK_ANSI_C, 0, strokes, MG_MAX_KEY_STROKES);
    XCTAssertEqual(count, (NSUInteger)2);
    XCTAssertEqual(strokes[0].keyCode, (CGKeyCode)kVK_ANSI_C);
    XCTAssertTrue(strokes[0].keyDown);
    XCTAssertEqual(strokes[1].keyCode, (CGKeyCode)kVK_ANSI_C);
    XCTAssertFalse(strokes[1].keyDown);
}

- (void)testOptionCommandDoesNotRemapCToCedilla {
    CGEventFlags stored = kCGEventFlagMaskAlternate | kCGEventFlagMaskCommand;
    MGKeyStroke strokes[MG_MAX_KEY_STROKES];
    NSUInteger count = MGKeyStrokesForShortcut(kVK_ANSI_C, stored, strokes, MG_MAX_KEY_STROKES);
    XCTAssertGreaterThanOrEqual(count, (NSUInteger)4);

    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
    XCTAssertNotEqual(source, NULL);
    CGEventRef event = CGEventCreateKeyboardEvent(source, kVK_ANSI_C, true);
    XCTAssertNotEqual(event, NULL);
    MGConfigureShortcutEvent(event, source, kVK_ANSI_C, strokes[2].flags);

    UniChar buf[8] = {0};
    UniCharCount length = 0;
    CGEventKeyboardGetUnicodeString(event, 8, &length, buf);
    XCTAssertGreaterThan(length, (UniCharCount)0);
    XCTAssertNotEqual(buf[0], (UniChar)0x00e7);

    CFRelease(event);
    CFRelease(source);
}

@end
