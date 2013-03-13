#import "STEMasterViewController.h"
#import "STESimpleTextDocument.h"
#import "STEDetailViewController.h"

NSString *STEDocFilenameExtension = @"stedoc";
NSString *DisplayDetailSegue = @"DisplayDetailSegue";
NSString *STEDocumentsDirectoryName = @"Documents";
NSString *DocumentEntryCell = @"DocumentEntryCell";


@implementation STEMasterViewController {
    NSMutableArray *documents;
    NSMetadataQuery *_query;
}
@synthesize addButton;

- (NSMetadataQuery*)textDocumentQuery {
    NSMetadataQuery* aQuery = [[NSMetadataQuery alloc] init];
    if (aQuery) {
        // Search the Documents subdirectory only.
        [aQuery setSearchScopes:[NSArray
                                 arrayWithObject:NSMetadataQueryUbiquitousDocumentsScope]];
        
        // Add a predicate for finding the documents.
        NSString* filePattern = [NSString stringWithFormat:@"*.%@",
                                 STEDocFilenameExtension];
        [aQuery setPredicate:[NSPredicate predicateWithFormat:@"%K LIKE %@",
                              NSMetadataItemFSNameKey, filePattern]];
    }
    
    return aQuery;
}

- (void)setupAndStartQuery {
    // Create the query object if it does not exist.
    if (!_query)
        _query = [self textDocumentQuery];
    
    // Register for the metadata query notifications.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(processFiles:)
                                                 name:NSMetadataQueryDidFinishGatheringNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(processFiles:)
                                                 name:NSMetadataQueryDidUpdateNotification
                                               object:nil];
    
    [_query startQuery];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    if (!documents)
        documents = [[NSMutableArray alloc] init];
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    [self setupAndStartQuery];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark Document Management

- (NSString*)newUntitledDocumentName {
    NSInteger docCount = 1;   // Start with 1 and go from there.
    NSString *newDocName = nil;
    
    // At this point, the document list should be up to date.
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

- (IBAction)addDocument:(id)sender {
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
        });
    });
}

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


#pragma mark Table View methods

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return [documents count];
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


#pragma mark Query Method

- (void)processFiles:(NSNotification*)aNotification {
    NSMutableArray *discoveredFiles = [NSMutableArray array];
    
    // Always disable updates while processing results.
    [_query disableUpdates];
    
    // The query reports all files found, every time.
    NSArray *queryResults = [_query results];
    for (NSMetadataItem *result in queryResults) {
        NSURL *fileURL = [result valueForAttribute:NSMetadataItemURLKey];
        NSNumber *aBool = nil;
        
        // Don't include hidden files.
        [fileURL getResourceValue:&aBool forKey:NSURLIsHiddenKey error:nil];
        if (aBool && ![aBool boolValue])
            [discoveredFiles addObject:fileURL];
    }
    
    // Update the list of documents.
    [documents removeAllObjects];
    [documents addObjectsFromArray:discoveredFiles];
    [self.tableView reloadData];
    
    // Reenable query updates.
    [_query enableUpdates];
}
@end
