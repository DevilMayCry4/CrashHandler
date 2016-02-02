//
//  TableCell.m
//  CrashHandler
//
//  Created by virgil on 16/2/2.
//  Copyright © 2016年 virgil. All rights reserved.
//

#import "TableCell.h"

@implementation TableCell

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self)
    {
        
    }
    return self;
}

- (NSMenu *)textView:(NSTextView *)view menu:(NSMenu *)menu forEvent:(NSEvent *)event atIndex:(NSUInteger)charIndex
{
    return nil;
}


- (void)rightMouseUp:(NSEvent *)theEvent
{
}


- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)openMenu
{
}
@end
