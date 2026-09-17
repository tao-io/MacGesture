#import "MGLinkActionExecutor.h"
#import <Cocoa/Cocoa.h>

static NSString *const MGArcBundleIdentifier = @"company.thebrowser.Browser";

static NSString *MGAppleScriptQuotedString(NSString *value) {
    NSString *escaped = [value stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    return [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
}

static BOOL MGOpenArcURLInNewWindow(NSURL *url, NSString *sourceBundleIdentifier) {
    if (![sourceBundleIdentifier isEqualToString:MGArcBundleIdentifier]) {
        return NO;
    }

    NSString *source = [NSString stringWithFormat:
        @"tell application id \"%@\"\n"
         "set newWindow to make new window with properties {mode:\"normal\"}\n"
         "set URL of active tab of newWindow to \"%@\"\n"
         "activate\n"
         "end tell",
        MGArcBundleIdentifier, MGAppleScriptQuotedString(url.absoluteString)];
    NSDictionary *error = nil;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    [script executeAndReturnError:&error];
    if (error != nil) {
        NSLog(@"Open link in Arc window failed: %@", error);
        return NO;
    }
    return YES;
}

@interface MGLinkActionExecutor ()

@property (nonatomic, copy) MGCopyURLHandler copyHandler;
@property (nonatomic, copy) MGOpenURLHandler openHandler;
@property (nonatomic, copy) MGOpenURLInNewWindowHandler newWindowHandler;

@end

@implementation MGLinkActionExecutor

- (instancetype)init {
    return [self initWithCopyHandler:^BOOL(NSString *absoluteURLString) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        return [pasteboard setString:absoluteURLString forType:NSPasteboardTypeString];
    } openHandler:^BOOL(NSURL *url) {
        return [[NSWorkspace sharedWorkspace] openURL:url];
    } newWindowHandler:^BOOL(NSURL *url, NSString *sourceBundleIdentifier) {
        return MGOpenArcURLInNewWindow(url, sourceBundleIdentifier);
    }];
}

- (instancetype)initWithCopyHandler:(MGCopyURLHandler)copyHandler
                         openHandler:(MGOpenURLHandler)openHandler
                    newWindowHandler:(MGOpenURLInNewWindowHandler)newWindowHandler {
    self = [super init];
    if (self) {
        _copyHandler = [copyHandler copy];
        _openHandler = [openHandler copy];
        _newWindowHandler = [newWindowHandler copy];
    }
    return self;
}

- (BOOL)performAction:(MGLinkURLAction)action
                  URL:(NSURL *)url
sourceBundleIdentifier:(NSString *)sourceBundleIdentifier {
    if (url == nil || url.absoluteString.length == 0) {
        return NO;
    }
    switch (action) {
        case MGLinkURLActionCopy:
            return self.copyHandler(url.absoluteString);
        case MGLinkURLActionOpen:
            return self.openHandler(url);
        case MGLinkURLActionOpenInNewWindow:
            if (self.newWindowHandler(url, sourceBundleIdentifier ?: @"")) {
                return YES;
            }
            return self.openHandler(url);
    }
}

@end
