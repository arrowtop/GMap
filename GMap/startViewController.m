//
//  startViewController.m
//  GMap
//
//  Created by toby on 6/19/14.
//  Copyright (c) 2014 Quantilus. All rights reserved.
//

#import "startViewController.h"
#import "gmapViewController.h"

@interface startViewController ()<UIPickerViewDataSource, UIPickerViewDelegate>

@property (weak, nonatomic) IBOutlet UIPickerView *pickerView;

@end

@implementation startViewController
{
    NSArray *array;
    long index;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationController setNavigationBarHidden:YES];
    array = [[NSArray alloc]         initWithObjects:@"Host-Bluetooth",@"Host-WiFi",@"Receiver-Bluetooth",@"Receiver-WiFi", nil];
}

#pragma mark - Navigation
-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row   forComponent:(NSInteger)component
{
    return [array objectAtIndex:row];
}
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row   inComponent:(NSInteger)component
{
    index = row;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
    
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent: (NSInteger)component
{
    return 4;
    
}

- (IBAction)segue:(id)sender
{
    if (index >= 0 && index < 4) {
        gmapViewController *gvc = [self.storyboard instantiateViewControllerWithIdentifier:@"gmapViewController"];
        [self.navigationController pushViewController:gvc animated:YES];
        gvc.index = index;
    }
}

@end
