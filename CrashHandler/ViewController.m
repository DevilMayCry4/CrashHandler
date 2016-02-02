//
//  ViewController.m
//  CrashHandler
//
//  Created by virgil on 16/2/1.
//  Copyright © 2016年 virgil. All rights reserved.
//

#import "ViewController.h"
#import "StandardPaths.h"
#import "MBProgressHUD.h"

@interface DragView : NSView

@property (nonatomic,copy) NSString *filePath;
@property (nonatomic,copy) void(^didSelectedFile)(NSArray *filePaths);

@end

@implementation DragView

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self registerForDraggedTypes:@[NSFilenamesPboardType]];
    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor whiteColor].CGColor;
}

- (NSDragOperation)draggingEntered:(id )sender {
    
    NSLog(@"drag operation entered");
    
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
    
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        
        if (sourceDragMask & NSDragOperationLink) {
            return NSDragOperationLink;
        } else if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id )sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    NSLog(@"drop now");
    
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        
        NSInteger numberOfFiles = [files count];
        
        if(numberOfFiles>0)
        {
            if (_didSelectedFile)
            {
                _didSelectedFile(files);
            }
            _filePath = [files firstObject];
            return YES;
        }
    }
    else
    {
        NSLog(@"pboard types(%@) not register!",[pboard types]);
    }
    return YES;
}


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.textView.editable = NO;
    self.contentView.didSelectedFile = ^(NSArray *files){
        NSMutableArray *crashFiles = [NSMutableArray array];
        NSMutableString *string = [NSMutableString string];
        [string appendString:@"crash文件路径\n"];
        for (NSString *file in files)
        {
            if ([file hasSuffix:@".crash"])
            {
                [string appendFormat:@"%@\n----------------\n",file];
                [crashFiles addObject:file];
            }
        }
       
        if (crashFiles.count)
        {
             _files = crashFiles;
            self.textView.string = string;
        }
    };
}

- (IBAction)onOpen:(id)sender
{
    if (_files.count)
    {
        NSOpenPanel* panel = [NSOpenPanel openPanel];
        panel.canChooseDirectories = YES;
        panel.canChooseFiles = NO;
        // This method displays the panel and returns immediately.
        // The completion handler is called when the user selects an
        // item or cancels the panel.
        [panel beginWithCompletionHandler:^(NSInteger result){
            if (result == NSFileHandlingPanelOKButton) {
                
                NSURL*  theDoc = [[panel URLs] objectAtIndex:0];
                _saveDir = [theDoc path];
                MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithWindow:self.view.window];
                [self.view addSubview:HUD];
                self.contentView.hidden = YES;
                self.parserButton.hidden = YES;
                // Set determinate mode
                HUD.mode = MBProgressHUDModeDeterminate;
                
                HUD.labelText = @"正在解析";
                [HUD show:YES];
                dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    for (NSInteger i = 0; i < _files.count; i++)
                    {
                        NSString *file = _files[i];
                        NSString *name = [[file lastPathComponent] stringByDeletingPathExtension];
                        [self parseCrashFile:file savePath:[_saveDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@__parse.txt",name]]];
                        CGFloat progress = i*1./_files.count;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            HUD.progress = progress;
                            if (i == _files.count - 1)
                            {
                                [HUD hide:YES afterDelay:1];
                                self.contentView.hidden = NO;
                                self.parserButton.hidden = NO;
                            }
                            
                        });
                        
                    }
                });
            }
            
        }];
    }
    
}

- (void)parseCrashFile:(NSString *)crashFile savePath:(NSString *)savePath
{
    NSString *launchPad = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/symbolicatecrash.pl"];
    if([[NSFileManager defaultManager] fileExistsAtPath:launchPad])
    {
        NSTask *symbolicateTask = [[NSTask alloc] init];
        symbolicateTask.launchPath = launchPad;
        symbolicateTask.arguments = [NSArray arrayWithObjects:@"-o", savePath, crashFile, nil];
        [symbolicateTask launch];
        [symbolicateTask waitUntilExit];
    }
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
