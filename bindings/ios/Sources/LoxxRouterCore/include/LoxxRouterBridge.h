//
//  LoxxRouterBridge.h
//  LoxxRouter
//
//  C++ to Swift bridge for routing engine
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

/// Internal bridge class connecting Swift API to C++ routing core
/// This class is not part of public API and should not be used directly
@interface LoxxRouterBridge : NSObject

/// Initialize bridge with database path and options
/// @param path Path to .routingdb file
/// @param zoom Tile zoom level (default 14)
/// @param cacheCapacity Number of tiles to cache in memory
/// @param error Error pointer for initialization failures
- (nullable instancetype)initWithPath:(NSString *)path
                                 zoom:(NSInteger)zoom
                        cacheCapacity:(NSInteger)cacheCapacity
                                error:(NSError **)error;

/// Calculate route between two coordinates
/// @param start Starting coordinate
/// @param end Destination coordinate
/// @param profile 0 = car, 1 = foot
/// @param error Error pointer for routing failures
/// @return Dictionary with keys: @"coordinates", @"distance", @"duration" or nil on error
- (nullable NSDictionary *)routeFrom:(CLLocationCoordinate2D)start
                                  to:(CLLocationCoordinate2D)end
                             profile:(NSInteger)profile
                               error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

