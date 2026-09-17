#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Event types the mouse tap must subscribe to.
/// Includes left-drag so a right-button session can keep recording
/// direction after the left button joins the chord (macOS then emits
/// `kCGEventLeftMouseDragged` instead of `kCGEventRightMouseDragged`).
CGEventMask MGGestureEventTapMask(void);

/// A right-button gesture session is active when the tap has claimed
/// a right-mouse-down (`shouldShow`) and still holds that down event.
BOOL MGGestureSessionIsActive(BOOL shouldShow, BOOL hasRightMouseDown);

/// Left-drag updates the gesture only while a right-button session is active.
/// Ordinary left-drag must pass through unchanged.
BOOL MGShouldUpdateGestureFromLeftMouseDrag(BOOL shouldShow, BOOL hasRightMouseDown);

/// Returns 0 when the movement is shorter than `threshold`.
unichar MGDirectionForMovement(double deltaX, double deltaY, double threshold);

/// Appends `dir` when it is a new direction, or when repeats are allowed.
/// Returns YES if `gesture` changed.
BOOL MGAppendGestureCharacter(NSMutableString *gesture, unichar dir, BOOL allowSameDirection);

NS_ASSUME_NONNULL_END
