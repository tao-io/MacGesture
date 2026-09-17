//
// Created by codefalling on 15/10/17.
// Copyright (c) 2015 MacGesture. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RulesList : NSObject
typedef enum {
    FILTER_TYPE_WILDCARD, // for example *chrome
    FILTER_TYPE_REGEX
} FilterType;

typedef enum {
    ACTION_TYPE_SHORTCUT,
    ACTION_TYPE_APPLE_SCRIPT,
    ACTION_TYPE_COPY_LINK_URL,
    ACTION_TYPE_OPEN_LINK_URL,
    ACTION_TYPE_OPEN_LINK_URL_IN_NEW_WINDOW
} ActionType;

typedef enum {
    CONTEXT_SCOPE_ANY,
    CONTEXT_SCOPE_LINK
} ContextScope;


- (void)addRuleWithDirection:(NSString *)direction
                      filter:(NSString *)filter
                  filterType:(FilterType)filterType
                  actionType:(ActionType)actionType
             shortcutKeyCode:(NSUInteger)shortcutKeyCode // when actionType == ACTION_TYPE_SHORTCUT required,or 0
                shortcutFlag:(NSUInteger)shortcutFlag // when actionType == ACTION_TYPE_SHORTCUT required,or 0
               appleScriptId:(NSString *)appleScriptId // when actionType == ACTION_TYPE_APPLE_SCRIPT required,or nil
                        note:(NSString *)note;

- (void)addRuleWithDirection:(NSString *)direction
                      filter:(NSString *)filter
                  filterType:(FilterType)filterType
                contextScope:(ContextScope)contextScope
                  actionType:(ActionType)actionType
             shortcutKeyCode:(NSUInteger)shortcutKeyCode
                shortcutFlag:(NSUInteger)shortcutFlag
               appleScriptId:(NSString *)appleScriptId
                        note:(NSString *)note;

- (void)moveRuleFrom:(NSInteger)from
              ruleTo:(NSInteger)to;

- (void)removeRuleAtIndex:(NSInteger)index;

- (NSInteger)count;

- (NSString *)directionAtIndex:(NSUInteger)index;

- (NSString *)filterAtIndex:(NSUInteger)index;

- (FilterType)filterTypeAtIndex:(NSUInteger)index;

- (ActionType)actionTypeAtIndex:(NSUInteger)index;

- (ContextScope)contextScopeAtIndex:(NSUInteger)index;

- (NSString *)noteAtIndex:(NSUInteger)index;

- (NSString *)appleScriptIdAtIndex:(NSUInteger)index;

- (NSUInteger)shortcutKeycodeAtIndex:(NSUInteger)index;

- (NSUInteger)shortcutFlagAtIndex:(NSUInteger)index;

- (BOOL)enabledAtIndex:(NSUInteger)index;

- (BOOL)triggerOnEveryMatchAtIndex:(NSUInteger)index;

- (void)setShortcutWithKeycode:(NSUInteger)keycode withFlag:(NSUInteger)flag atIndex:(NSUInteger)index;

- (void)setWildFilter:(NSString *)filter atIndex:(NSUInteger)index;

- (void)setDirection:(NSString *)direction atIndex:(NSUInteger)index;

- (void)setAppleScriptId:(NSString *)id atIndex:(NSUInteger)index;

- (void)setContextScope:(ContextScope)contextScope atIndex:(NSUInteger)index;

- (void)setLinkActionType:(ActionType)actionType atIndex:(NSUInteger)index;

- (void)setNote:(NSString *)note atIndex:(NSUInteger)index;

- (void)setTriggerOnEveryMatch:(BOOL)match atIndex:(NSUInteger)index;

- (BOOL)handleGesture:(NSString *)gesture isLastGesture:(BOOL)last;

- (BOOL)handleGesture:(NSString *)gesture
        isLastGesture:(BOOL)last
              linkURL:(NSURL *)linkURL
          frontBundle:(NSString *)frontBundle;

- (void)toggleRule:(NSUInteger)index;

- (NSInteger)suitedRuleWithGesture:(NSString *)gesture;

- (NSInteger)suitedRuleWithGesture:(NSString *)gesture
                       frontBundle:(NSString *)frontBundle
                           linkURL:(NSURL *)linkURL
                     isLastGesture:(BOOL)last;

- (BOOL)appSuitedRule:(NSString*)bundleId;

- (void)reInit;

- (void)save;

- (NSData *)nsData;

- (RulesList *)initWithNsData:(NSData *)data;

+ (RulesList *)sharedRulesList;

@end
