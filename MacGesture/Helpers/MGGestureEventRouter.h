#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Event types the mouse tap must subscribe to.
/// Includes left-drag so a right-button session can keep recording
/// direction after the left button joins the chord (macOS then emits
/// `kCGEventLeftMouseDragged` instead of `kCGEventRightMouseDragged`).
/// Includes left-up so physical left-button state can be cleared even
/// when no right-button session has started yet.
CGEventMask MGGestureEventTapMask(void);

/// A right-button gesture session is active when the tap has claimed
/// a right-mouse-down (`shouldShow`) and still holds that down event.
BOOL MGGestureSessionIsActive(BOOL shouldShow, BOOL hasRightMouseDown);

/// Left-drag updates the gesture only while a right-button session is active.
/// Ordinary left-drag must pass through unchanged.
BOOL MGShouldUpdateGestureFromLeftMouseDrag(BOOL shouldShow, BOOL hasRightMouseDown);

/// Physical left-button state, independent of a right-button session.
/// `chordZRecorded` prevents a left-first seed and a later left-down
/// in the same session from both appending `Z`.
typedef struct {
    BOOL leftButtonDown;
    BOOL chordZRecorded;
} MGLeftChordState;

/// Record a physical left-button down or up. Up also forgets a pending
/// chord `Z` so a later right-only gesture cannot inherit one.
void MGLeftChordSetButtonDown(MGLeftChordState *state, BOOL isDown);

/// Record at most one `Z` for the current left-down while a right session
/// is starting or already active. Returns YES when a `Z` should be appended.
BOOL MGLeftChordConsumeZ(MGLeftChordState *state);

/// Forget a session-scoped `Z` so the next right session can seed again
/// if the left button is still held.
void MGLeftChordClearSession(MGLeftChordState *state);

/// Returns 0 when the movement is shorter than `threshold`.
unichar MGDirectionForMovement(double deltaX, double deltaY, double threshold);

/// Appends `dir` when it is a new direction, or when repeats are allowed.
/// Returns YES if `gesture` changed.
BOOL MGAppendGestureCharacter(NSMutableString *gesture, unichar dir, BOOL allowSameDirection);

NS_ASSUME_NONNULL_END
