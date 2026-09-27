#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// נטרול תצוגת מקטעי חיפוש גלובלי בתוך הטבלאות והתצוגות של טלגרם
static CGFloat (*orig_heightForRow)(id self, SEL _cmd, UITableView *tableView, NSIndexPath *indexPath);
static CGFloat hooked_heightForRow(id self, SEL _cmd, UITableView *tableView, NSIndexPath *indexPath) {
    // אם זו מחלקת תוצאות חיפוש
    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"Search"]) {
        // בודקים אם הפריט במקטע הזה שייך לחיפוש גלובלי
        @try {
            SEL itemSelector = sel_registerName("itemAtIndexPath:");
            if ([self respondsToSelector:itemSelector]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id item = [self performSelector:itemSelector withObject:indexPath];
                #pragma clang diagnostic pop
                if (item) {
                    NSString *itemDesc = NSStringFromClass([item class]);
                    if ([itemDesc containsString:@"Global"] || [itemDesc containsString:@"Remote"]) {
                        return 0.01; // גובה אפס - מעלים את השורה
                    }
                }
            }
        } @catch (NSException *e) {}
    }
    
    if (orig_heightForRow) {
        return orig_heightForRow(self, _cmd, tableView, indexPath);
    }
    return 44.0;
}

// חסימת יצירת תאי Global Search
static UITableViewCell* (*orig_cellForRow)(id self, SEL _cmd, UITableView *tableView, NSIndexPath *indexPath);
static UITableViewCell* hooked_cellForRow(id self, SEL _cmd, UITableView *tableView, NSIndexPath *indexPath) {
    UITableViewCell *cell = nil;
    if (orig_cellForRow) {
        cell = orig_cellForRow(self, _cmd, tableView, indexPath);
    }
    
    @try {
        NSString *cellClass = NSStringFromClass([cell class]);
        // אם מדובר בתא של ערוץ/קבוצה ציבורית מחיפוש עולמי או כותרת Global Search
        if ([cellClass containsString:@"Global"] || [cellClass containsString:@"Remote"]) {
            cell.hidden = YES;
            cell.userInteractionEnabled = NO;
        }
    } @catch (NSException *e) {}
    
    return cell;
}

__attribute__((constructor)) static void initTweak(void) {
    // מבצעים Hook רוחבי על כל בקרי הטבלה של החיפוש ב-Telegram
    Class searchClass = objc_getClass("TelegramUI.ChatListSearchContainerNode") ?:
                        objc_getClass("ChatListSearchContainerNode") ?:
                        objc_getClass("TelegramUI.PeerListSearchControllerNode");
    
    if (searchClass) {
        // Hooking heightForRow
        SEL heightSel = sel_registerName("tableView:heightForRowAtIndexPath:");
        Method mHeight = class_getInstanceMethod(searchClass, heightSel);
        if (mHeight) {
            orig_heightForRow = (void *)method_getImplementation(mHeight);
            method_setImplementation(mHeight, (IMP)hooked_heightForRow);
        }
        
        // Hooking cellForRow
        SEL cellSel = sel_registerName("tableView:cellForRowAtIndexPath:");
        Method mCell = class_getInstanceMethod(searchClass, cellSel);
        if (mCell) {
            orig_cellForRow = (void *)method_getImplementation(mCell);
            method_setImplementation(mCell, (IMP)hooked_cellForRow);
        }
    }
}
