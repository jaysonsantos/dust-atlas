#import <AppKit/AppKit.h>
#include "actions.h"

@interface AtlasMenuTarget : NSObject
@property NSInteger choice;
- (void)choose:(NSMenuItem *)item;
@end
@implementation AtlasMenuTarget
- (void)choose:(NSMenuItem *)item { self.choice = item.tag; }
@end

int atlas_context_menu(const char *path) {
    @autoreleasepool {
        NSString *name = [NSString stringWithUTF8String:path];
        AtlasMenuTarget *target = [AtlasMenuTarget new];
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"File actions"];
        menu.autoenablesItems = NO;
        NSMenuItem *heading = [menu addItemWithTitle:name.lastPathComponent action:nil keyEquivalent:@""];
        heading.enabled = NO;
        [menu addItem:[NSMenuItem separatorItem]];
        NSArray *titles = @[@"Move to Trash", @"Delete Permanently…"];
        for (NSInteger i = 0; i < titles.count; i++) {
            NSMenuItem *item = [menu addItemWithTitle:titles[i] action:@selector(choose:) keyEquivalent:@""];
            item.target = target;
            item.tag = i + 1;
        }
        [menu popUpMenuPositioningItem:nil atLocation:NSEvent.mouseLocation inView:nil];
        if (target.choice == 2) {
            NSAlert *alert = [NSAlert new];
            alert.messageText = @"Delete permanently?";
            alert.informativeText = [NSString stringWithFormat:@"%@\n\nThis deletes the item and its contents. You cannot undo this action.", name];
            alert.alertStyle = NSAlertStyleWarning;
            [alert addButtonWithTitle:@"Cancel"];
            [alert addButtonWithTitle:@"Delete Permanently"];
            if ([alert runModal] != NSAlertSecondButtonReturn) return 0;
        }
        return (int)target.choice;
    }
}

int atlas_remove(const char *path, int permanent, char *error, int capacity) {
    @autoreleasepool {
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
        NSError *failure = nil;
        BOOL ok = permanent
            ? [NSFileManager.defaultManager removeItemAtURL:url error:&failure]
            : [NSFileManager.defaultManager trashItemAtURL:url resultingItemURL:nil error:&failure];
        if (!ok && capacity > 0) snprintf(error, capacity, "%s", failure.localizedDescription.UTF8String ?: "File operation failed");
        return ok;
    }
}
