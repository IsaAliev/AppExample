//
//  ViewController.m
//  AppExample
//
//  Created by user on 28.06.16.
//  Copyright © 2016 I&N. All rights reserved.
//

#import "ViewController.h"
#import <GoogleMaps/GoogleMaps.h>

static const CGFloat kTextFieldHeight = 34.0;
static const CGFloat kTextFieldHorizontalInset = 5.0;
static const CGFloat kTextFieldTopInset = 25.0;

@interface ViewController () <UITextFieldDelegate, GMSAutocompleteTableDataSourceDelegate>
@property (strong,nonatomic) GMSMapView *mapView;
@property (strong, nonatomic) GMSAutocompleteTableDataSource* autocompleteDataSource;
@property (strong, nonatomic) UITableViewController* resultsController;
@property (strong, nonatomic) UITextField* searchField;
@end

@implementation ViewController

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [ViewController removeGMSBlockingGestureRecognizerFromMapView:self.mapView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:-33.86
                                                            longitude:151.20
                                                                 zoom:6];
    
    GMSMapView* mapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
    self.mapView = mapView;
    self.mapView.myLocationEnabled = YES;
    
    UITextField* searchTextField = [[UITextField alloc] init];
    
    searchTextField.translatesAutoresizingMaskIntoConstraints = NO;
    searchTextField.borderStyle = UITextBorderStyleRoundedRect;
    searchTextField.backgroundColor = [UIColor whiteColor];
    searchTextField.placeholder = @"Поиск по местам";
    searchTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    searchTextField.keyboardType = UIKeyboardTypeDefault;
    searchTextField.returnKeyType = UIReturnKeyDone;
    searchTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    searchTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    
    searchTextField.delegate = self;
    [searchTextField addTarget:self action:@selector(searchTextFieldTextDidChangeAction:) forControlEvents:UIControlEventEditingChanged];
    
    
    self.autocompleteDataSource = [[GMSAutocompleteTableDataSource alloc] init];
    self.autocompleteDataSource.delegate = self;
    
    _resultsController = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    _resultsController.tableView.delegate = self.autocompleteDataSource;
    _resultsController.tableView.dataSource = self.autocompleteDataSource;
    
    self.view = self.mapView;
    [self.view addSubview:searchTextField];
    self.searchField = searchTextField;

    NSDictionary* metrics = @{@"kTextFieldHorizontalInset":@(kTextFieldHorizontalInset), @"kTextFieldHeight":@(kTextFieldHeight), @"kTextFieldTopInset":@(kTextFieldTopInset)};
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(kTextFieldHorizontalInset)-[searchTextField]-(5)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(searchTextField)]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(kTextFieldTopInset)-[searchTextField(kTextFieldHeight)]" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(searchTextField)]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark - Actions

-(void)searchTextFieldTextDidChangeAction:(UITextField*)textField{
    [self.autocompleteDataSource sourceTextHasChanged:textField.text];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField{
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField{
    [self addChildViewController:_resultsController];
    
    CGRect contentRect = [self contentRect];
    contentRect.origin.y = CGRectGetMaxY(self.view.frame);
    
    _resultsController.view.frame = contentRect;
    
    [self.view addSubview:_resultsController.view];
    [_resultsController.tableView reloadData];
    [self.view layoutIfNeeded];
    
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:1 options:UIViewAnimationOptionCurveLinear animations:^{
        _resultsController.view.frame = [self contentRect];
    } completion:^(BOOL finished) {

    }];

    [_resultsController didMoveToParentViewController:self];
}

- (void)textFieldDidEndEditing:(UITextField *)textField{
    [_resultsController willMoveToParentViewController:nil];
    CGRect initialRect = [self contentRect];
    initialRect.origin.y = CGRectGetMaxY(self.view.frame);
    
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:1 options:UIViewAnimationOptionCurveLinear animations:^{
        _resultsController.view.frame = initialRect;
    } completion:^(BOOL finished) {
        [_resultsController.view removeFromSuperview];
        [_resultsController removeFromParentViewController];
    }];


}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    
    [[[GMSPlacesClient alloc] init] autocompleteQuery:textField.text bounds:nil filter:0 callback:^(NSArray<GMSAutocompletePrediction *> * _Nullable results, NSError * _Nullable error) {
        if (results.count>0) {
        GMSAutocompletePrediction* prediction = [results objectAtIndex:0];
        [[[GMSPlacesClient alloc] init] lookUpPlaceID:prediction.placeID callback:^(GMSPlace * _Nullable result, NSError * _Nullable error) {
            [self moveToPlace:result];

        }];
        }
    }];
    return YES;
}

#pragma mark - GMSAutocompleteTableDataSourceDelegate

- (void)tableDataSource:(GMSAutocompleteTableDataSource *)tableDataSource didFailAutocompleteWithError:(NSError *)error{
    NSLog(@"ERROR %@", error);
}

- (void)tableDataSource:(GMSAutocompleteTableDataSource *)tableDataSource
didAutocompleteWithPlace:(GMSPlace *)place {
    [self.searchField resignFirstResponder];
    NSMutableAttributedString *text =
    [[NSMutableAttributedString alloc] initWithString:[place description]];
    if (place.attributions) {
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\n"]];
        [text appendAttributedString:place.attributions];
    }
    _searchField.text = place.name;
    
    [self moveToPlace:place];

}


- (void)didUpdateAutocompletePredictionsForTableDataSource:
(GMSAutocompleteTableDataSource *)tableDataSource{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [_resultsController.tableView reloadData];
}

- (void)didRequestAutocompletePredictionsForTableDataSource:
(GMSAutocompleteTableDataSource *)tableDataSource{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [_resultsController.tableView reloadData];
}

#pragma mark - Private Methods


-(void)moveToPlace:(GMSPlace*)place{
    GMSCameraPosition* selectedPosition = [GMSCameraPosition cameraWithLatitude:place.coordinate.latitude longitude:place.coordinate.longitude zoom:15];
    
    
    [self.mapView animateToCameraPosition:selectedPosition];
    
    GMSMarker *marker = [[GMSMarker alloc] init];
    marker.position = place.coordinate;
    marker.title = place.name;
    marker.map = self.mapView;
    
}

- (CGRect)contentRect {
    return CGRectMake(0, kTextFieldHeight+kTextFieldTopInset, self.view.bounds.size.width,
                      self.view.bounds.size.height - kTextFieldHeight-kTextFieldTopInset);
}

+ (void)removeGMSBlockingGestureRecognizerFromMapView:(GMSMapView *)mapView
{
    for (id gestureRecognizer in mapView.gestureRecognizers)
    {
        if (![gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]])
        {
            [mapView removeGestureRecognizer:gestureRecognizer];
        }
    }
}

@end
