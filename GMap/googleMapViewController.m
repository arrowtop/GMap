//
//  googleMapViewController.m
//  GMap
//
//  Created by toby on 6/18/14.
//  Copyright (c) 2014 Quantilus. All rights reserved.
//

#import "googleMapViewController.h"
#import <GoogleMaps/GoogleMaps.h>
#import <SocketRocket/SRWebSocket.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface googleMapViewController ()<GMSMapViewDelegate, SRWebSocketDelegate, UIGestureRecognizerDelegate,CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate>
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
@property (strong, nonatomic) NSMutableData *data;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *transferCharacteristic;
@property (strong, nonatomic) NSData *dataToSend;
@property (nonatomic, readwrite) NSInteger sendDataIndex;

@end

@implementation googleMapViewController
{
    GMSMapView *mapView_;
    BOOL isiPad;
    SRWebSocket *webSocket;
}

#define IDIOM    UI_USER_INTERFACE_IDIOM()
#define IPAD     UIUserInterfaceIdiomPad
#define TRANSFER_SERVICE_UUID           @"FB694B90-F49E-4597-8306-171BBA78F846"
#define TRANSFER_CHARACTERISTIC_UUID    @"EB6727C4-F184-497A-A656-76B0CDAC633A"
#define NOTIFY_MTU 20


- (void)viewDidLoad {
    self.location = CLLocationCoordinate2DMake(-33.86, 151.20);
    [self mapDidChange: self.location WithZoomLevel:6 WithMark:NO];
    [super viewDidLoad];
    if (IDIOM == IPAD) {
        isiPad = YES;
    } else {
        isiPad = NO;
        [self createTimer];
    }
    if (self.index == 1) {
        [self createTimer];
    } else if (self.index == 2 || self.index == 3){
        self.view.userInteractionEnabled = NO;
    }
    if (self.index == 1 || self.index == 3) {
        [self connectWebSocket];
    }
    if (self.index == 2) {
        dispatch_queue_t centralQueue = dispatch_queue_create("Bluetooth Service", DISPATCH_QUEUE_SERIAL);
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:centralQueue];
        self.data = [[NSMutableData alloc] init];
    }
    if (self.index == 0) {
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
        
        [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] }];
    }
}

- (void)mapDidChange: (CLLocationCoordinate2D) location WithZoomLevel: (double)zoom WithMark:(bool)mark
{
    self.location = location;
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:self.location.latitude
                                                            longitude:self.location.longitude
                                                                 zoom:zoom];
    if(!mapView_){
        mapView_ = [GMSMapView mapWithFrame:CGRectZero camera:camera];
        mapView_.settings.rotateGestures = NO;
        mapView_.settings.tiltGestures = NO;
        self.view = mapView_;
    } else
        mapView_.camera = camera;

    if (mark == true) {
        // Creates a marker in the center of the map.
        [mapView_ clear];
        GMSMarker *marker = [[GMSMarker alloc] init];
        marker.position = self.location;
        marker.title = self.searchedTitle;
        marker.map = mapView_;
        
    }
}

#pragma mark - Timer
- (void)createTimer
{
    NSTimer *timer =[NSTimer timerWithTimeInterval:0.05 target:self selector:@selector(sendMessage) userInfo:nil repeats: YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    
}

- (NSString *)sendMessage
{
    CGPoint point = mapView_.center;
    CLLocationCoordinate2D coor = [mapView_.projection coordinateForPoint:point];
    double latitude = coor.latitude;
    double longitude = coor.longitude;
    double zoom = mapView_.camera.zoom;
    NSString *regionData = [NSString stringWithFormat:@"%f+%f+%f", latitude, longitude, zoom];
    if(self.index == 1) {
        [webSocket send:regionData];
    } else if (self.index == 0) {
        return regionData;
    }
    return @"";
}

#pragma mark - Connection

- (void)connectWebSocket {
    webSocket.delegate = nil;
    webSocket = nil;
    
    NSString *urlString = @"ws://192.168.1.7:8080";
    SRWebSocket *newWebSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:urlString]];
    newWebSocket.delegate = self;
    
    [newWebSocket open];
}


#pragma mark - SRWebSocket delegate

- (void)webSocketDidOpen:(SRWebSocket *)newWebSocket {
    webSocket = newWebSocket;
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    [self connectWebSocket];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [self connectWebSocket];
}


- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    if (self.index == 3) {
        if (isiPad){
            NSString* receivedData = [NSString stringWithFormat:@"%@", message];
            NSArray *array = [receivedData componentsSeparatedByString:@" "];
            NSArray *regionArray = [[array objectAtIndex:1] componentsSeparatedByString:@"+"];
            if([regionArray count] == 3) {
                CLLocationCoordinate2D coor = CLLocationCoordinate2DMake([[regionArray objectAtIndex:0] doubleValue], [[regionArray objectAtIndex:1] doubleValue]);
                double zoom = [[regionArray objectAtIndex:2] doubleValue]/1.025;
                [self mapDidChange:coor WithZoomLevel: zoom WithMark:NO];
            }
        } else {
            NSString* receivedData = [NSString stringWithFormat:@"%@", message];
            NSArray *array = [receivedData componentsSeparatedByString:@" "];
            NSArray *regionArray = [[array objectAtIndex:1] componentsSeparatedByString:@"+"];
            if([regionArray count] == 3) {
                CLLocationCoordinate2D coor = CLLocationCoordinate2DMake([[regionArray objectAtIndex:0] doubleValue], [[regionArray objectAtIndex:1] doubleValue]);
                double zoom = [[regionArray objectAtIndex:2] doubleValue]*1.025;
                [self mapDidChange:coor WithZoomLevel: zoom WithMark:NO];
            }
        }
    }
}

#pragma mark - Core Bluetooth Methods Receiver
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn) {
        return;
    }
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        // Scan for devices
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
        
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    //NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    if (_discoveredPeripheral != peripheral) {
        // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
        _discoveredPeripheral = peripheral;
        
        // And connect
        [_centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self cleanup];
}

- (void)cleanup {
    
    // See if we are subscribed to a characteristic on the peripheral
    if (self.discoveredPeripheral.services != nil) {
        for (CBService *service in self.discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
    }
    
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    
    [self.centralManager stopScan];
    
    [self.data setLength:0];
    
    peripheral.delegate = self;
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        [self cleanup];
        return;
    }
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]] forService:service];
    }
    // Discover other characteristics
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self cleanup];
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    
    // Have we got everything we need?
    if ([stringFromData isEqualToString:@"EOM"]) {
        
        NSString *receivedData = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
        NSArray *array = [receivedData componentsSeparatedByString:@" "];
        NSArray *regionArray;
        if([array count] == 1) {
        regionArray = [[array objectAtIndex:0] componentsSeparatedByString:@"+"];
        } else {
             regionArray = [[array objectAtIndex:1] componentsSeparatedByString:@"+"];
        }
        if([regionArray count] == 3) {
            CLLocationCoordinate2D coor = CLLocationCoordinate2DMake([[regionArray objectAtIndex:0] doubleValue], [[regionArray objectAtIndex:1] doubleValue]);
            double zoom;
            if(isiPad) zoom = [[regionArray objectAtIndex:2] doubleValue]/1.025;
            else zoom = [[regionArray objectAtIndex:2] doubleValue]*1.025;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self mapDidChange:coor WithZoomLevel: zoom WithMark:NO];
            });
        }
        
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
    
    [self.data appendData:characteristic.value];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
        return;
    }
    
    if (characteristic.isNotifying) {
    } else {
        // Notification has stopped
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    self.discoveredPeripheral = nil;
    
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
}

#pragma mark - Core Bluetooth Methods Sender
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }
    
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        self.transferCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
        
        CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID] primary:YES];
        
        transferService.characteristics = @[_transferCharacteristic];
        
        [_peripheralManager addService:transferService];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    
    _dataToSend = [[self sendMessage] dataUsingEncoding:NSUTF8StringEncoding];
    
    _sendDataIndex = 0;
    
    [self sendData];
}

- (void)sendData {
    
    static BOOL sendingEOM = NO;
    
    // end of message?
    if (sendingEOM) {
        BOOL didSend = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
        
        if (didSend) {
            // It did, so mark it as sent
            sendingEOM = NO;
        }
        // didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return;
    }
    
    // We're sending data
    // Is there any left to send?
    if (self.sendDataIndex >= self.dataToSend.length) {
        // No data left.  Do nothing
        return;
    }
    
    // There's data left, so send until the callback fails, or we're done.
    BOOL didSend = YES;
    
    while (didSend) {
        // Work out how big it should be
        NSInteger amountToSend = self.dataToSend.length - self.sendDataIndex;
        
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) amountToSend = NOTIFY_MTU;
        
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:self.dataToSend.bytes+self.sendDataIndex length:amountToSend];
        
        didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
        
        // If it didn't work, drop out and wait for the callback
        if (!didSend) {
            return;
        }
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSLog(@"Sent: %@", stringFromData);
        
        // It did send, so update our index
        self.sendDataIndex += amountToSend;
        
        // Was it the last one?
        if (self.sendDataIndex >= self.dataToSend.length) {
            
            // Set this so if the send fails, we'll send it next time
            sendingEOM = YES;
            
            BOOL eomSent = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
            
            if (eomSent) {
                // It sent, we're all done
                sendingEOM = NO;
                NSLog(@"Sent: EOM");
            }
            
            return;
        }
    }
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral {
    [self sendData];
}


@end
