//
//  BookingGuaranteeController.m
//  Venere
//
//  Created by David Taylor on 13/08/2013.
//
//

#import "BookingGuaranteeController.h"
#import "HotelNavigationTitleView.h"
#import "UIViewController+Extension.h"
#import "MasAvailResult+Extension.h"
#import "VenereBookingDetailsUtils.h"
#import "UIView+Extension.h"
#import "VenereValidationUtils.h"
#import "NSString+Extension.h"
#import "VenereContext.h"

#define INITIAL_HEIGHT      419
#define ANIMATION_DURATION  0.3f
#define BOTTOM_PADDING      13


static NSDictionary *_issueCodes;
static NSArray *_issueCodeKeys;

static NSDictionary *_cardTypeCodes;

static NSDictionary *_phonePrefixes;
static NSArray *_phonePrefixKeys;

static NSArray *_ccMonths;
static NSArray *_ccYears;

typedef enum {
    BookingGuaranteePickerCardType,
    BookingGuaranteePickerCardExpiryDate,
    BookingGuaranteePickerCountryIssued,
    BookingGuaranteePickerPhonePrefix,
}BookingGuaranteePickerType;

@interface BookingGuaranteePickerData : NSObject

@property (strong, nonatomic) NSIndexPath *indexPath; // row + component
@property (strong, nonatomic) UIPickerView *pickerView;

- (id)initWithPickerView:(UIPickerView *)pickerView indexPath:(NSIndexPath *)indexPath;

@end

@implementation BookingGuaranteePickerData

- (id)initWithPickerView:(UIPickerView *)pickerView indexPath:(NSIndexPath *)indexPath
{
    self = [super init];
    if (self != nil) {
        _indexPath = indexPath;
        _pickerView = pickerView;
    }
    
    return self;
}

@end

@interface BookingGuaranteeController () {
    CGFloat _keyboardHeight;
    CGFloat _keyboardAnimationDuration;
    BOOL _isAboveIOS6;
}

@property (weak, nonatomic) IBOutlet HotelNavigationTitleView *hotelNavigationTitleView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *doneButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *textConfirmationLabel;
@property (weak, nonatomic) IBOutlet UIView *phoneDetailsContainerView;
@property (weak, nonatomic) IBOutlet UIView *detailsView;
@property (weak, nonatomic) IBOutlet UINavigationBar *navigationBar;

@property (weak, nonatomic) IBOutlet BookingDetailsTextField *ccNumberTextField;
@property (weak, nonatomic) IBOutlet BookingDetailsTextField *ccCVVNumberTextField;
@property (weak, nonatomic) IBOutlet BookingDetailsTextField *ccFirstNameTextField;
@property (weak, nonatomic) IBOutlet BookingDetailsTextField *ccLastNameTextField;
@property (weak, nonatomic) IBOutlet BookingDetailsTextField *ccExpiryDateTextField;
@property (weak, nonatomic) IBOutlet BookingDetailsTextField *ccCountryIssueTextField;
@property (weak, nonatomic) IBOutlet BookingDetailsTextField *ccZipCodeTextField;
@property (weak, nonatomic) IBOutlet BookingDetailsTextField *ccPhoneTextField;

@property (nonatomic) BookingGuaranteePickerType pickerType;
@property (strong, nonatomic) NSLocale *currentLocale;
@property (nonatomic) BOOL hasError;

//Util properties
@property (readonly, strong, nonatomic) NSString *ccNumber;
@property (readonly, strong, nonatomic) NSString *ccCVVNumber;
@property (readonly, strong, nonatomic) NSString *ccFirstName;
@property (readonly, strong, nonatomic) NSString *ccLastName;
@property (readonly, strong, nonatomic) NSString *ccZipCode;


@end

@implementation BookingGuaranteeController
{
    int _additionalErrorHeight;
}

#pragma mark - Object lifecycle

+ (void)initialize
{
    _issueCodes = [VenereBookingDetailsUtils ccIssuedCountries];
    NSLocale *currentLocal = [[NSLocale alloc] initWithLocaleIdentifier:[VenereContext getSelectedLanguage].languageCode];
    _issueCodeKeys = [_issueCodes.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        NSString *displayName1 = [currentLocal displayNameForKey:NSLocaleCountryCode value:obj1];
        NSString *displayName2 = [currentLocal displayNameForKey:NSLocaleCountryCode value:obj2];
        return [displayName1 compare:displayName2 options:NSCaseInsensitiveSearch];
    }];
    NSArray *initalCountries = [@[@"FR", @"DE", @"IT", @"ES", @"GB", @"US"] sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        NSString *displayName1 = [currentLocal displayNameForKey:NSLocaleCountryCode value:obj1];
        NSString *displayName2 = [currentLocal displayNameForKey:NSLocaleCountryCode value:obj2];
        return [displayName1 compare:displayName2 options:NSCaseInsensitiveSearch];
    }];
    _issueCodeKeys = [initalCountries arrayByAddingObjectsFromArray:_issueCodeKeys];
    
    _cardTypeCodes = [VenereBookingDetailsUtils ccTypes];
    
    _phonePrefixes = [VenereBookingDetailsUtils phonePrefixCodes];
    _phonePrefixKeys = [_phonePrefixes.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        NSString *displayName1 = [currentLocal displayNameForKey:NSLocaleCountryCode value:obj1];
        NSString *displayName2 = [currentLocal displayNameForKey:NSLocaleCountryCode value:obj2];
        return [displayName1 compare:displayName2 options:NSCaseInsensitiveSearch];
    }];
    
    _ccMonths = [VenereBookingDetailsUtils ccMonths];
    _ccYears = [VenereBookingDetailsUtils ccYears];
}

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
    
    _additionalErrorHeight = 0;
    
    self.currentLocale = [[NSLocale alloc] initWithLocaleIdentifier:[VenereContext getSelectedLanguage].languageCode];
    
    [self.navigationBar setBackgroundImage:[UIImage imageNamed:@"navbar"] forBarMetrics:UIBarMetricsDefault];
    
    // Set Navbar title
    [self.hotelNavigationTitleView updateWithName:_detailResult.name andRating:_detailResult.rating];
    
    // Change done and cancel button backgrounds and text
    [self addGreenBackgroundToNavbarButton:self.doneButton];
    [self addGreenBackgroundToNavbarButton:self.cancelButton];
    
    // Load the screen from the gaurantee details
    self.ccNumberTextField.buttonImage = [self.bookingGuaranteeDetails cardTypeImage];
    self.ccNumberTextField.text = self.bookingGuaranteeDetails.ccNumber;
    self.ccCVVNumberTextField.text = self.bookingGuaranteeDetails.ccCVVCode;
    self.ccFirstNameTextField.text = self.bookingGuaranteeDetails.ccFirstName;
    self.ccLastNameTextField.text = self.bookingGuaranteeDetails.ccSurname;
    self.ccExpiryDateTextField.text = [self.bookingGuaranteeDetails ccExpiryDateAsString];
    self.ccZipCodeTextField.text = self.bookingGuaranteeDetails.ccZipCode;
//    NSArray *keys = [_issueCodes allKeysForObject:self.bookingGuaranteeDetails.ccCountryIssued];
//    if (keys.count > 0) {
//        self.ccCountryIssueTextField.text = [self.currentLocale displayNameForKey:NSLocaleCountryCode value:[keys objectAtIndex:0]];
//    }
    if (self.bookingGuaranteeDetails.ccCountryIssued != nil)
        self.ccCountryIssueTextField.text = [self.currentLocale displayNameForKey:NSLocaleCountryCode value:self.bookingGuaranteeDetails.ccCountryIssued];
    else {
        NSString *country = _issueCodeKeys[0]; //_issueCodes[_issueCodeKeys[[pickerView selectedRowInComponent:0]]];
        self.bookingGuaranteeDetails.ccCountryIssued = country;
    }
    
    if (self.bookingGuaranteeDetails.ccExpiryMonth == nil) {
        self.bookingGuaranteeDetails.ccExpiryMonth = _ccMonths[0];
    }
    
    if (self.bookingGuaranteeDetails.ccExpiryYear == nil) {
        self.bookingGuaranteeDetails.ccExpiryYear = _ccYears[0];
    }
    
    self.ccPhoneTextField.text = self.bookingGuaranteeDetails.phoneNumber;
    if (self.bookingGuaranteeDetails.phonePrefix == nil) {
        self.bookingGuaranteeDetails.phonePrefix = [VenereBookingDetailsUtils phonePrefixForCountry:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    }
    self.ccPhoneTextField.buttonTitle = self.bookingGuaranteeDetails.phonePrefix;
    
    // Set localized text
    self.titleLabel.text = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_CARD_TITLE" withDefault:@"Enter your card details. Secure transaction guaranteed."];
    self.ccNumberTextField.placeholder = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_CARD_NUMBER" withDefault:@"Card number (no punctuation, no spaces)"];
    self.ccCVVNumberTextField.placeholder = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_CARD_CVV" withDefault:@"Card number (no punctuation, no spaces)"];
    self.ccPhoneTextField.placeholder = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_PHONE" withDefault:@"Phone number"];
    self.ccFirstNameTextField.placeholder = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_GUEST_FIRST_NAME" withDefault:@"First name"];
    self.ccLastNameTextField.placeholder = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_GUEST_LAST_NAME" withDefault:@"Last name"];
    self.ccExpiryDateTextField.placeholder = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_CARD_EXPIRY_DATE" withDefault:@"Card expiration date"];
    self.ccCountryIssueTextField.placeholder = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_COUNTRY" withDefault:@"Country of issue"];
    self.ccZipCodeTextField.placeholder = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_ZIPCODE" withDefault:@"Zip code"];
    self.ccPhoneTextField.placeholder = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_PHONE" withDefault:@"Phone number"];
    self.textConfirmationLabel.text = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_PHONE_TITLE" withDefault:@"We'll send you a free confirmation text to the phone number provided!"];
    [self.doneButton setTitle:[LocalizationProvider stringForKey:FORM_DONE withDefault:@"Done"]];
    [self.cancelButton setTitle:[LocalizationProvider stringForKey:FORM_CANCEL withDefault:@"Cancel"]];
    
    // Set addition BookingDetailsTextfield properties
    self.ccNumberTextField.buttonUserInteraction = YES;
    self.ccNumberTextField.buttonImage = [self.bookingGuaranteeDetails cardTypeImage];
    [self.ccNumberTextField setButtonEdgeInsets:UIEdgeInsetsMake(3.0f, 5.0f, 5.0f, 220.0f)];
    [self.ccNumberTextField setTextFieldEdgeInsets:UIEdgeInsetsMake(14.0f, 60.0f, 14.0f, 10.0f)];
    self.ccExpiryDateTextField.buttonUserInteraction = YES;
    self.ccCountryIssueTextField.buttonUserInteraction = YES;
    self.ccPhoneTextField.buttonUserInteraction = YES;
    [self.ccPhoneTextField setButtonEdgeInsets:UIEdgeInsetsMake(3.0f, 5.0f, 5.0f, 220.0f)];
    [self.ccPhoneTextField setTextFieldEdgeInsets:UIEdgeInsetsMake(14.0f, 70.0f, 14.0f, 10.0f)];
    self.ccNumberTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.ccCVVNumberTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.ccPhoneTextField.keyboardType = UIKeyboardTypeNumberPad;
    
    // Register keyboard notifications
    [self registerKeyboardNotifications];
    
    //self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width, [self.phoneDetailsContainerView bottom] + 13.0f);
    [self.detailsView resizeHeight:[self.ccZipCodeTextField bottomIfVisible] + BOTTOM_PADDING];
    [self updateScrollviewContentSize];
    
    
    // Set the supported credit cards
    for (MasAcceptedCreditCards *creditCard in self.detailResult.paymentDetails.acceptedCreditCards) {
        if ([self.stay.price isPostpay] && [creditCard.type isEqualToString:PAYMENT_METHOD_POSTPAY]) {
            self.supportedCardTypes = [creditCard.value componentsSeparatedByString:@" "];
        } else if ([self.stay.price isPrepay] && [creditCard.type isEqualToString:PAYMENT_METHOD_PREPAY]) {
            self.supportedCardTypes = [creditCard.value componentsSeparatedByString:@" "];
        }
    }
            
    // Make sure that the BookingGuaranteeDetails is ready to be used
    if (self.bookingGuaranteeDetails == nil) {
        self.bookingGuaranteeDetails = [BookingGuaranteeDetails new];
    }
    
    // Display validation messages unless this is the first time filling in the details
    if (!self.firstView) {
        if (self.bookingGuaranteeDetails.isFilledIn) {
            [self validate];
        }
    }
    
    
    if ([self.bookingGuaranteeDetails.ccCountryIssued isEqualToString:COUNTRY_ISSUED_USA] || [self.bookingGuaranteeDetails.ccCountryIssued isEqualToString:COUNTRY_ISSUED_CANADA]) {
        [self showZipCode];
    }
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
        self.scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, _keyboardHeight, 0.0f);
    } completion:nil];
}

#pragma mark - UI 

- (IBAction)doneButtonPressed:(id)sender
{
    [self updateBookingGuaranteeDetails];

    if (self.delegate != nil) {
        [self.delegate updateBookingGuarantee:self dismissWithCancel:NO];
    }
    
    [self dismissModalViewControllerAnimated:YES];    
}

- (IBAction)cancelButtonPressed:(id)sender
{
    if (self.delegate != nil) {
        [self.delegate updateBookingGuarantee:self dismissWithCancel:YES];
    }
    
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - Private methods

- (void)popCardTypePickerView
{
    self.pickerType = BookingGuaranteePickerCardType;
    [self popPickerView];
    [self scrollToTextField:self.ccNumberTextField];
}

- (void)popDatePickerView
{
    self.pickerType = BookingGuaranteePickerCardExpiryDate;
    [self popPickerView];
    [self scrollToTextField:self.ccExpiryDateTextField];
}

- (void)popPhonePrefixPickerView
{
    self.pickerType = BookingGuaranteePickerPhonePrefix;
    [self popPickerView];
    [self scrollToTextField:self.ccPhoneTextField];
}

- (void)popCountryIssuedPickerView
{
    self.pickerType = BookingGuaranteePickerCountryIssued;
    [self popPickerView];
    [self scrollToTextField:self.ccCountryIssueTextField];
}

- (void)popPickerView
{
    [self.view loopThroughSubviewsAndResignFirstResponder];
    

    
    UIPickerView *picker = [UIPickerView new];
    picker.dataSource = self;
    picker.delegate = self;
    picker.backgroundColor = [UIColor whiteColor];//for iOS 7
    
    SlideUpSheet *sheet = [[SlideUpSheet alloc] initWithPresentInView:self.view
                                               andPreviousButtonTitle:[LocalizationProvider stringForKey:FORM_PREVIOUS withDefault:@"Previous"]
                                                   andNextButtonTitle:[LocalizationProvider stringForKey:FORM_NEXT withDefault:@"Next"]
                                                   andDoneButtonTitle:[LocalizationProvider stringForKey:FORM_DONE withDefault:@"Done"]
                                                           andSubview:picker];
    
    sheet.delegate = self;
    [sheet slideUp];
    
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, _keyboardHeight, 0.0f);
    } completion:nil];
    
    [self selectRowInPicker:picker];
}

- (void)selectRowInPicker:(UIPickerView *)picker
{
    switch (self.pickerType) {
        case BookingGuaranteePickerCardExpiryDate:
            if (self.bookingGuaranteeDetails.ccExpiryMonth != nil) {
                [picker selectRow:[_ccMonths indexOfObject:self.bookingGuaranteeDetails.ccExpiryMonth] inComponent:0 animated:NO];
            }
            if (self.bookingGuaranteeDetails.ccExpiryYear != nil) {
                [picker selectRow:[_ccYears indexOfObject:self.bookingGuaranteeDetails.ccExpiryYear] inComponent:1 animated:NO];
            }
            self.ccExpiryDateTextField.text = [self.bookingGuaranteeDetails ccExpiryDateAsString];
            break;
        case BookingGuaranteePickerCardType:
            if (self.bookingGuaranteeDetails.ccCardType != nil && [self.supportedCardTypes containsObject:self.bookingGuaranteeDetails.ccCardType]) {
                [picker selectRow:[self.supportedCardTypes indexOfObject:self.bookingGuaranteeDetails.ccCardType] inComponent:0 animated:NO];
            } else if (self.bookingGuaranteeDetails.ccCardType == nil) {
                [picker selectRow:0 inComponent:0 animated:NO];
                [self pickerView:picker didSelectRow:0 inComponent:0];
            }
            break;
        case BookingGuaranteePickerCountryIssued: {
            if (self.bookingGuaranteeDetails.ccCountryIssued != nil) {
                [picker selectRow:[_issueCodeKeys indexOfObject:self.bookingGuaranteeDetails.ccCountryIssued] inComponent:0 animated:NO];
                //NSArray *keys = [_issueCodes allKeysForObject:self.bookingGuaranteeDetails.ccCountryIssued];
                //if (keys.count > 0) {
                    //[picker selectRow:[_issueCodeKeys indexOfObject:[keys objectAtIndex:0]] inComponent:0 animated:NO];
                //}
                self.ccCountryIssueTextField.text = [self.currentLocale displayNameForKey:NSLocaleCountryCode value:self.bookingGuaranteeDetails.ccCountryIssued];
            } else {
                [picker selectRow:0 inComponent:0 animated:NO];
            }
            break;
        }
        case BookingGuaranteePickerPhonePrefix: {
            if (self.bookingGuaranteeDetails.phonePrefix != nil) {
                NSArray *keys = [_phonePrefixes allKeysForObject:self.bookingGuaranteeDetails.phonePrefix];
                if (keys.count > 0) {
                    [picker selectRow:[_phonePrefixKeys indexOfObject:[keys objectAtIndex:0]] inComponent:0 animated:NO];
                }
            }
            break;
        }
            
        default:
            break;
    }
}

- (void)showZipCode
{
    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        self.ccZipCodeTextField.alpha = 1.0f;
        self.ccZipCodeTextField.hidden = NO;
        
        [self.detailsView resizeHeight:[self.ccZipCodeTextField bottom] + BOTTOM_PADDING];
        [self updateScrollviewContentSize];
        
    } completion:^(BOOL finished) {

    }];
}

- (void)hideZipCode
{
    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        self.ccZipCodeTextField.alpha = 0.0f;
        self.ccZipCodeTextField.hidden = YES;

        [self.detailsView resizeHeight:[self.ccCountryIssueTextField bottom] + BOTTOM_PADDING];
        [self updateScrollviewContentSize];

    } completion:^(BOOL finished) {

    }];
}

- (void) updateScrollviewContentSize {
    //ensures the scrollview contains the details view container correctly
    self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width, [self.detailsView bottom] + BOTTOM_PADDING);
}

- (void)updatePickerView:(UIPickerView *)pickerView
{
    switch (self.pickerType) {
        case BookingGuaranteePickerCardType:
            self.bookingGuaranteeDetails.ccCardType = self.supportedCardTypes[[pickerView selectedRowInComponent:0]];
            self.ccNumberTextField.buttonImage = [self.bookingGuaranteeDetails cardTypeImage];
            break;
        case BookingGuaranteePickerPhonePrefix:
            self.bookingGuaranteeDetails.phonePrefix = _phonePrefixes[_phonePrefixKeys[[pickerView selectedRowInComponent:0]]];
            self.ccPhoneTextField.buttonTitle = self.bookingGuaranteeDetails.phonePrefix;
            break;
        case BookingGuaranteePickerCountryIssued: {
            NSString *country = _issueCodeKeys[[pickerView selectedRowInComponent:0]]; //_issueCodes[_issueCodeKeys[[pickerView selectedRowInComponent:0]]];
            self.bookingGuaranteeDetails.ccCountryIssued = country;
            self.ccCountryIssueTextField.text = [self.currentLocale displayNameForKey:NSLocaleCountryCode value:_issueCodeKeys[[pickerView selectedRowInComponent:0]]];
            
            
            // USA and Canada residents need to enter a zip code
            if ([country isEqualToString:COUNTRY_ISSUED_USA] || [country isEqualToString:COUNTRY_ISSUED_CANADA]) {
                [self showZipCode];
            } else {
                self.ccZipCodeTextField.text = nil;
                self.ccZipCodeTextField.errorMessage = nil;
                self.bookingGuaranteeDetails.ccZipCode = nil;
                [self hideZipCode];
            }
            
            
            break;
        }
        case BookingGuaranteePickerCardExpiryDate: {
            self.bookingGuaranteeDetails.ccExpiryMonth = _ccMonths[[pickerView selectedRowInComponent:0]];
            self.bookingGuaranteeDetails.ccExpiryYear = _ccYears[[pickerView selectedRowInComponent:1]];
            self.ccExpiryDateTextField.text = [self.bookingGuaranteeDetails ccExpiryDateAsString];
            break;
        }
            
        default:
            break;
    }
}

- (void)jumpToPreviousResponder:(UIResponder *)responder
{
    if (responder == self.ccNumberTextField) {
        [self popCardTypePickerView];
    } else if (responder == self.ccCVVNumberTextField) {
        [self.ccNumberTextField becomeFirstResponder];
    } else if (responder == self.ccFirstNameTextField) {
        [self.ccCVVNumberTextField becomeFirstResponder];
    } else if (responder == self.ccLastNameTextField) {
        [self.ccFirstNameTextField becomeFirstResponder];
//    }
    } else if (responder == self.ccZipCodeTextField) {
        [self popCountryIssuedPickerView];
//    } else if (responder == self.ccPhoneTextField) {
//        [self popPhonePrefixPickerView];
    }
}

- (void)jumpToNextResponder:(UIResponder *)responder
{
    if (responder == self.ccNumberTextField) {
        [self.ccCVVNumberTextField becomeFirstResponder];
    } else if (responder == self.ccCVVNumberTextField) {
        [self.ccFirstNameTextField becomeFirstResponder];
    } else if (responder == self.ccFirstNameTextField) {
        [self.ccLastNameTextField becomeFirstResponder];
    } else if (responder == self.ccLastNameTextField) {
        [self popDatePickerView];
    } else if (responder == self.ccZipCodeTextField) {
        [self popCardTypePickerView];
//        [self popPhonePrefixPickerView];
    } else {
        [responder resignFirstResponder];
        [self resetTableContentInsets];
    }
}

- (void)validate
{
    [self checkPickerValidation:BookingGuaranteePickerCardType];
    [self checkPickerValidation:BookingGuaranteePickerCardExpiryDate];
    [self checkPickerValidation:BookingGuaranteePickerCountryIssued];
//    [self checkPickerValidation:BookingGuaranteePickerPhonePrefix];
    
    [self checkValidation:self.ccNumberTextField];
    [self checkValidation:self.ccCVVNumberTextField];
    [self checkValidation:self.ccFirstNameTextField];
    [self checkValidation:self.ccLastNameTextField];
//    [self checkValidation:self.ccPhoneTextField];
    [self checkValidation:self.ccZipCodeTextField];
    
}

- (void) updateCellHeightFromValidation {
    //how many have errors? The cell needs to grow to accomodate
    int errorHeightTemp = _additionalErrorHeight;

    _additionalErrorHeight = 0;
    if (self.ccCVVNumberTextField.hasError) _additionalErrorHeight += BOOKINGDETAILS_ERRORMSG_HEIGHT;
    if (self.ccFirstNameTextField.hasError) _additionalErrorHeight += BOOKINGDETAILS_ERRORMSG_HEIGHT;
    if (self.ccLastNameTextField.hasError) _additionalErrorHeight += BOOKINGDETAILS_ERRORMSG_HEIGHT;
    if (self.ccExpiryDateTextField.hasError) _additionalErrorHeight += BOOKINGDETAILS_ERRORMSG_HEIGHT;
    if (self.ccCountryIssueTextField.hasError) _additionalErrorHeight += BOOKINGDETAILS_ERRORMSG_HEIGHT;

    if (!self.ccZipCodeTextField.hidden)
        if (self.ccZipCodeTextField.hasError) _additionalErrorHeight += BOOKINGDETAILS_ERRORMSG_HEIGHT;
    
    //rearrange all items positions, animating into new positions
    [self.ccCVVNumberTextField moveTop:[self.ccNumberTextField bottom]];
    [self.ccFirstNameTextField moveTop:[self.ccCVVNumberTextField bottom]];
    [self.ccLastNameTextField moveTop:[self.ccFirstNameTextField bottom]];
    [self.ccExpiryDateTextField moveTop:[self.ccLastNameTextField bottom]];
    [self.ccCountryIssueTextField moveTop:[self.ccExpiryDateTextField bottom]];
    [self.ccZipCodeTextField moveTop:[self.ccCountryIssueTextField bottom]];
    
    //notify the change
    if (errorHeightTemp != _additionalErrorHeight) {
        [self.detailsView resizeHeight:[self.ccZipCodeTextField bottomIfVisible] + BOTTOM_PADDING];
        [self updateScrollviewContentSize];
    }
   
}

-(BOOL)hasError {
    BOOL theError = NO;
    theError |= self.ccNumberTextField.hasError;
    theError |= self.ccCVVNumberTextField.hasError;
    theError |= self.ccFirstNameTextField.hasError;
    theError |= self.ccLastNameTextField.hasError;
    theError |= self.ccExpiryDateTextField.hasError;
    theError |= self.ccCountryIssueTextField.hasError;
    
    if (!self.ccZipCodeTextField.hidden) {
        theError |= self.ccZipCodeTextField.hasError;
    }
    return theError;
}

- (void)checkValidation:(BookingDetailsTextField *)textField
{
    NSString *message;
    if (textField == self.ccFirstNameTextField) {
        [VenereValidationUtils firstNameValid:self.ccFirstName message:&message];
        self.ccFirstNameTextField.errorMessage = message;
    }
    
    if (textField == self.ccLastNameTextField) {
        [VenereValidationUtils lastNameValid:self.ccLastName message:&message];
        self.ccLastNameTextField.errorMessage = message;
    }

    if (textField == self.ccNumberTextField) {
        NSString *cardType = [VenereValidationUtils ccTypeFromCCNumber:self.ccNumber message:&message];
        if (cardType == nil) {
            self.ccNumberTextField.errorMessage = message;
        } else if  (![self.supportedCardTypes containsObject:cardType]) {
            self.ccNumberTextField.errorMessage = [LocalizationProvider stringForKey:@"BF_BOOKING_FORM_PAYMENT_CARD_TYPE_EMPTY" withDefault:@"Select one of the card types accepted by the hotel"];

        } else {
            if ([NSString isNilOrEmpty:self.ccNumber]) {
                self.bookingGuaranteeDetails.ccCardType = cardType;
                self.ccNumberTextField.buttonImage = [self.bookingGuaranteeDetails cardTypeImage];
            }
            self.bookingGuaranteeDetails.ccCardType = cardType;
            self.ccNumberTextField.buttonImage = [self.bookingGuaranteeDetails cardTypeImage];
            [VenereValidationUtils ccNumberValid:self.ccNumber ccType:self.bookingGuaranteeDetails.ccCardType message:&message];
            self.ccNumberTextField.errorMessage = message;
        }
    }
    
    if (textField == self.ccCVVNumberTextField) {
        [VenereValidationUtils ccCVVNumberValid:self.ccCVVNumber ccType:self.bookingGuaranteeDetails.ccCardType message:&message];
        self.ccCVVNumberTextField.errorMessage = message;
    }
    
    if (textField == self.ccPhoneTextField) {
        [VenereValidationUtils phoneNumberCorrectLength:self.ccPhoneTextField.text phonePrefix:self.bookingGuaranteeDetails.phonePrefix message:&message];
        self.ccPhoneTextField.errorMessage = message;
        [VenereValidationUtils phoneNumberValid:self.ccPhoneTextField.text phonePrefix:self.bookingGuaranteeDetails.phonePrefix message:&message];
        self.ccPhoneTextField.errorMessage = message;
    }
    
    if (textField == self.ccZipCodeTextField) {
        [VenereValidationUtils postalCodeValid:self.ccZipCode forCountryCode:self.bookingGuaranteeDetails.ccCountryIssued message:&message];
        self.ccZipCodeTextField.errorMessage = message;
    }
    
    [self updateCellHeightFromValidation];
}

- (void)checkPickerValidation:(BookingGuaranteePickerType)pickerType
{
    NSString *message;
    switch (pickerType) {
        case BookingGuaranteePickerCardExpiryDate:
            [VenereValidationUtils ccExpiryDateValidMonth:self.bookingGuaranteeDetails.ccExpiryMonth year:self.bookingGuaranteeDetails.ccExpiryYear andAfterCheckIn: self.bookingGuaranteeDetails.checkInDate message:&message];
            
            self.ccExpiryDateTextField.errorMessage = message;
            break;
        case BookingGuaranteePickerCardType: {
            if (![NSString isNilOrEmpty:self.ccNumber]) {
                [VenereValidationUtils ccNumberValid:self.ccNumber ccType:self.bookingGuaranteeDetails.ccCardType message:&message];
                self.ccNumberTextField.errorMessage = message;
            }
            break;
        }
        case BookingGuaranteePickerCountryIssued:
            [VenereValidationUtils ccCountryIssuedValid:self.bookingGuaranteeDetails.ccCountryIssued message:&message];
            self.ccCountryIssueTextField.errorMessage = message;
            break;
        case BookingGuaranteePickerPhonePrefix:
            if (self.ccPhoneTextField.text != nil) {
                [VenereValidationUtils phoneNumberValid:self.ccPhoneTextField.text phonePrefix:self.bookingGuaranteeDetails.phonePrefix message:&message];
                self.ccPhoneTextField.errorMessage = message;
            }
            break;
            
        default:
            break;
    }
    
    [self updateCellHeightFromValidation];
}

- (void)updateBookingGuaranteeDetails
{
    self.bookingGuaranteeDetails.ccNumber = self.ccNumber;
    self.bookingGuaranteeDetails.ccCVVCode = self.ccCVVNumber;
    self.bookingGuaranteeDetails.ccFirstName = self.ccFirstName;
    self.bookingGuaranteeDetails.ccSurname = self.ccLastName;
    self.bookingGuaranteeDetails.ccZipCode = self.ccZipCode;
//    self.bookingGuaranteeDetails.phoneNumber = self.ccPhoneTextField.text;
    
    self.bookingGuaranteeDetails.filledIn = YES;
}

#pragma mark - Private Properties

- (NSString *)ccNumber { return [NSString trimmed:self.ccNumberTextField.text]; }
- (NSString *)ccCVVNumber { return [NSString trimmed:self.ccCVVNumberTextField.text]; }
- (NSString *)ccFirstName { return [NSString trimmed:self.ccFirstNameTextField.text]; }
- (NSString *)ccLastName { return [NSString trimmed:self.ccLastNameTextField.text]; }
- (NSString *)ccZipCode { return [NSString trimmed:self.ccZipCodeTextField.text]; }

#pragma mark -

- (void)resetTableContentInsets
{
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    } completion:nil];
}

- (void)scrollToTextField:(BookingDetailsTextField *)textField
{
    if (self.hasError)
        return;
    
    CGRect frame = [self.scrollView convertRect:textField.bounds fromView:textField];
    CGFloat offsetY = [self.scrollView convertRect:self.ccNumberTextField.bounds fromView:self.ccNumberTextField].origin.y;
    
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.scrollView.contentOffset = CGPointMake(0.0f, frame.origin.y - offsetY);
    } completion:nil];
}

#pragma mark - UIPickerViewDataSource methods

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return (self.pickerType == BookingGuaranteePickerCardExpiryDate) ? 2 : 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    switch (self.pickerType) {
        case BookingGuaranteePickerPhonePrefix:
            return _phonePrefixKeys.count;
            break;
        case BookingGuaranteePickerCardType:
            return self.supportedCardTypes.count;
            break;
        case BookingGuaranteePickerCountryIssued:
            return _issueCodeKeys.count;
            break;
        case BookingGuaranteePickerCardExpiryDate:
            return (component == 0) ? _ccMonths.count : _ccYears.count;
            break;
            
        default:
            break;
    }
    
    return 0;
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    ImageLabelView *imageLabelView = (ImageLabelView *)view;

    if (imageLabelView == nil) {
        imageLabelView = [ImageLabelView new];
        NSArray *nibContents = [[NSBundle mainBundle] loadNibNamed:@"ImageLabelView" owner:nil options:nil];
        
        CGSize size = [pickerView rowSizeForComponent:component];

        imageLabelView = nibContents[0];
        imageLabelView.frame = CGRectMake(0, 0, size.width, size.height);
        imageLabelView.imageView.image = [UIImage imageNamed:@"Checkmark"];
        imageLabelView.delegate = self;
    }
    
    imageLabelView.imageView.hidden = ![self isCheckMarkVisibleForRow:row component:component pickerType:self.pickerType];
    imageLabelView.label.text = [self stringForRow:row component:component pickerType:self.pickerType];
    imageLabelView.data = [[BookingGuaranteePickerData alloc] initWithPickerView:pickerView indexPath:[NSIndexPath indexPathForRow:row inSection:component]];

    if (_isAboveIOS6)
        imageLabelView.showImage = NO;
    
    return imageLabelView;
}

- (NSString *)stringForRow:(NSInteger)row component:(NSInteger)component pickerType:(BookingGuaranteePickerType)pickerType
{    
    switch (pickerType) {
        case BookingGuaranteePickerCardType:
            return _cardTypeCodes[self.supportedCardTypes[row]];
        case BookingGuaranteePickerCountryIssued:
            return [self.currentLocale displayNameForKey:NSLocaleCountryCode value:_issueCodeKeys[row]];
        case BookingGuaranteePickerPhonePrefix:
            return [NSString stringWithFormat:@"(%@) %@", _phonePrefixes[_phonePrefixKeys[row]], [self.currentLocale displayNameForKey:NSLocaleCountryCode value:_phonePrefixKeys[row]]];
        case BookingGuaranteePickerCardExpiryDate:
            return (component == 0) ? [NSString stringWithFormat:@"%02d", [_ccMonths[row] integerValue]] : [_ccYears[row] stringValue];
            
        default:
            break;
    }
    
    return nil;
}

- (BOOL)isCheckMarkVisibleForRow:(NSInteger)row component:(NSInteger)component pickerType:(BookingGuaranteePickerType)pickerType
{
    if (_isAboveIOS6)
        return NO;
    
    switch (pickerType) {
        case BookingGuaranteePickerCardType:
            if (self.bookingGuaranteeDetails.ccCardType == nil) {return NO;}
            return [self.supportedCardTypes[row] isEqualToString:self.bookingGuaranteeDetails.ccCardType];
        case BookingGuaranteePickerCountryIssued:
            if (self.bookingGuaranteeDetails.ccCountryIssued == nil) {return NO;}
            //return [_issueCodes[_issueCodeKeys[row]] isEqualToString:self.bookingGuaranteeDetails.ccCountryIssued];
            return [_issueCodeKeys[row] isEqualToString:self.bookingGuaranteeDetails.ccCountryIssued];
        case BookingGuaranteePickerPhonePrefix:
            if (self.bookingGuaranteeDetails.phonePrefix == nil) {return NO;}
            return [_phonePrefixes[_phonePrefixKeys[row]] isEqualToString:self.bookingGuaranteeDetails.phonePrefix];
        case BookingGuaranteePickerCardExpiryDate:
            if (component == 0) {
                if (self.bookingGuaranteeDetails.ccExpiryMonth == nil) {return NO;}
                return [_ccMonths[row] isEqualToNumber:self.bookingGuaranteeDetails.ccExpiryMonth];
            } else {
                if (self.bookingGuaranteeDetails.ccExpiryYear == nil) {return NO;}
                return [_ccYears[row] isEqualToNumber:self.bookingGuaranteeDetails.ccExpiryYear];
            }
            
        default:
            break;
    }
    
    return NO;
}

#pragma mark - UIPickerViewDelegate methods

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    if (_isAboveIOS6) {
        ImageLabelView *currentView = (ImageLabelView *)[pickerView viewForRow:row forComponent:component];
        [self buttonPressedOnImageLabelView:currentView];
    } else {
        [pickerView reloadAllComponents];
        [pickerView selectRow:row inComponent:component animated:YES];
    }
}

#pragma mark - SlideUpSheetDelegate methods

- (void)didDismissSlideUpSheet:(SlideUpSheet *)slideUpSheet dismissedBy:(enum SlideUpSheetDismissedBy)dismissedBy
{    
    [self checkPickerValidation:self.pickerType];
    [self resetTableContentInsets];
}

- (void)previousButtonPressedSlideUpSheet:(SlideUpSheet *)slideUpSheet withSubView:(UIView *)subview
{
    UIPickerView *pickerView = (UIPickerView *)slideUpSheet.subview;
    [self checkPickerValidation:self.pickerType];
    switch (self.pickerType) {
        case BookingGuaranteePickerCardExpiryDate:
            [self.ccLastNameTextField becomeFirstResponder];
            [slideUpSheet dismissSlideUp];
            break;
        case BookingGuaranteePickerCardType:
            [slideUpSheet dismissSlideUp];
            [self resetTableContentInsets];
            break;
        case BookingGuaranteePickerPhonePrefix:
            if ([self.bookingGuaranteeDetails.ccCountryIssued isEqualToString:COUNTRY_ISSUED_USA] || [self.bookingGuaranteeDetails.ccCountryIssued isEqualToString:COUNTRY_ISSUED_CANADA]) {
                [self.ccZipCodeTextField becomeFirstResponder];
                [slideUpSheet dismissSlideUp];
            } else {
                self.pickerType = BookingGuaranteePickerCountryIssued;
                [self scrollToTextField:self.ccCountryIssueTextField];
            }
            break;
        case BookingGuaranteePickerCountryIssued:
            self.pickerType = BookingGuaranteePickerCardExpiryDate;
            [self scrollToTextField:self.ccExpiryDateTextField];
            break;
            
        default:
            break;
    }
    
    [pickerView reloadAllComponents];
    [self selectRowInPicker:pickerView];
}

- (void)nextButtonPressedSlideUpSheet:(SlideUpSheet *)slideUpSheet withSubView:(UIView *)subview
{
    UIPickerView *pickerView = (UIPickerView *)slideUpSheet.subview;
    [self checkPickerValidation:self.pickerType];
    switch (self.pickerType) {
        case BookingGuaranteePickerCardExpiryDate:
            self.pickerType = BookingGuaranteePickerCountryIssued;
            [self scrollToTextField:self.ccCountryIssueTextField];
            break;
        case BookingGuaranteePickerCardType:
            [self.ccNumberTextField becomeFirstResponder];
            [slideUpSheet dismissSlideUp];
            break;
        case BookingGuaranteePickerPhonePrefix:
            [self.ccPhoneTextField becomeFirstResponder];
            [slideUpSheet dismissSlideUp];
            break;
        case BookingGuaranteePickerCountryIssued:
            
            if ([self.bookingGuaranteeDetails.ccCountryIssued isEqualToString:COUNTRY_ISSUED_USA] || [self.bookingGuaranteeDetails.ccCountryIssued isEqualToString:COUNTRY_ISSUED_CANADA]) {
                [self.ccZipCodeTextField becomeFirstResponder];
                [slideUpSheet dismissSlideUp];
            } else {
                [self.ccNumberTextField becomeFirstResponder];
                [slideUpSheet dismissSlideUp];
//                [self resetTableContentInsets];
                
//                self.pickerType = BookingGuaranteePickerPhonePrefix;
//                [self scrollToTextField:self.ccPhoneTextField];
            }

            break;
            
        default:
            break;
    }
    
    [pickerView reloadAllComponents];
    [self selectRowInPicker:pickerView];
}

#pragma mark - ImageLabelViewDelegate methods

- (void)buttonPressedOnImageLabelView:(ImageLabelView *)imageLabelView
{
    NSIndexPath *indexPath = ((BookingGuaranteePickerData *)imageLabelView.data).indexPath;
    UIPickerView *pickerView = ((BookingGuaranteePickerData *)imageLabelView.data).pickerView;
    
    [pickerView selectRow:indexPath.row inComponent:indexPath.section animated:YES];
    [self updatePickerView:pickerView];
    [pickerView reloadAllComponents];
}

#pragma mark - BookingDetailsTextFieldDelegate methods

- (void)bookingDetailsTextFieldDidBeginEditing:(BookingDetailsTextField *)bookingDetailsTextField
{
    [self scrollToTextField:bookingDetailsTextField];
}

- (void)bookingDetailsTextFieldDidEndEditing:(BookingDetailsTextField *)bookingDetailsTextField
{
    [self checkValidation:bookingDetailsTextField];
}

- (void)bookingDetailsTextFieldEditingChanged:(BookingDetailsTextField *)bookingDetailsTextField;
{
    if (bookingDetailsTextField == self.ccNumberTextField) {
        self.bookingGuaranteeDetails.ccCardType = [VenereBookingDetailsUtils ccTypeForCCNumber:bookingDetailsTextField.text];
        self.ccNumberTextField.buttonImage = [self.bookingGuaranteeDetails cardTypeImage];
    }
}

- (BOOL)bookingDetailsTextField:(BookingDetailsTextField *)bookingDetailsTextField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{   
    return YES;
}

- (void)bookingDetailsTextFieldPreviousButtonPressed:(BookingDetailsTextField *)bookingDetailsTextField;
{
    [self checkValidation:bookingDetailsTextField];
    if ([NSString isNilOrEmpty:bookingDetailsTextField.errorMessage]) {
        [self jumpToPreviousResponder:bookingDetailsTextField];
    }
}

- (void)bookingDetailsTextFieldNextButtonPressed:(BookingDetailsTextField *)bookingDetailsTextField;
{
    [self checkValidation:bookingDetailsTextField];
    if ([NSString isNilOrEmpty:bookingDetailsTextField.errorMessage]) {
        [self jumpToNextResponder:bookingDetailsTextField];
    }
}

- (void)bookingDetailsTextFieldDoneButtonPressed:(BookingDetailsTextField *)bookingDetailsTextField
{
    [self resetTableContentInsets];
}

- (void)bookingDetailsTextFieldButtonPressed:(BookingDetailsTextField *)bookingDetailsTextField
{
    if (bookingDetailsTextField == self.ccNumberTextField) {
        [self popCardTypePickerView];
    }
    
    if (bookingDetailsTextField == self.ccExpiryDateTextField) {
        [self popDatePickerView];
    }
    
    if (bookingDetailsTextField == self.ccCountryIssueTextField) {
        [self popCountryIssuedPickerView];
    }
    
    if (bookingDetailsTextField == self.ccPhoneTextField) {
        [self popPhonePrefixPickerView];
    }
}

- (void)viewDidUnload {
    [self setNavigationBar:nil];
    [super viewDidUnload];
}
@end
