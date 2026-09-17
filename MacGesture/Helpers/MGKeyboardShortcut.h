#import <CoreGraphics/CoreGraphics.h>
#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define MG_MAX_KEY_STROKES 16

typedef struct {
    CGKeyCode keyCode;
    BOOL keyDown;
    CGEventFlags flags;
} MGKeyStroke;

/// Builds the hardware-like sequence for a stored ShortcutRecorder shortcut:
/// modifier key-downs (flagsChanged), the key, then modifier key-ups.
/// Chromium/Arc tracks modifiers from those flagsChanged events; posting
/// only the letter with `CGEventSetFlags` is not enough for Option+Command.
NSUInteger MGKeyStrokesForShortcut(CGKeyCode keyCode,
                                   CGEventFlags storedFlags,
                                   MGKeyStroke *outStrokes,
                                   NSUInteger capacity);

void MGConfigureShortcutEvent(CGEventRef _Nullable event,
                              CGEventSourceRef _Nullable source,
                              CGKeyCode keyCode,
                              CGEventFlags flags);

void MGPostKeyboardShortcut(CGKeyCode keyCode, CGEventFlags storedFlags);

NS_ASSUME_NONNULL_END
