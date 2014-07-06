//
//  gmapViewController.m
//  GMap
//
//  Created by toby on 6/18/14.
//  Copyright (c) 2014 Quantilus. All rights reserved.
//

#import "gmapViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <GoogleMaps/GoogleMaps.h>
#import "MapViewControllerDelegate.h"
#import "googleMapViewController.h"

@interface gmapViewController ()<UISearchDisplayDelegate, CLLocationManagerDelegate, MapViewControllerDelegate>
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (nonatomic) UITableView *tableView;
@property (nonatomic, strong) googleMapViewController *mapViewController;

@end

@implementation gmapViewController
{
    CLLocationManager *locationManager;
    NSArray *places;
    NSString *searchedTitle;
}

#define GOOGLE_PLACES_API_KEY @"AIzaSyAbebELSXs7I3Izypw72eqXmf8QFl18Nxg"
#define IDIOM    UI_USER_INTERFACE_IDIOM()
#define IPAD     UIUserInterfaceIdiomPad

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.index == 2 || self.index == 3) {
        [self disableFunctions];
    }

}

#pragma mark - Disable Functions
- (void)disableFunctions
{
    self.searchBar.hidden = YES;
}

#pragma mark - Search Display Controller

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self searchCoordinatesForAddress:searchString];
    return NO;
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView
{
    self.tableView = tableView;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [places count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    NSDictionary *place = [places objectAtIndex:indexPath.row];
    NSString *placeDescription = place[@"description"];
    cell.textLabel.text = placeDescription;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.searchDisplayController setActive:NO animated:YES];
    [self.tableView reloadData];
    NSDictionary *place = [places objectAtIndex:indexPath.row];
    places = nil;
    NSString *reference = place[@"reference"];
    searchedTitle = place[@"description"];
    [self searchCoordinatesForReference:reference];

}

#pragma mark - get Google Map Results
- (void) searchCoordinatesForAddress:(NSString *)inAddress
{
    NSString *searchString = [inAddress stringByReplacingOccurrencesOfString: @" " withString:@"+"];
    NSString *url = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/autocomplete/json?input=%@&sensor=true&key=%@", searchString, GOOGLE_PLACES_API_KEY];
    NSURL *googleRequestURL=[NSURL URLWithString:url];
    dispatch_queue_t downloader = dispatch_queue_create("DataDownloader", NULL);
    dispatch_async(downloader, ^{
        NSData* data = [NSData dataWithContentsOfURL: googleRequestURL];
        [self performSelectorOnMainThread:@selector(fetchedData:) withObject:data waitUntilDone:YES];
    });
}

- (void) fetchedData: (NSData *)responseData
{
    NSError* error;
    NSDictionary* json = [NSJSONSerialization
                          JSONObjectWithData:responseData
                          
                          options:kNilOptions
                          error:&error];
    
    //The results from Google will be an array obtained from the NSDictionary object with the key "results".
    places = [json objectForKey:@"predictions"];
    
    //Write out the data to the console.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void) searchCoordinatesForReference:(NSString *)reference
{
    NSString *url = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/details/json?reference=%@&sensor=true&key=%@", reference, GOOGLE_PLACES_API_KEY];
    NSURL *googleRequestURL=[NSURL URLWithString:url];
    dispatch_queue_t downloader = dispatch_queue_create("ReferenceDownloader", NULL);
    dispatch_async(downloader, ^{
        NSData* data = [NSData dataWithContentsOfURL: googleRequestURL];
        [self performSelectorOnMainThread:@selector(fetchedLocation:) withObject:data waitUntilDone:YES];
    });
}

- (void) fetchedLocation: (NSData *)responseData
{
    NSError* error;
    NSDictionary* json = [NSJSONSerialization
                          JSONObjectWithData:responseData
                          
                          options:kNilOptions
                          error:&error];
    
    //The results from Google will be an array obtained from the NSDictionary object with the key "results".
    double latitude = [[json objectForKey:@"result"][@"geometry"][@"location"][@"lat"] doubleValue];
    double longitude = [[json objectForKey:@"result"][@"geometry"][@"location"][@"lng"] doubleValue];

    //Write out the data to the console.
    dispatch_async(dispatch_get_main_queue(), ^{
        CLLocationCoordinate2D location = CLLocationCoordinate2DMake(latitude, longitude);
        [self gmapViewController:self.mapViewController sendData:location];
        
    });
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"mapSegue"]) {
        [self prepareForMapEmbeddingSegue:segue sender:sender];
    }
}

- (void)prepareForMapEmbeddingSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    self.mapViewController = segue.destinationViewController;
    self.mapViewController.delegate = self;
    self.mapViewController.index = self.index;
}

- (void)gmapViewController:(googleMapViewController *)mapViewController sendData: (CLLocationCoordinate2D) seguelocation
{
    mapViewController.location = seguelocation;
    NSArray *array = [searchedTitle componentsSeparatedByString:@","];
    double zoom;
    if([array count] <= 4) zoom = 3 + [array count]*3;
    else zoom = 18;
    mapViewController.searchedTitle = searchedTitle;
    [mapViewController mapDidChange:seguelocation WithZoomLevel:zoom WithMark: YES];
}

    /*
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.region = self.mapView.region;
    request.naturalLanguageQuery = inAddress;
    MKLocalSearch *localsearch = [[MKLocalSearch alloc] initWithRequest:request];
    dispatch_queue_t downloader = dispatch_queue_create("DataDownloader", NULL);
    dispatch_async(downloader, ^{
        [localsearch startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
            if(error) {
                NSLog(@"Error: %@", error);
                placemarks = [[NSMutableArray alloc] init];
                [self.tableView reloadData];
                
            }
            else {
                for (MKMapItem *item in response.mapItems)
                {
                    CLPlacemark *placemark = item.placemark;
                    [placemarks addObject:placemark];
                    
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadData];
                });
                
            }
        }];
    });
     */





@end
