//
//  BookingGuestController.m
//  Venere
//
//  Created by David Taylor on 13/08/2013.
//
//

#import "BookingGuestController.h"
#import "BookingGuaranteeController.h"
#import "HotelNavigationTitleView.h"
#import "UIViewController+Extension.h"
#import "LocalizationProvider.h"
#import "VenereValidationUtils.h"
#import "BookingGuestCell.h"
#import "BookingGuestDetails.h"
#import "UIView+Extension.h"

#define BOOKINGGUEST_HEADERCELL     @"GuestDetailHeaderCell"
#define ROW_HEIGHT_HEADERCELL       27

@interface BookingGuestController () {
    CGFloat _keyboardHeight;
    CGFloat _keyboardAnimationDuration;
}

@property (weak, nonatomic) IBOutlet HotelNavigationTitleView *hotelNavigationTitleView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *doneButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (strong, nonatomic) NSMutableDictionary *errorDictionary;
@property (nonatomic) BOOL hasError;
@end

@implementation BookingGuestController {
    NSMutableArray *_rowHeights;
    NSMutableArray *_cells;
    BOOL _allowValidation;
    BOOL _isAboveIOS6;
}

#pragma mark - Object lifecycle

- (void)dealloc
{
    [self unregisterKeyboardNotifications];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    _isAboveIOS6 = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0");
    
    [self.navigationBar setBackgroundImage:[UIImage imageNamed:@"navbar"] forBarMetrics:UIBarMetricsDefault];
    
    // Set Navbar title
    [self.hotelNavigationTitleView updateWithName:_detailResult.name andRating:_detailResult.rating];
    
    // Change done and cancel button backgrounds and text
    [self addGreenBackgroundToNavbarButton:self.doneButton];
    [self addGreenBackgroundToNavbarButton:self.cancelButton];
    
    [self.doneButton setTitle:[LocalizationProvider stringForKey:FORM_DONE withDefault:@"Done"]];
    [self.cancelButton setTitle:[LocalizationProvider stringForKey:FORM_CANCEL withDefault:@"Cancel"]];
    
    
    //setup initial heights for rows
    _rowHeights = [NSMutableArray new];
    [_rowHeights addObject:[NSNumber numberWithInt:[BookingGuestCell completeHeight]]];
    [_rowHeights addObject:[NSNumber numberWithInt:[BookingGuestCell partialHeight]]];
    
    
    //disallow validation of the data while the table is loading the first time. It re-adds new cells as the validation triggers height changes
    _allowValidation = NO;
    [self.tableView reloadData];

    
    [self registerKeyboardNotifications];
    
    _cells = [NSMutableArray new];
}

- (void) viewDidAppear:(BOOL)animated   {
    [super viewDidAppear:animated];
    self.errorDictionary = [NSMutableDictionary new];
    self.hasError = NO;
    //now call for validation as the table has loaded to details
    _allowValidation = YES;
    [self validateCells];
    
}

- (void)viewDidUnload {
    [self setNavigationBar:nil];
    [super viewDidUnload];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

-(NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - UIKeyboard methods

- (void)registerKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
}

- (void)unregisterKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    _keyboardHeight = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
    _keyboardAnimationDuration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    
    [UIView animateWithDuration:_keyboardAnimationDuration delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.tableView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, _keyboardHeight, 0.0f);
    } completion:nil];
}

#pragma mark - UI methods

- (IBAction)doneButtonPressed:(id)sender
{
    //validate all the fields again as the current field when done is pressed might not trigger an update
    for (BookingGuestCell *cell in _cells) {
        [cell updateDetails];
    }
    
    
    
    //tell the delegate we have finished
    for (BookingGuestDetails *details in self.bookingGuestDetails) {
        details.filledIn = YES;
    }
    
    if (self.delegate != nil) {
        [self.delegate updateBookingGuest:self dismissWithCancel:NO];
    }
    
    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)cancelButtonPressed:(id)sender
{
    if (self.delegate != nil) {
        [self.delegate updateBookingGuest:self dismissWithCancel:YES];
    }
    
    [self dismissModalViewControllerAnimated:YES];
}


#pragma mark - UITableViewDelegate methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DLog();

    if (indexPath.section == 0)
        return [_rowHeights[0] integerValue];
    
    return [_rowHeights[1] integerValue];
}

- (UIView *) tableView:(UITableView *) tableView viewForHeaderInSection:(NSInteger)section {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BOOKINGGUEST_HEADERCELL];
    
    cell.textLabel.text = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_ROOM_TITLE_V" withDefault:@"Room %number_room%" andReplacements:@{@"number_room" : [NSNumber numberWithInt: section + 1]} ];
    cell.backgroundView = [[UIImageView alloc] initWithImage: [UIImage imageNamed:@"RecentSearchesHeader"]];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    int sections = 0;
    if (self.bookingGuestDetails.count > 0) { // only show section headers if there is more than one room
        sections = self.bookingGuestDetails.count;
    }
    
    return sections;
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    DLog();
    if ([cell isKindOfClass:[BookingGuestCell class]])
        [((BookingGuestCell *)cell) validate: YES];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1; //one guest per section
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellId = (indexPath.section == 0) ? BOOKINGGUESTCOMPLETECELL_ID : BOOKINGGUESTPARTIALCELL_ID;
    DLog(@"requesting: %@", cellId);
    BookingGuestCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    cell.index = indexPath;
    cell.delegate = self;
    [cell updateBookingGuestDetails:self.bookingGuestDetails[indexPath.section]];
    
    //maintain a reference to a cell, as these need to be informed the page is being dismissed, and the textfields need to trigger resignFirstResponder to get all the data collected
    if (![_cells containsObject:cell]) {
        [_cells addObject:cell];
    }
    
    
    return cell;
}

- (CGFloat) tableView:(UITableView *) tableView heightForHeaderInSection:(NSInteger)section {
    return ROW_HEIGHT_HEADERCELL;
}



#pragma mark - BookingGuestCellDelegate methods

- (void)bookingGuestCellWillDismissInput:(BookingGuestCell *)bookingGuestCell;
{
    [self resetTableContentInsets];
}

- (void)bookingGuestCell:(BookingGuestCell *)bookingGuestCell willMoveToField:(BookingDetailsTextField *)field
{
    if (self.hasError)
        return;
    
    CGRect frame = [self.tableView convertRect:field.bounds fromView:field];
    CGFloat fieldCenter = 58.0f;
    
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.tableView.contentOffset = CGPointMake(0.0f, frame.origin.y - fieldCenter);
    } completion:nil];
}

- (void)bookingGuestCellShouldMoveToNextCell:(BookingGuestCell *)bookingGuestCell
{
    if (self.hasError)
        return;
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:bookingGuestCell];
    
    //always one row per section
    //one section per guest
    
    
    if (indexPath.section < self.bookingGuestDetails.count - 1) {
        NSIndexPath *nextIndexPath = [NSIndexPath indexPathForRow:0 inSection:indexPath.section + 1];
        BookingGuestCell *nextCell = (BookingGuestCell *)[self.tableView cellForRowAtIndexPath:nextIndexPath];
        [nextCell becomeFirstResponder];
    } else {
        [self becomeFirstResponder];
        [self resetTableContentInsets];
    }
}

- (void)bookingGuestCellShouldMoveToPreviousCell:(BookingGuestCell *)bookingGuestCell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:bookingGuestCell];
    
    if (indexPath.section > 0) {
        NSIndexPath *previousIndexPath = [NSIndexPath indexPathForRow:0 inSection:indexPath.section - 1];
        BookingGuestCell *previousCell = (BookingGuestCell *)[self.tableView cellForRowAtIndexPath:previousIndexPath];
        [previousCell makeLastTextFieldFirstResponder];
    } else {
        [self becomeFirstResponder];
        [self resetTableContentInsets];
    }
}

- (BOOL) bookingGuestCell:(BookingGuestCell *) bookingGuestCell isBookingGuestDuplicate:(BookingGuestDetails *) bookingGuest {
    //this guest unique?
    NSArray *filtered = [self.bookingGuestDetails filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"firstName == %@ && lastName == %@", bookingGuest.firstName, bookingGuest.lastName]];
    return (filtered.count > 1);
}

- (void) bookingGuestCell:(BookingGuestCell *)bookingGuestCell didChangeHeight:(int)toNewHeight {
    //trigger a resize of the cell
    
    DLog();
    
    //partial cells are not designed to change height for errors. Only record height changes for full cells
    if (bookingGuestCell.index.section == 0)
        _rowHeights[0] = [NSNumber numberWithInt:toNewHeight];
    
    
    //test if this cell is visible by getting the index
    NSIndexPath *index = [self.tableView indexPathForCell:bookingGuestCell];
    
    //if there is no index found, this cell is not visible, DO NOT request an update to the size as this will request a whole new cell, and put it over the top
    if (!index)
        return;
    
    [self.errorDictionary setObject:[NSNumber numberWithBool:bookingGuestCell.hasError] forKey:index];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7")) {
        [self.tableView reloadData];
    } else {
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
    }
    [self.tableView flashScrollIndicators];
}

- (BOOL) bookingGuestCellCanValidate:(BookingGuestCell *) bookingGuestCell {
    //can the cells perform validation?)
    return _allowValidation;
}

#pragma mark -


- (UIView *)viewToPresentSlideUpSheet
{
    return self.view;
}

#pragma mark - Private methods

- (void)resetTableContentInsets
{
    [UIView animateWithDuration:_keyboardAnimationDuration delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.tableView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    } completion:nil];
}

- (BOOL)hasError {
    for (NSNumber *error in [self.errorDictionary allValues]) {
        if (error.boolValue)
            return YES;
    }
    return NO;
}

- (void) validateCells {
    for (NSInteger j = 0; j < [self.tableView numberOfSections]; ++j)
    {
        for (NSInteger i = 0; i < [self.tableView numberOfRowsInSection:j]; ++i)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:j];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            
            if ([cell isKindOfClass:[BookingGuestCell class]]){
                BookingGuestCell *theCell = (BookingGuestCell *)cell;
                [theCell validate];
                [self.errorDictionary setObject:[NSNumber numberWithBool:theCell.hasError] forKey:indexPath];
            }
        }
    }
}

@end
