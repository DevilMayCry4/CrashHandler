//
//  ViewController.h
//  CrashHandler
//
//  Created by virgil on 16/2/1.
//  Copyright © 2016年 virgil. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class DragView;

@interface ViewController : NSViewController
{
    NSArray *_files;
    NSString *_saveDir;
}
@property (weak) IBOutlet DragView *contentView;
@property (strong) IBOutlet NSTextView *textView;
@property (weak) IBOutlet NSButton *parserButton;

@end

