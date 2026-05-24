#ifndef SYPHON26_H
#define SYPHON26_H

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const Syphon26ErrorDomain;

typedef NSString * Syphon26StreamID NS_SWIFT_NAME(Syphon26StreamID);
typedef uint64_t Syphon26Sequence NS_SWIFT_NAME(Syphon26Sequence);
typedef uint64_t Syphon26HostTime NS_SWIFT_NAME(Syphon26HostTime);

typedef NS_ENUM(NSInteger, Syphon26ColorPrimaries) {
    Syphon26ColorPrimariesSRGB,
    Syphon26ColorPrimariesDisplayP3,
    Syphon26ColorPrimariesRec2020,
    Syphon26ColorPrimariesUnspecified
} NS_SWIFT_NAME(Syphon26ColorPrimaries);

typedef NS_ENUM(NSInteger, Syphon26TransferFunction) {
    Syphon26TransferFunctionSRGB,
    Syphon26TransferFunctionLinear,
    Syphon26TransferFunctionPQ,
    Syphon26TransferFunctionHLG,
    Syphon26TransferFunctionUnspecified
} NS_SWIFT_NAME(Syphon26TransferFunction);

typedef NS_ENUM(NSInteger, Syphon26AlphaMode) {
    Syphon26AlphaModeOpaque,
    Syphon26AlphaModePremultiplied,
    Syphon26AlphaModeStraight,
    Syphon26AlphaModeUnspecified
} NS_SWIFT_NAME(Syphon26AlphaMode);

typedef NS_ENUM(NSInteger, Syphon26SyncMode) {
    Syphon26SyncModeAutomatic,
    Syphon26SyncModeSharedEvent,
    Syphon26SyncModeSequencePolling
} NS_SWIFT_NAME(Syphon26SyncMode);

typedef NS_ENUM(NSInteger, Syphon26DeliveryMode) {
    Syphon26DeliveryModeLatest,
    Syphon26DeliveryModeBoundedLatency
} NS_SWIFT_NAME(Syphon26DeliveryMode);

typedef NS_ENUM(NSInteger, Syphon26FallbackReason) {
    Syphon26FallbackReasonNone,
    Syphon26FallbackReasonSharedEventUnavailable,
    Syphon26FallbackReasonSharedEventHandoffFailed,
    Syphon26FallbackReasonIOSurfaceSecureHandoffUnavailable,
    Syphon26FallbackReasonUnsupportedPixelFormat,
    Syphon26FallbackReasonDeviceMismatch
} NS_SWIFT_NAME(Syphon26FallbackReason);

typedef NS_ENUM(NSInteger, Syphon26Role) {
    Syphon26RoleServer,
    Syphon26RoleClient
} NS_SWIFT_NAME(Syphon26Role);

typedef NS_ERROR_ENUM(Syphon26ErrorDomain, Syphon26ErrorCode) {
    Syphon26ErrorUnsupportedDevice = 1,
    Syphon26ErrorUnsupportedPixelFormat,
    Syphon26ErrorInvalidConfiguration,
    Syphon26ErrorTransportUnavailable,
    Syphon26ErrorXPCConnectionFailed,
    Syphon26ErrorSharedEventUnavailable,
    Syphon26ErrorIOSurfaceHandoffFailed,
    Syphon26ErrorStreamNotFound,
    Syphon26ErrorStreamRetired,
    Syphon26ErrorTimeout,
    Syphon26ErrorNoAvailableSlot,
    Syphon26ErrorCommandBufferRequired,
    Syphon26ErrorInternalInconsistency,
    Syphon26ErrorInvalidSharedState,
    Syphon26ErrorUnsupportedSharedStateVersion,
    Syphon26ErrorNamespaceIsolationFailed
};

@class Syphon26TransportCapabilities;
@class Syphon26StreamDescription;
@class Syphon26ServerConfiguration;
@class Syphon26ClientConfiguration;
@class Syphon26DiagnosticsSnapshot;
@class Syphon26ServerDrawable;
@class Syphon26Frame;
@class Syphon26Server;
@class Syphon26Client;
@class Syphon26Directory;

typedef void (^Syphon26ErrorHandler)(NSError *error);
typedef void (^Syphon26StreamHandler)(Syphon26StreamDescription *streamDescription);
typedef void (^Syphon26FrameHandler)(Syphon26Sequence sequence);

@interface Syphon26TransportCapabilities : NSObject <NSCopying>
@property (nonatomic, readonly) Syphon26SyncMode syncMode;
@property (nonatomic, readonly) MTLPixelFormat pixelFormat;
@property (nonatomic, readonly) Syphon26ColorPrimaries colorPrimaries;
@property (nonatomic, readonly) Syphon26TransferFunction transferFunction;
@property (nonatomic, readonly) Syphon26AlphaMode alphaMode;
@property (nonatomic, readonly) NSUInteger ringSlotCount;
@property (nonatomic, readonly) Syphon26FallbackReason fallbackReason;
- (instancetype)initWithSyncMode:(Syphon26SyncMode)syncMode
                     pixelFormat:(MTLPixelFormat)pixelFormat
                  colorPrimaries:(Syphon26ColorPrimaries)colorPrimaries
                transferFunction:(Syphon26TransferFunction)transferFunction
                       alphaMode:(Syphon26AlphaMode)alphaMode
                   ringSlotCount:(NSUInteger)ringSlotCount
                  fallbackReason:(Syphon26FallbackReason)fallbackReason NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface Syphon26StreamDescription : NSObject <NSCopying>
@property (nonatomic, copy, readonly) Syphon26StreamID streamID;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, nullable, readonly) NSString *appName;
@property (nonatomic, readonly) int32_t processIdentifier;
@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;
@property (nonatomic, readonly) MTLPixelFormat pixelFormat;
@property (nonatomic, readonly) Syphon26ColorPrimaries colorPrimaries;
@property (nonatomic, readonly) Syphon26TransferFunction transferFunction;
@property (nonatomic, readonly) Syphon26AlphaMode alphaMode;
@property (nonatomic, readonly) NSUInteger slotCount;
@property (nonatomic, readonly) Syphon26SyncMode syncMode;
@property (nonatomic, readonly) Syphon26DeliveryMode deliveryMode;
@property (nonatomic, strong, readonly) Syphon26TransportCapabilities *transportCapabilities;
@property (nonatomic, copy, readonly) NSSet<NSString *> *capabilities;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *metadata;
@property (nonatomic, readonly) uint64_t descriptionVersion;
@property (nonatomic, readonly) Syphon26HostTime createdAtHostTime;
@end

@interface Syphon26ServerConfiguration : NSObject <NSCopying>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *appName;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic) NSUInteger width;
@property (nonatomic) NSUInteger height;
@property (nonatomic) MTLPixelFormat pixelFormat;
@property (nonatomic) NSUInteger slotCount;
@property (nonatomic) Syphon26SyncMode syncMode;
@property (nonatomic) Syphon26DeliveryMode deliveryMode;
@property (nonatomic) Syphon26ColorPrimaries colorPrimaries;
@property (nonatomic) Syphon26TransferFunction transferFunction;
@property (nonatomic) Syphon26AlphaMode alphaMode;
@property (nonatomic, getter=isPrivateStream) BOOL privateStream;
@property (nonatomic, copy) NSDictionary<NSString *, id> *metadata;
@property (nonatomic) BOOL allowsFallbacks;
@property (nonatomic) uint64_t maximumProducerWaitNanoseconds;
- (instancetype)initWithName:(NSString *)name
                      device:(id<MTLDevice>)device
                       width:(NSUInteger)width
                      height:(NSUInteger)height NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface Syphon26ClientConfiguration : NSObject <NSCopying>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, copy, nullable) Syphon26StreamID streamID;
@property (nonatomic, strong, nullable) Syphon26StreamDescription *streamDescription;
@property (nonatomic) Syphon26SyncMode syncMode;
@property (nonatomic) Syphon26DeliveryMode deliveryMode;
@property (nonatomic, copy) NSArray<NSNumber *> *preferredPixelFormats;
@property (nonatomic) BOOL allowsFallbacks;
@property (nonatomic) uint64_t maximumFrameWaitNanoseconds;
- (instancetype)initWithDevice:(id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface Syphon26DiagnosticsSnapshot : NSObject <NSCopying>
@property (nonatomic, readonly) Syphon26Role role;
@property (nonatomic, copy, nullable, readonly) Syphon26StreamID streamID;
@property (nonatomic, readonly) Syphon26SyncMode syncMode;
@property (nonatomic, readonly) Syphon26FallbackReason fallbackReason;
@property (nonatomic, readonly) NSUInteger activeClientCount;
@property (nonatomic, readonly) uint64_t publishedFrames;
@property (nonatomic, readonly) uint64_t observedFrames;
@property (nonatomic, readonly) uint64_t missedFrames;
@property (nonatomic, readonly) uint64_t repeatedReads;
@property (nonatomic, readonly) uint64_t overwrittenFrames;
@property (nonatomic, readonly) uint64_t droppedFrames;
@property (nonatomic, readonly) uint64_t currentConsumerLagFrames;
@property (nonatomic, readonly) uint64_t maxConsumerLagFrames;
@property (nonatomic, readonly) uint64_t slotDepthFrames;
@property (nonatomic, readonly) uint64_t producerStallNanoseconds;
@property (nonatomic, readonly) uint64_t gpuWaitNanoseconds;
@property (nonatomic, readonly) uint64_t xpcMessagesSent;
@property (nonatomic, readonly) uint64_t xpcMessagesReceived;
@property (nonatomic, readonly) uint64_t sharedEventSignals;
@property (nonatomic, readonly) uint64_t sharedEventWaits;
@property (nonatomic, readonly) uint64_t sharedEventTimeouts;
@property (nonatomic, readonly) NSInteger lastErrorCode;
@end

@interface Syphon26ServerDrawable : NSObject
@property (nonatomic, strong, readonly) id<MTLTexture> texture;
@property (nonatomic, readonly) Syphon26Sequence sequence;
@property (nonatomic, readonly) NSUInteger slotIndex;
@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;
@property (nonatomic, readonly) MTLPixelFormat pixelFormat;
@property (nonatomic, strong, readonly) Syphon26StreamDescription *streamDescription;
@end

@interface Syphon26Frame : NSObject
@property (nonatomic, strong, readonly) id<MTLTexture> texture;
@property (nonatomic, readonly) Syphon26Sequence sequence;
@property (nonatomic, readonly) Syphon26HostTime timestamp;
@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;
@property (nonatomic, readonly) MTLPixelFormat pixelFormat;
@property (nonatomic, readonly) Syphon26ColorPrimaries colorPrimaries;
@property (nonatomic, readonly) Syphon26TransferFunction transferFunction;
@property (nonatomic, readonly) Syphon26AlphaMode alphaMode;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *metadata;
@property (nonatomic, strong, readonly) Syphon26StreamDescription *streamDescription;
@property (nonatomic, readonly) BOOL requiresGPUWait;
- (BOOL)encodeWaitOnCommandBuffer:(id<MTLCommandBuffer>)commandBuffer error:(NSError **)error;
- (void)markConsumedWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (void)close;
@end

@interface Syphon26Server : NSObject
@property (nonatomic, copy, readonly) Syphon26StreamID streamID;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, nullable, readonly) NSString *appName;
@property (nonatomic, strong, readonly) id<MTLDevice> device;
@property (nonatomic, strong, readonly) Syphon26StreamDescription *streamDescription;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly) NSUInteger activeClientCount;
@property (nonatomic, strong, readonly) Syphon26ServerConfiguration *configuration;
@property (nonatomic, strong, readonly) Syphon26DiagnosticsSnapshot *diagnostics;
@property (nonatomic, copy, nullable) Syphon26StreamHandler clientDidConnectHandler;
@property (nonatomic, copy, nullable) Syphon26StreamHandler clientDidDisconnectHandler;
@property (nonatomic, copy, nullable) dispatch_block_t streamDidStartHandler;
@property (nonatomic, copy, nullable) dispatch_block_t streamDidStopHandler;
@property (nonatomic, copy, nullable) Syphon26ErrorHandler errorHandler;
- (nullable instancetype)initWithConfiguration:(Syphon26ServerConfiguration *)configuration error:(NSError **)error;
+ (BOOL)isSupportedOnDevice:(id<MTLDevice>)device reason:(NSString * _Nullable * _Nullable)reason;
- (BOOL)startWithError:(NSError **)error;
- (void)stop;
- (void)invalidate;
- (BOOL)updateName:(NSString *)name error:(NSError **)error;
- (BOOL)updateMetadata:(NSDictionary<NSString *, id> *)metadata error:(NSError **)error;
- (nullable Syphon26ServerDrawable *)acquireDrawableWithTimeout:(uint64_t)timeoutNanoseconds error:(NSError **)error;
- (BOOL)presentDrawable:(Syphon26ServerDrawable *)drawable
          commandBuffer:(id<MTLCommandBuffer>)commandBuffer
              timestamp:(Syphon26HostTime)timestamp
               metadata:(NSDictionary<NSString *, id> *)metadata
                  error:(NSError **)error;
- (void)discardDrawable:(Syphon26ServerDrawable *)drawable;
- (BOOL)publishTexture:(id<MTLTexture>)texture
         commandBuffer:(id<MTLCommandBuffer>)commandBuffer
             timestamp:(Syphon26HostTime)timestamp
              metadata:(NSDictionary<NSString *, id> *)metadata
                 error:(NSError **)error;
- (Syphon26DiagnosticsSnapshot *)diagnosticsSnapshot;
- (void)resetDiagnostics;
@end

@interface Syphon26Client : NSObject
@property (nonatomic, copy, nullable, readonly) Syphon26StreamID streamID;
@property (nonatomic, strong, nullable, readonly) Syphon26StreamDescription *streamDescription;
@property (nonatomic, strong, readonly) id<MTLDevice> device;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly, getter=isValid) BOOL valid;
@property (nonatomic, readonly) BOOL hasNewFrame;
@property (nonatomic, readonly) Syphon26Sequence latestSequence;
@property (nonatomic, readonly) Syphon26Sequence lastPresentedSequence;
@property (nonatomic, strong, readonly) Syphon26ClientConfiguration *configuration;
@property (nonatomic, strong, readonly) Syphon26DiagnosticsSnapshot *diagnostics;
@property (nonatomic, copy, nullable) Syphon26FrameHandler newFrameHandler;
@property (nonatomic, copy, nullable) dispatch_block_t streamDidRetireHandler;
@property (nonatomic, copy, nullable) Syphon26StreamHandler streamDidChangeDescriptionHandler;
@property (nonatomic, copy, nullable) Syphon26ErrorHandler errorHandler;
- (nullable instancetype)initWithConfiguration:(Syphon26ClientConfiguration *)configuration error:(NSError **)error;
- (nullable instancetype)initWithStreamDescription:(Syphon26StreamDescription *)streamDescription
                                           device:(id<MTLDevice>)device
                                            error:(NSError **)error;
+ (BOOL)isSupportedOnDevice:(id<MTLDevice>)device reason:(NSString * _Nullable * _Nullable)reason;
- (BOOL)startWithError:(NSError **)error;
- (void)stop;
- (void)invalidate;
- (nullable Syphon26Frame *)copyLatestFrameWithError:(NSError **)error;
- (nullable Syphon26Frame *)copyLatestFrameWithTimeout:(uint64_t)timeoutNanoseconds error:(NSError **)error;
- (nullable Syphon26Frame *)copyLatestFrameForCommandBuffer:(id<MTLCommandBuffer>)commandBuffer error:(NSError **)error;
- (void)releaseFrame:(Syphon26Frame *)frame;
- (Syphon26DiagnosticsSnapshot *)diagnosticsSnapshot;
- (void)resetDiagnostics;
@end

@interface Syphon26Directory : NSObject
@property (class, nonatomic, strong, readonly) Syphon26Directory *sharedDirectory;
- (BOOL)startWithError:(NSError **)error;
- (void)stop;
- (NSArray<Syphon26StreamDescription *> *)streams;
- (nullable Syphon26StreamDescription *)streamWithID:(Syphon26StreamID)streamID;
- (NSArray<Syphon26StreamDescription *> *)streamsMatchingPredicate:(NSPredicate *)predicate;
- (id)addStreamChangeHandler:(void (^)(NSArray<Syphon26StreamDescription *> *streams))handler;
- (void)removeStreamChangeHandler:(id)handlerToken;
@end

/*
 Classic Syphon bridge APIs are intentionally out of scope for Phase 1.
 Do not include classic Syphon server/client wrappers in this header.
 */

NS_ASSUME_NONNULL_END

#endif
