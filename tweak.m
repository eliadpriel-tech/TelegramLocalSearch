#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// נטרול גלובלי של תאי חיפוש ברשת לפי תוכן וטקסט
static void (*orig_layoutSubviews)(id self, SEL _cmd);
static void hooked_layoutSubviews(id self, SEL _cmd) {
    if (orig_layoutSubviews) {
        orig_layoutSubviews(self, _cmd);
    }
    
    UIView *view = (UIView *)self;
    
    // סריקה רק של תצוגות שקשורות לרשימות ולחיפוש
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"Cell"] || [className containsString:@"NodeView"] || [className containsString:@"ItemView"]) {
        
        // בדיקה רקורסיבית אם התא מכיל כותרת של חיפוש עולמי
        void (^checkView)(UIView *) = ^(UIView *v) {
            if ([v isKindOfClass:[UILabel class]]) {
                UILabel *lbl = (UILabel *)v;
                NSString *text = lbl.text;
                if (text && ([text isEqualToString:@"Global Search"] || 
                             [text isEqualToString:@"חיפוש גלובלי"] || 
                             [text containsString:@"Global"] ||
                             [text containsString:@"גלובלי"])) {
                    // הסתרת כל השורה/התא
                    view.hidden = YES;
                    view.alpha = 0.0;
                    view.userInteractionEnabled = NO;
                    CGRect frame = view.frame;
                    frame.size.height = 0;
                    view.frame = frame;
                }
            }
        };
        
        for (UIView *sub in view.subviews) {
            checkView(sub);
            for (UIView *sub2 in sub.subviews) {
                checkView(sub2);
            }
        }
    }
}

__attribute__((constructor)) static void initTweak(void) {
    // Hooking UIView layoutSubviews בצורה גלובלית
    Class viewClass = [UIView class];
    SEL layoutSel = sel_registerName("layoutSubviews");
    Method mLayout = class_getInstanceMethod(viewClass, layoutSel);
    if (mLayout) {
        orig_layoutSubviews = (void *)method_getImplementation(mLayout);
        method_setImplementation(mLayout, (IMP)hooked_layoutSubviews);
    }
}
