#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void (*orig_searchRemote)(id self, SEL _cmd, id query);

static void hooked_searchRemote(id self, SEL _cmd, id query) {
    return;
}

__attribute__((constructor)) static void initTweak(void) {
    Class searchContextClass = objc_getClass("TelegramUI.ChatListSearchContext") ?: 
                               objc_getClass("ChatListSearchContext") ?:
                               objc_getClass("TelegramUI.PeerListGlobalSearchContext");
                               
    if (searchContextClass) {
        SEL searchSel = sel_registerName("searchRemote:");
        if (!class_getInstanceMethod(searchContextClass, searchSel)) {
            searchSel = sel_registerName("setQuery:");
        }
        Method m = class_getInstanceMethod(searchContextClass, searchSel);
        if (m) {
            orig_searchRemote = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)hooked_searchRemote);
        }
    }

    Class resultsControllerClass = objc_getClass("TelegramUI.ChatListSearchContainerNode") ?: 
                                   objc_getClass("ChatListSearchContainerNode");
    if (resultsControllerClass) {
        SEL toggleGlobalSel = sel_registerName("setIncludeGlobalSearch:");
        Method mToggle = class_getInstanceMethod(resultsControllerClass, toggleGlobalSel);
        if (mToggle) {
            IMP blockImp = imp_implementationWithBlock(^(id _self, BOOL include) {
                void (*orig_toggle)(id, SEL, BOOL) = (void *)method_getImplementation(mToggle);
                orig_toggle(_self, toggleGlobalSel, NO);
            });
            method_setImplementation(mToggle, blockImp);
        }
    }
}
