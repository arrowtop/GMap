//
//  googleMapViewController.h
//  GMap
//
//  Created by toby on 6/18/14.
//  Copyright (c) 2014 Quantilus. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MapViewControllerDelegate.h"

@interface googleMapViewController : UIViewController

@property (nonatomic, weak) id<MapViewControllerDelegate> delegate;
@property (nonatomic) CLLocationCoordinate2D location;
@property (nonatomic, strong) NSString *searchedTitle;
@property(nonatomic) long index;


- (void)mapDidChange: (CLLocationCoordinate2D) location WithZoomLevel: (double)zoom WithMark: (bool)mark;

@end
