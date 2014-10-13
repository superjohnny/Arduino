//
//  FiltersMainViewController.m
//  Venere
//
//  Created by John Green on 03/07/2013.
//
//

#import "FiltersMainViewController.h"
#import "UIViewController+Extension.h"
#import "UIView+Extension.h"
#import "NSString+Extension.h"

#define kButtonPadding    20.0f

@interface FiltersMainViewController ()

@property (strong, nonatomic) NSArray *selectedTypes;
@property (strong, nonatomic) NSArray *selectedCityzones;

@end

@implementation FiltersMainViewController
{
    UITextField *activeField;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    [self addNavigationBackButton:@selector(backButtonPressed)];
    
    [self setupToggleButton:self.amenityWifiButton];
    [self setupToggleButton:self.amenityBreakfastButton];
    [self setupToggleButton:self.amenityParkingButton];

    [self setupSegmentControl: self.priceRangeSegment];
    [self setupSegmentControl: self.starRatingSegment];
    
    [self localize];
    
    self.scrollView.contentSize = self.containerView.frame.size;
    
    
    [self registerForKeyboardNotifications]; //listen for the keyboard
    
    //update the display of the filter options
    if (_filter) {
        
        self.priceRange = _filter.priceRange;
        self.starRating = _filter.starRating;
        self.deals = _filter.deals;
        self.propertyName = _filter.propertyName;
        self.amenities = _filter.feature;
        _selectedTypes = _filter.typologies;
        _selectedCityzones = _filter.cityzones;
        
    } else { /* set detaults */
        self.priceRange = SearchProviderFilterPriceRangeAll;
        self.starRating = SearchProviderFilterStarRatingAll;
        self.deals = NO;
        self.propertyName = nil;
        self.amenities = SearchProviderFilterAmenitiesNone;
    }
    
    [self updateAccommodationCheck];
    [self updateCityzoneCheck];
    
    
}

-(NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    [self setFilterResultsTitle:nil];
    [self setPriceRangeTitle:nil];
    [self setStarRatingTitle:nil];
    [self setAmenitiesTitle:nil];
    [self setPriceRangeSegment:nil];
    [self setStarRatingSegment:nil];
    [self setAmenityWifiButton:nil];
    [self setAmenityBreakfastButton:nil];
    [self setAmenityParkingButton:nil];
    [self setScrollView:nil];
    [self setApplyBarButton:nil];
    [self setDealsSwitch:nil];
    [self setPropertyNameTextBox:nil];
    [self setContainerView:nil];
    [self setAccommodationButton:nil];
    [self setAccommodationCheck:nil];
    [self setCityareaButton:nil];
    [self setCityareaCheck:nil];
    [self setPropertyNameTitle:nil];
    [self setDealsTitle:nil];
    [super viewDidUnload];
    
    //remove all notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



- (void) setupToggleButton:(UIButton *) button {
    
//    UIImage *deselectedImage = [[UIImage imageNamed:@"SegmentedControl-Unselected"] resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
//    
//    UIImage *selectedImage = [[UIImage imageNamed:@"SegmentedControl-Selected"] resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
//    
//    [button setBackgroundImage:deselectedImage forState:UIControlStateNormal];
//    [button setBackgroundImage:selectedImage forState:UIControlStateSelected];
//    
//    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
//    [button setTitleColor:[UIColor blackColor] forState:UIControlStateSelected];
}

- (void) setupSegmentControl:(UISegmentedControl *) segmentContol {
    [segmentContol resizeHeight:49];

    
    UIImage *bg = [[UIImage imageNamed:@"SegmentedControl-Unselected"] resizableImageWithCapInsets:UIEdgeInsetsMake(3, 10, 7, 10)];
    UIImage *selected = [[UIImage imageNamed:@"SegmentedControl-Selected"] resizableImageWithCapInsets:UIEdgeInsetsMake(3, 10, 7, 10)];
    [segmentContol setBackgroundImage:bg forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [segmentContol setBackgroundImage:selected forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    
    [segmentContol setDividerImage:[UIImage imageNamed:@"SegmentedControl-Divider-UU"]
                                 forLeftSegmentState:UIControlStateNormal
                                   rightSegmentState:UIControlStateNormal
                                          barMetrics:UIBarMetricsDefault];
    [segmentContol setDividerImage:[UIImage imageNamed:@"SegmentedControl-Divider-SU"]
                                 forLeftSegmentState:UIControlStateSelected
                                   rightSegmentState:UIControlStateNormal
                                          barMetrics:UIBarMetricsDefault];
    
    [segmentContol setDividerImage:[UIImage imageNamed:@"SegmentedControl-Divider-US"]
                                 forLeftSegmentState:UIControlStateNormal
                                   rightSegmentState:UIControlStateSelected
                                          barMetrics:UIBarMetricsDefault];
    
    //setup font and colour
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [UIFont fontWithName:@"OpenSans-Bold" size:14], UITextAttributeFont,
                                [UIColor blackColor], UITextAttributeTextColor,
                                nil];
    NSDictionary *highlightedAttributes = [NSDictionary dictionaryWithObject:[UIColor whiteColor] forKey:UITextAttributeTextColor];
    [segmentContol setTitleTextAttributes:attributes forState:UIControlStateNormal];
    [segmentContol setTitleTextAttributes:highlightedAttributes forState:UIControlStateHighlighted];    
}

- (void) localize {

    self.title = [LocalizationProvider stringForKey:@"SRP_FILTER_BUTTON" withDefault:@"Filter"];
    
    self.navigationItem.rightBarButtonItem.title = [LocalizationProvider stringForKey:@"FILTER_APPLY_BUTTON" withDefault:@"Done"];
    
    //price
    self.priceRangeTitle.text = [LocalizationProvider stringForKey:@"FILTER_PRICE_RANGE" withDefault:@"Price Range"];
    [self.priceRangeSegment setTitle:[LocalizationProvider stringForKey:@"FILTER_PRICE_RANGE_ALL" withDefault:@"All"] forSegmentAtIndex:3];
    
    //star
    self.starRatingTitle.text = [LocalizationProvider stringForKey:@"FILTER_STAR_RATING" withDefault:@"Star Rating"];
    [self.starRatingSegment setTitle:[LocalizationProvider stringForKey:@"FILTER_STAR_RATING_ALL" withDefault:@"All"] forSegmentAtIndex:3];
    
    //amenties
    self.amenitiesTitle.text = [LocalizationProvider stringForKey:@"FILTER_VALUE_ADDS_TITLE" withDefault:@"Show only hotels with"];
    [self.amenityWifiButton setTitle:[LocalizationProvider stringForKey:@"FILTER_VALUE_ADDS_WIFI" withDefault:@"Wifi"] forState:UIControlStateNormal];
    
    //Translated strings for breakfast can be long, we need to check length and reduce pointSize if necessary
    NSDictionary *breakfastButtonAttributesStringsForStates = [self getAttributedStringsForButtonWithText:[LocalizationProvider stringForKey:@"FILTER_VALUE_ADDS_BREAKFAST" withDefault:@"Breakfast"] andFont:self.amenityBreakfastButton.titleLabel.font andButtonWidth:self.amenityBreakfastButton.frame.size.width];
    [self.amenityBreakfastButton setAttributedTitle:[breakfastButtonAttributesStringsForStates objectForKey:@"state_normal"] forState:UIControlStateNormal];
    [self.amenityBreakfastButton setAttributedTitle:[breakfastButtonAttributesStringsForStates objectForKey:@"state_selected"] forState:UIControlStateSelected];
    
    [self.amenityParkingButton setTitle:[LocalizationProvider stringForKey:@"FILTER_VALUE_ADDS_PARKING" withDefault:@"Parking"] forState:UIControlStateNormal];
 
    //deals
    self.dealsTitle.text = [LocalizationProvider stringForKey:@"FILTER_DEAL_FINDER_TITLE" withDefault:@"Show only hotels with deals"];
    
    //accomodation
    [self.accommodationButton setTitle:[LocalizationProvider stringForKey:@"FILTER_PROPERTY_TYPE_FORM" withDefault:@"Select Accommodation type"] forState:UIControlStateNormal];
    
    //city zones
    [self.cityareaButton setTitle:[LocalizationProvider stringForKey:@"FILTER_CITY_AREA_FORM" withDefault:@"Select city areas"] forState:UIControlStateNormal];
    
    //property name
    self.propertyNameTitle.text = [LocalizationProvider stringForKey:@"FILTER_PROPERTY_NAME_TITLE" withDefault:@"Property name"];
}

- (NSDictionary *)getAttributedStringsForButtonWithText:(NSString *)text andFont:(UIFont *)font andButtonWidth:(CGFloat)buttonWidth
{
    NSDictionary *controlStateNormalAttributes;
    NSDictionary *controlStateSelectedAttributes;
    if ([text widthInFont:font] + kButtonPadding >= buttonWidth) {
        CGFloat newPointSize = font.pointSize;
        //if the text is too wide, reduce the pointSize to fit
        newPointSize -= 2.0f;
        UIFont *newFont = [UIFont fontWithName:font.familyName size:newPointSize];
        //These only work with the filter page attributes, so can't be further generalised
        controlStateNormalAttributes = @{NSFontAttributeName : newFont, NSForegroundColorAttributeName : [UIColor blackColor]};
        controlStateSelectedAttributes = @{NSFontAttributeName : newFont, NSForegroundColorAttributeName : [UIColor whiteColor]};
    }else {
        controlStateNormalAttributes = @{NSFontAttributeName : font, NSForegroundColorAttributeName : [UIColor blackColor]};
        controlStateSelectedAttributes = @{NSFontAttributeName : font, NSForegroundColorAttributeName : [UIColor whiteColor]};
    }
    NSAttributedString *controlStateNormalAttrString = [[NSAttributedString alloc] initWithString:text attributes:controlStateNormalAttributes];
    NSAttributedString *controlStateSelectedAttrString = [[NSAttributedString alloc] initWithString:text attributes:controlStateSelectedAttributes];
    
    NSDictionary *allControlStateStrings = @{@"state_normal" : controlStateNormalAttrString, @"state_selected": controlStateSelectedAttrString};
    return allControlStateStrings;
}

#pragma mark - TextField delegates

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    activeField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    activeField = nil;
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

#pragma mark - Keyboard handling

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    CGFloat navBarHeight = self.navigationController.navigationBarHidden ? 0 : self.navigationController.navigationBar.frame.size.height;
    
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    //CGFloat height = kbSize.height;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height + navBarHeight, 0.0);
    
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    
    if (!CGRectContainsPoint(aRect, activeField.frame.origin) ) {
        CGPoint scrollPoint = CGPointMake(0.0, (activeField.frame.origin.y - kbSize.height) + navBarHeight);
        [self.scrollView setContentOffset:scrollPoint animated:YES];
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    //resizes the content view of the table so the keyboard doesnt obscure
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    [UIView animateWithDuration:0.4 animations:^{
        self.scrollView.contentInset = contentInsets;
    }];
    self.scrollView.scrollIndicatorInsets = contentInsets;
}

#pragma mark - Button actions

- (IBAction)amenityButtonTouched:(UIButton *)button {
    button.selected = !button.selected;
}

- (IBAction)applyBarButtonPressed:(UIBarButtonItem *)sender {
    if (self.delegate)
        [self.delegate updateFilters:self];
}

#pragma mark - Property Overrides

- (enum SearchProviderFilterPriceRange) priceRange
{
    switch (self.priceRangeSegment.selectedSegmentIndex) {
        case 0: return SearchProviderFilterPriceRangeLow;
        case 1: return SearchProviderFilterPriceRangeMedium;
        case 2: return SearchProviderFilterPriceRangeHigh;
    };
    return SearchProviderFilterPriceRangeAll;
}
- (void) setPriceRange:(enum SearchProviderFilterPriceRange)priceRange {
    switch (priceRange) {
        case SearchProviderFilterPriceRangeLow:
            self.priceRangeSegment.selectedSegmentIndex = 0;
            break;
        case SearchProviderFilterPriceRangeMedium:
            self.priceRangeSegment.selectedSegmentIndex = 1;
            break;

        case SearchProviderFilterPriceRangeHigh:
            self.priceRangeSegment.selectedSegmentIndex = 2;
            break;

        default:
            self.priceRangeSegment.selectedSegmentIndex = 3;
            break;
    }
}

- (enum SearchProviderFilterStarRating) starRating
{
    switch (self.starRatingSegment.selectedSegmentIndex) {
        case 0: return SearchProviderFilterStarRatingThree + SearchProviderFilterStarRatingFour + SearchProviderFilterStarRatingFive;
        case 1: return SearchProviderFilterStarRatingFour + SearchProviderFilterStarRatingFive;
        case 2: return SearchProviderFilterStarRatingFive;
    };
    return SearchProviderFilterStarRatingAll;
}
- (void) setStarRating:(enum SearchProviderFilterStarRating)starRating {
    
    if (starRating & SearchProviderFilterStarRatingThree)
        self.starRatingSegment.selectedSegmentIndex = 0;
    else if (starRating & SearchProviderFilterStarRatingFour)
        self.starRatingSegment.selectedSegmentIndex = 1;
    else if (starRating & SearchProviderFilterStarRatingFive)
        self.starRatingSegment.selectedSegmentIndex = 2;
    else
        self.starRatingSegment.selectedSegmentIndex = 3;
}

- (enum SearchProviderFilterAmenities) amenities {
    
    enum SearchProviderFilterAmenities value;
    value = SearchProviderFilterAmenitiesNone;
    
    if (self.amenityWifiButton.selected)
        value |= SearchProviderFilterAmenitiesWifi;
    if (self.amenityBreakfastButton.selected)
        value |= SearchProviderFilterAmenitiesBreakfast;
    if (self.amenityParkingButton.selected)
        value |= SearchProviderFilterAmenitiesParking;
    
    return value;
}
- (void) setAmenities:(enum SearchProviderFilterAmenities)amenities {
    self.amenityWifiButton.selected = (amenities & SearchProviderFilterAmenitiesWifi) ? YES : NO;
    self.amenityBreakfastButton.selected = (amenities & SearchProviderFilterAmenitiesBreakfast) ? YES : NO;
    self.amenityParkingButton.selected = (amenities & SearchProviderFilterAmenitiesParking) ? YES : NO;
}

- (BOOL) deals {
    return self.dealsSwitch.on;
}
- (void) setDeals:(BOOL)newDeals {
    self.dealsSwitch.on = newDeals;
}

- (NSArray *) types {
    return _selectedTypes;
}

- (NSArray *) areas {
    return _selectedCityzones;
}

- (NSString *) propertyName {
    return self.propertyNameTextBox.text;
}
- (void) setPropertyName:(NSString *)propertyName {
    self.propertyNameTextBox.text = propertyName;
}


#pragma mark - Segue

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([segue.identifier isEqualToString:SEGUE_FILTER_TYPES]) {
        
        FiltersTypesViewController *controller = segue.destinationViewController;
        controller.types = _filterAssets.typologies;
        controller.selectedTypes = _selectedTypes;
        controller.delegate = self;
        
    } else if([segue.identifier isEqualToString:SEGUE_FILTER_CITYZONES]) {
        FiltersCityzonesViewController *controller = segue.destinationViewController;
        controller.cityzones = _filterAssets.cityZones;
        controller.selectedCityzones = _selectedCityzones;
        controller.delegate = self;
    }
}

#pragma mark - Filter Types Delegate

- (void) updateSelectedTypes:(FiltersTypesViewController* ) filterTypesView {
    DLog();
    _selectedTypes = filterTypesView.selectedTypes;
    [self updateAccommodationCheck];
}

#pragma mark - Filter Cityzones Delegate

- (void) updateSelectedCityzones:(FiltersCityzonesViewController* ) filterCityzonesView {
    DLog();
    _selectedCityzones = filterCityzonesView.selectedCityzones;
    [self updateCityzoneCheck];
}

#pragma mark - Methods

- (void) backButtonPressed {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) updateAccommodationCheck {
    self.accommodationCheck.hidden = !(_selectedTypes && _selectedTypes.count > 0);
}

- (void) updateCityzoneCheck {
    self.cityareaCheck.hidden = !(_selectedCityzones && _selectedCityzones.count > 0);
}
@end
