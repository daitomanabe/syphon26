#import <Syphon26/Syphon26.h>

static void Syphon26ObjCCompileOnly(id<MTLDevice> device) {
    Syphon26ServerConfiguration *serverConfiguration =
        [[Syphon26ServerConfiguration alloc] initWithName:@"Objective-C Compile Only"
                                                  device:device
                                                   width:1920
                                                  height:1080];
    serverConfiguration.pixelFormat = MTLPixelFormatBGRA8Unorm;
    serverConfiguration.slotCount = 3;
    serverConfiguration.syncMode = Syphon26SyncModeAutomatic;
    serverConfiguration.deliveryMode = Syphon26DeliveryModeLatest;
    serverConfiguration.metadata = @{@"purpose": @"compile-only"};

    NSError *error = nil;
    Syphon26Server *server = [[Syphon26Server alloc] initWithConfiguration:serverConfiguration error:&error];
    [server startWithError:&error];
    Syphon26DiagnosticsSnapshot *serverDiagnostics = [server diagnosticsSnapshot];
    (void)serverDiagnostics;
    [server stop];

    NSArray<Syphon26StreamDescription *> *streams = [[Syphon26Directory sharedDirectory] streams];
    Syphon26StreamDescription *description = streams.firstObject;
    if (description != nil) {
        Syphon26ClientConfiguration *clientConfiguration =
            [[Syphon26ClientConfiguration alloc] initWithDevice:device];
        clientConfiguration.streamDescription = description;
        clientConfiguration.preferredPixelFormats = @[@(MTLPixelFormatBGRA8Unorm), @(MTLPixelFormatRGBA16Float)];

        Syphon26Client *client = [[Syphon26Client alloc] initWithConfiguration:clientConfiguration error:&error];
        [client startWithError:&error];
        Syphon26Frame *frame = [client copyLatestFrameWithError:&error];
        if (frame.requiresGPUWait) {
            [frame close];
        }
        [client stop];
    }
}
