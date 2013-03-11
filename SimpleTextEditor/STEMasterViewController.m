//
//  STEMasterViewController.m
//  SimpleTextEditor
//
//  Created by Fred Sharples on 3/11/13.
//  Copyright (c) 2013 Orange Design. All rights reserved.
//

#import "STEMasterViewController.h"

#import "STEDetailViewController.h"

#import "STESimpleTextDocument.h"

#import "STEDetailViewController.h"

NSString* STEDocFilenameExtension = @"stedoc";

NSString* DisplayDetailSegue = @"DisplayDetailSegue";

NSString* STEDocumentsDirectoryName = @"Documents";

NSString* DocumentEntryCell = @"DocumentEntryCell";

@interface STEMasterViewController () {
    NSMutableArray *_objects;
}
@end

@implementation STEMasterViewController

NSMutableArray * documents;

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (![segue.identifier isEqualToString:DisplayDetailSegue])
        return;
    
    // Get the detail view controller.
    STEDetailViewController* destVC =
    (STEDetailViewController*)segue.destinationViewController;
    
    // Find the correct dictionary from the documents array.
    NSIndexPath *cellPath = [self.tableView indexPathForSelectedRow];
    UITableViewCell *theCell = [self.tableView cellForRowAtIndexPath:cellPath];
    NSURL *theURL = [documents objectAtIndex:[cellPath row]];
    
    // Assign the URL to the detail view controller and
    // set the title of the view controller to the doc name.
    destVC.detailItem = theURL;
    destVC.navigationItem.title = theCell.textLabel.text;
}


- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSURL *fileURL = [documents objectAtIndex:[indexPath row]];
        
        // Don't use file coordinators on the app's main queue.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSFileCoordinator *fc = [[NSFileCoordinator alloc]
                                     initWithFilePresenter:nil];
            [fc coordinateWritingItemAtURL:fileURL
                                   options:NSFileCoordinatorWritingForDeleting
                                     error:nil
                                byAccessor:^(NSURL *newURL) {
                                    NSFileManager *fm = [[NSFileManager alloc] init];
                                    [fm removeItemAtURL:newURL error:nil];
                                }];
        });
        
        // Remove the URL from the documents array.
        [documents removeObjectAtIndex:[indexPath row]];
        
        // Update the table UI. This must happen after
        // updating the documents array.
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                         withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}


- (UITableViewCell*)tableView:(UITableView *)tableView
        cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *newCell = [tableView dequeueReusableCellWithIdentifier:DocumentEntryCell];
    if (!newCell)
        newCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:DocumentEntryCell];
    
    if (!newCell)
        return nil;
    
    // Get the doc at the specified row.
    NSURL *fileURL = [documents objectAtIndex:[indexPath row]];
    
    // Configure the cell.
    newCell.textLabel.text = [[fileURL lastPathComponent] stringByDeletingPathExtension];
    return newCell;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return [documents count];
}


- (IBAction)addDocument:(id)sender {
    // Disable the Add button while creating the document.
    self.addButton.enabled = NO;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Create the new URL object on a background queue.
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *newDocumentURL = [fm URLForUbiquityContainerIdentifier:nil];
        
        newDocumentURL = [newDocumentURL
                          URLByAppendingPathComponent:STEDocumentsDirectoryName
                          isDirectory:YES];
        newDocumentURL = [newDocumentURL
                          URLByAppendingPathComponent:[self newUntitledDocumentName]];
        
        // Perform the remaining tasks on the main queue.
        dispatch_async(dispatch_get_main_queue(), ^{
            // Update the data structures and table.
            [documents addObject:newDocumentURL];
            
            // Update the table.
            NSIndexPath* newCellIndexPath =
            [NSIndexPath indexPathForRow:([documents count] - 1) inSection:0];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newCellIndexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            
            [self.tableView selectRowAtIndexPath:newCellIndexPath
                                        animated:YES
                                  scrollPosition:UITableViewScrollPositionMiddle];
            
            // Segue to the detail view controller to begin editing.
            UITableViewCell* selectedCell = [self.tableView
                                             cellForRowAtIndexPath:newCellIndexPath];
            [self performSegueWithIdentifier:DisplayDetailSegue sender:selectedCell];
            
            // Reenable the Add button.
            self.addButton.enabled = YES;
        });
    });
}


- (NSString*)newUntitledDocumentName {
    NSInteger docCount = 1;     // Start with 1 and go from there.
    NSString* newDocName = nil;
    
    // At this point, the document list should be up-to-date.
    BOOL done = NO;
    while (!done) {
        newDocName = [NSString stringWithFormat:@"Note %d.%@",
                      docCount, STEDocFilenameExtension];
        
        // Look for an existing document with the same name. If one is
        // found, increment the docCount value and try again.
        BOOL nameExists = NO;
        for (NSURL* aURL in documents) {
            if ([[aURL lastPathComponent] isEqualToString:newDocName]) {
                docCount++;
                nameExists = YES;
                break;
            }
        }
        
        // If the name wasn't found, exit the loop.
        if (!nameExists)
            done = YES;
    }
    return newDocName;
}



- (void)awakeFromNib
{
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    if (!documents){
        documents = [[NSMutableArray alloc] init];
    }
    
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.leftBarButtonItem = self.editButtonItem;

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
    self.navigationItem.rightBarButtonItem = addButton;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)insertNewObject:(id)sender
{
    if (!_objects) {
        _objects = [[NSMutableArray alloc] init];
    }
    [_objects insertObject:[NSDate date] atIndex:0];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - Table View



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSDate *object = _objects[indexPath.row];
        [[segue destinationViewController] setDetailItem:object];
    }
}

@end
