#import <Foundation/Foundation.h>

/// Runs `block`, turning an Objective-C exception into an error. AVAudioEngine throws these for
/// things like a mic that changed under it, and Swift can't catch them, so they'd quit the app.
BOOL YapCatch(void (NS_NOESCAPE ^_Nonnull block)(void), NSError *_Nullable *_Nullable error);
