#import "MGKeyboardShortcut.h"
#import <Carbon/Carbon.h>
#import <IOKit/hidsystem/IOLLEvent.h>

typedef struct {
    CGEventFlags mask;
    CGEventFlags deviceMask;
    CGKeyCode keyCode;
} MGModifierKey;

static const MGModifierKey kMGModifierKeys[] = {
    { kCGEventFlagMaskControl,   NX_DEVICELCTLKEYMASK,   kVK_Control },
    { kCGEventFlagMaskAlternate, NX_DEVICELALTKEYMASK,   kVK_Option },
    { kCGEventFlagMaskShift,     NX_DEVICELSHIFTKEYMASK, kVK_Shift },
    { kCGEventFlagMaskCommand,   NX_DEVICELCMDKEYMASK,   kVK_Command },
};

static BOOL MGIsModifierKeyCode(CGKeyCode keyCode) {
    switch (keyCode) {
        case kVK_Command:
        case kVK_RightCommand:
        case kVK_Option:
        case kVK_RightOption:
        case kVK_Shift:
        case kVK_RightShift:
        case kVK_Control:
        case kVK_RightControl:
        case kVK_Function:
        case kVK_CapsLock:
            return YES;
        default:
            return NO;
    }
}

void MGConfigureShortcutEvent(CGEventRef event, CGEventSourceRef source, CGKeyCode keyCode, CGEventFlags flags) {
    CGEventSetFlags(event, flags);
    if (MGIsModifierKeyCode(keyCode) || event == NULL || source == NULL) {
        return;
    }
    // Option remaps C to ç. Command shortcuts must keep the unmodified
    // character so the key equivalent stays "c", not "ç".
    CGEventRef probe = CGEventCreateKeyboardEvent(source, keyCode, true);
    if (probe == NULL) {
        return;
    }
    CGEventSetFlags(probe, flags & ~(kCGEventFlagMaskAlternate | NX_DEVICELALTKEYMASK | NX_DEVICERALTKEYMASK));
    UniChar buf[8];
    UniCharCount length = 0;
    CGEventKeyboardGetUnicodeString(probe, 8, &length, buf);
    CFRelease(probe);
    if (length > 0) {
        CGEventKeyboardSetUnicodeString(event, length, buf);
    }
}

NSUInteger MGKeyStrokesForShortcut(CGKeyCode keyCode,
                                   CGEventFlags storedFlags,
                                   MGKeyStroke *outStrokes,
                                   NSUInteger capacity) {
    if (outStrokes == NULL || capacity == 0) {
        return 0;
    }

    const MGModifierKey *active[4];
    NSUInteger modifierCount = 0;
    NSUInteger modifierKeyCount = sizeof(kMGModifierKeys) / sizeof(kMGModifierKeys[0]);
    for (NSUInteger i = 0; i < modifierKeyCount; i++) {
        if (storedFlags & kMGModifierKeys[i].mask) {
            active[modifierCount++] = &kMGModifierKeys[i];
        }
    }

    NSUInteger needed = modifierCount * 2 + 2;
    if (capacity < needed) {
        return 0;
    }

    CGEventFlags sticky = (storedFlags & kCGEventFlagMaskSecondaryFn) | kCGEventFlagMaskNonCoalesced;
    CGEventFlags running = sticky;
    NSUInteger n = 0;

    for (NSUInteger i = 0; i < modifierCount; i++) {
        running |= active[i]->mask | active[i]->deviceMask;
        outStrokes[n++] = (MGKeyStroke){ active[i]->keyCode, YES, running };
    }

    outStrokes[n++] = (MGKeyStroke){ keyCode, YES, running };
    outStrokes[n++] = (MGKeyStroke){ keyCode, NO, running };

    for (NSInteger i = (NSInteger)modifierCount - 1; i >= 0; i--) {
        running &= ~(active[i]->mask | active[i]->deviceMask);
        running |= sticky;
        outStrokes[n++] = (MGKeyStroke){ active[i]->keyCode, NO, running };
    }

    return n;
}

void MGPostKeyboardShortcut(CGKeyCode keyCode, CGEventFlags storedFlags) {
    MGKeyStroke strokes[MG_MAX_KEY_STROKES];
    NSUInteger count = MGKeyStrokesForShortcut(keyCode, storedFlags, strokes, MG_MAX_KEY_STROKES);
    if (count == 0) {
        return;
    }

    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (source == NULL) {
        return;
    }

    for (NSUInteger i = 0; i < count; i++) {
        CGEventRef event = CGEventCreateKeyboardEvent(source, strokes[i].keyCode, strokes[i].keyDown);
        if (event == NULL) {
            continue;
        }
        MGConfigureShortcutEvent(event, source, strokes[i].keyCode, strokes[i].flags);
        CGEventPost(kCGHIDEventTap, event);
        CFRelease(event);
    }

    CFRelease(source);
}
