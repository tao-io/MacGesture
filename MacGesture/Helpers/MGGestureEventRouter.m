#import "MGGestureEventRouter.h"
#include <math.h>

CGEventMask MGGestureEventTapMask(void) {
    return CGEventMaskBit(kCGEventRightMouseDown)
        | CGEventMaskBit(kCGEventRightMouseDragged)
        | CGEventMaskBit(kCGEventRightMouseUp)
        | CGEventMaskBit(kCGEventLeftMouseDown)
        | CGEventMaskBit(kCGEventLeftMouseDragged)
        | CGEventMaskBit(kCGEventScrollWheel);
}

BOOL MGGestureSessionIsActive(BOOL shouldShow, BOOL hasRightMouseDown) {
    return shouldShow && hasRightMouseDown;
}

BOOL MGShouldUpdateGestureFromLeftMouseDrag(BOOL shouldShow, BOOL hasRightMouseDown) {
    return MGGestureSessionIsActive(shouldShow, hasRightMouseDown);
}

unichar MGDirectionForMovement(double deltaX, double deltaY, double threshold) {
    double absX = fabs(deltaX);
    double absY = fabs(deltaY);
    if (absX + absY < threshold) {
        return 0;
    }
    if (absX > absY) {
        return deltaX > 0 ? 'R' : 'L';
    }
    return deltaY > 0 ? 'U' : 'D';
}

BOOL MGAppendGestureCharacter(NSMutableString *gesture, unichar dir, BOOL allowSameDirection) {
    if (dir == 0 || gesture == nil) {
        return NO;
    }
    unichar lastDirectionChar = gesture.length > 0
        ? [gesture characterAtIndex:gesture.length - 1]
        : ' ';
    if (dir != lastDirectionChar || allowSameDirection) {
        [gesture appendString:[NSString stringWithCharacters:&dir length:1]];
        return YES;
    }
    return NO;
}
