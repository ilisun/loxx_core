import Foundation
import CoreLocation

/// Routing profile determining which roads/paths are accessible
public enum LoxxRoutingProfile {
    /// Car routing - uses motorways, roads, respects oneway restrictions
    case car
    
    /// Pedestrian routing - uses footways, paths, avoids motorways
    case foot
}

/// Calculated route between two points
public struct LoxxRoute {
    /// Route polyline as array of coordinates
    public let coordinates: [CLLocationCoordinate2D]
    
    /// Total distance in meters
    public let distance: CLLocationDistance
    
    /// Estimated travel duration in seconds
    public let duration: TimeInterval
    
    /// Human-readable distance string (e.g. "11.3 km")
    public var distanceFormatted: String {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 1
        let meters = Measurement(value: distance, unit: UnitLength.meters)
        return formatter.string(from: meters)
    }
    
    /// Human-readable duration string (e.g. "5 min" or "1 hr 16 min")
    public var durationFormatted: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    /// Average speed in km/h
    public var averageSpeed: Double {
        guard duration > 0 else { return 0 }
        return (distance / 1000) / (duration / 3600)
    }
}

/// Router configuration options
public struct LoxxRouterOptions {
    /// Tile zoom level (default: 14, ~4x4 km tiles)
    public var tileZoom: Int = 14
    
    /// Number of tiles to keep in memory cache (default: 128)
    public var tileCacheCapacity: Int = 128
    
    public init() {}
}

/// Errors that can occur during routing
public enum LoxxRouterError: LocalizedError {
    /// Database file not found at specified path
    case databaseNotFound
    
    /// No route found between the specified points
    case noRoute
    
    /// No map data available for the requested region
    case noTileData
    
    /// Database file is corrupted or invalid
    case dataCorrupted
    
    /// Internal routing engine error
    case internalError(String)
    
    public var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "Routing database not found at specified path"
        case .noRoute:
            return "No route found between specified coordinates"
        case .noTileData:
            return "No map data available for this region"
        case .dataCorrupted:
            return "Routing database is corrupted or invalid format"
        case .internalError(let message):
            return "Internal routing error: \(message)"
        }
    }
}

/// Offline routing engine powered by OpenStreetMap data
///
/// `LoxxRouter` provides fast offline routing for car and pedestrian navigation.
/// It uses pre-processed OpenStreetMap data stored in `.routingdb` files.
///
/// ## Usage
///
/// ```swift
/// // Initialize with bundled database
/// let router = try LoxxRouter.bundled(resourceName: "arkhangelsk/routing")
///
/// // Calculate route
/// let start = CLLocationCoordinate2D(latitude: 64.589700, longitude: 40.507520)
/// let end = CLLocationCoordinate2D(latitude: 64.541891, longitude: 40.539648)
/// let route = try await router.calculateRoute(from: start, to: end, profile: .car)
///
/// print("Distance: \(route.distanceFormatted), Duration: \(route.durationFormatted)")
/// ```
public final class LoxxRouter {
    
    // Private C++ bridge implementation (hidden from public API)
    private let bridge: LoxxRouterBridge
    
    /// Initialize router with database file path
    ///
    /// - Parameters:
    ///   - databasePath: Full path to `.routingdb` file
    ///   - options: Router configuration options
    /// - Throws: `LoxxRouterError` if database cannot be opened or is invalid
    public init(databasePath: String, options: LoxxRouterOptions = LoxxRouterOptions()) throws {
        guard FileManager.default.fileExists(atPath: databasePath) else {
            throw LoxxRouterError.databaseNotFound
        }
        
        do {
            self.bridge = try LoxxRouterBridge(path: databasePath, zoom: options.tileZoom, cacheCapacity: options.tileCacheCapacity)
        } catch let error as LoxxRouterError {
            throw error
        } catch {
            throw LoxxRouterError.internalError(error.localizedDescription)
        }
    }
    
    /// Calculate route between two coordinates (synchronous)
    ///
    /// - Parameters:
    ///   - start: Starting coordinate
    ///   - end: Destination coordinate
    ///   - profile: Routing profile (car or foot)
    /// - Returns: Calculated route with polyline, distance and duration
    /// - Throws: `LoxxRouterError` if routing fails
    ///
    /// - Note: This method blocks the calling thread. Consider using async version for better performance.
    public func calculateRoute(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        profile: LoxxRoutingProfile = .car
    ) throws -> LoxxRoute {
        try bridge.route(from: start, to: end, profile: profile)
    }
    
    /// Calculate route asynchronously with completion handler
    ///
    /// - Parameters:
    ///   - start: Starting coordinate
    ///   - end: Destination coordinate
    ///   - profile: Routing profile (car or foot)
    ///   - completion: Completion handler called on main thread with result
    public func calculateRoute(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        profile: LoxxRoutingProfile = .car,
        completion: @escaping (Result<LoxxRoute, LoxxRouterError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError("Router deallocated")))
                }
                return
            }
            
            let result = Result { try self.calculateRoute(from: start, to: end, profile: profile) }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}

// MARK: - Async/Await Support (iOS 15+)

@available(iOS 15.0, macCatalyst 15.0, *)
extension LoxxRouter {
    /// Calculate route using Swift concurrency (async/await)
    ///
    /// - Parameters:
    ///   - start: Starting coordinate
    ///   - end: Destination coordinate
    ///   - profile: Routing profile (car or foot)
    /// - Returns: Calculated route
    /// - Throws: `LoxxRouterError` if routing fails
    ///
    /// ## Example
    /// ```swift
    /// let route = try await router.calculateRoute(
    ///     from: startCoordinate,
    ///     to: endCoordinate,
    ///     profile: .car
    /// )
    /// ```
    public func calculateRoute(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        profile: LoxxRoutingProfile = .car
    ) async throws -> LoxxRoute {
        try await withCheckedThrowingContinuation { continuation in
            calculateRoute(from: start, to: end, profile: profile) { result in
                continuation.resume(with: result)
            }
        }
    }
}

// MARK: - Convenience Initializers

public extension LoxxRouter {
    /// Initialize router with database from app bundle
    ///
    /// - Parameters:
    ///   - resourceName: Database filename without .routingdb extension
    ///   - bundle: Bundle containing the database (default: main bundle)
    ///   - options: Router configuration options
    /// - Returns: Configured router instance
    /// - Throws: `LoxxRouterError.databaseNotFound` if file not in bundle
    ///
    /// ## Example
    /// ```swift
    /// // Database in bundle: Resources/arkhangelsk/routing.routingdb
    /// let router = try LoxxRouter.bundled(resourceName: "arkhangelsk/routing")
    /// ```
    static func bundled(
        resourceName: String = "routing",
        bundle: Bundle = .main,
        options: LoxxRouterOptions = LoxxRouterOptions()
    ) throws -> LoxxRouter {
        // Handle paths like "arkhangelsk/routing"
        let components = resourceName.split(separator: "/").map(String.init)
        let name = components.last ?? resourceName
        let subdirectory = components.count > 1 ? components.dropLast().joined(separator: "/") : nil
        
        guard let path = bundle.path(forResource: name, ofType: "routingdb", inDirectory: subdirectory) else {
            throw LoxxRouterError.databaseNotFound
        }
        
        return try LoxxRouter(databasePath: path, options: options)
    }
    
    /// Initialize router with database in Documents directory
    ///
    /// - Parameters:
    ///   - filename: Database filename (with or without .routingdb extension)
    ///   - options: Router configuration options
    /// - Returns: Configured router instance
    /// - Throws: `LoxxRouterError.databaseNotFound` if file not found
    ///
    /// ## Example
    /// ```swift
    /// // Use downloaded database from Documents
    /// let router = try LoxxRouter.documents(filename: "moscow.routingdb")
    /// ```
    static func documents(
        filename: String,
        options: LoxxRouterOptions = LoxxRouterOptions()
    ) throws -> LoxxRouter {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbFilename = filename.hasSuffix(".routingdb") ? filename : "\(filename).routingdb"
        let databaseURL = documentsURL.appendingPathComponent(dbFilename)
        
        return try LoxxRouter(databasePath: databaseURL.path, options: options)
    }
}

// MARK: - CLLocation Integration

public extension LoxxRouter {
    /// Calculate route from CLLocation
    ///
    /// - Parameters:
    ///   - location: Starting location
    ///   - destination: Destination coordinate
    ///   - profile: Routing profile
    /// - Returns: Calculated route
    /// - Throws: `LoxxRouterError` if routing fails
    func calculateRoute(
        from location: CLLocation,
        to destination: CLLocationCoordinate2D,
        profile: LoxxRoutingProfile = .car
    ) throws -> LoxxRoute {
        try calculateRoute(from: location.coordinate, to: destination, profile: profile)
    }
    
    /// Calculate route between two CLLocations
    ///
    /// - Parameters:
    ///   - start: Starting location
    ///   - end: Destination location
    ///   - profile: Routing profile
    /// - Returns: Calculated route
    /// - Throws: `LoxxRouterError` if routing fails
    func calculateRoute(
        from start: CLLocation,
        to end: CLLocation,
        profile: LoxxRoutingProfile = .car
    ) throws -> LoxxRoute {
        try calculateRoute(from: start.coordinate, to: end.coordinate, profile: profile)
    }
}

