#import <UIKit/UIKit.h>
extern "C" void RenkSoftHaptic() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback prepare];
        [feedback impactOccurredWithIntensity:0.45];
        #if !__has_feature(objc_arc)
        [feedback release];
        #endif
    });
}
