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
#import "TableCell.h"

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

@interface ViewController ()<NSTableViewDataSource,NSTableViewDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSTableColumn *column = [self.tableView.tableColumns firstObject];
    column.headerCell.stringValue = @"解析文件路径";
    [column setWidth:1000];
    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
    [theMenu insertItemWithTitle:@"在右侧打开" action:@selector(openMenu) keyEquivalent:@"" atIndex:0];
    [theMenu insertItemWithTitle:@"在finder中打开" action:@selector(openFileAtFinder) keyEquivalent:@"" atIndex:1];
    self.tableView.menu = theMenu;
     self.tableConentView.hidden = YES;
    self.reloadButton.hidden = YES;
    self.tableView.rowHeight = 30;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;

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
        else
        {

            NSError *error = [NSError errorWithDomain:@"t" code:111 userInfo:@{NSLocalizedDescriptionKey:@"没有找到.crash文件"}];
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert runModal];
        }
    };
}

- (void)openMenu
{
    NSString *path = [self getCrashParsePath:_files[self.tableView.clickedRow]];
    NSString *string = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    self.textView.string = string;
}

- (void)openFileAtFinder
{
    NSString *path = [self getCrashParsePath:_files[self.tableView.clickedRow]];
    NSArray *fileURLs = [NSArray arrayWithObjects:[NSURL fileURLWithPath:path], /* ... */ nil];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}

- (IBAction)onOpen:(id)sender
{
    if (_files.count)
    {
        [self.tableView reloadData];
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
                        [self parseCrashFile:file savePath:[self getCrashParsePath:file]];
                        CGFloat progress = i*1./_files.count;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            HUD.progress = progress;
                            if (i == _files.count - 1)
                            {
                                [HUD hide:YES afterDelay:1];
                                self.tableConentView.hidden = NO;
                                self.reloadButton.hidden = NO;
                            }
                            
                        });
                        
                    }
                });
            }
            
        }];
    }
    
}

- (IBAction)onRightButtonClick:(id)sender
{
    self.tableConentView.hidden = YES;
    self.reloadButton.hidden = YES;
    self.contentView.hidden = NO;
    self.parserButton.hidden = NO;
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

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _files.count;
}

- (void)onDoubleTap:(NSTableView *)tableView
{
    NSString *path = [self getCrashParsePath:_files[tableView.selectedRow]];
    NSString *string = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    self.textView.string = string;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{

    TableCell *cell = [tableView makeViewWithIdentifier:@"MyView" owner:self];
    
    // There is no existing cell to reuse so create a new one
    if (cell == nil) {
        
        // Create the new NSTextField with a frame of the {0,0} with the width of the table.
        // Note that the height of the frame is not really relevant, because the row height will modify the height.
        cell = [[TableCell alloc] initWithFrame:CGRectZero];
        cell.autoresizingMask = NSViewAutoresizingFlexibleWidth;
        // The identifier of the NSTextField instance is set to MyView.
        // This allows the cell to be reused.
        cell.identifier = @"MyView";
    }
    cell.stringValue = [self getCrashParsePath:_files[row]];
    // result is now guaranteed to be valid, either as a reused cell
    // or as a new cell, so set the stringValue of the cell to the
    // nameArray value at row
    
    // Return the result
    return cell;
}

- (NSString *)getCrashParsePath:(NSString *)crashPath
{
    NSString *name = [[crashPath lastPathComponent] stringByDeletingPathExtension];
    return [_saveDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@__parse.txt",name]];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
