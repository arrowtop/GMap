//
//  MapViewControllerDelegate.h
//  GMap
//
//  Created by toby on 6/19/14.
//  Copyright (c) 2014 Quantilus. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GoogleMaps/GoogleMaps.h>

@class googleMapViewController;

@protocol MapViewControllerDelegate <NSObject>

- (void)gmapViewController:(googleMapViewController *)mapViewController sendData: (CLLocationCoordinate2D) location;

@end
