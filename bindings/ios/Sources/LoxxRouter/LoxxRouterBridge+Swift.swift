import Foundation
import CoreLocation
import LoxxRouterCore

/// Internal Swift extension to bridge Objective-C++ to pure Swift API
extension LoxxRouterBridge {
    
    /// Calculate route (Swift-friendly wrapper)
    func route(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        profile: LoxxRoutingProfile
    ) throws -> LoxxRoute {
        var error: NSError?
        let profileInt: Int = (profile == .car) ? 0 : 1
        
        guard let result = self.route(from: start, to: end, profile: profileInt, error: &error) else {
            // Convert NSError to LoxxRouterError
            if let nsError = error {
                throw convertError(nsError)
            }
            throw LoxxRouterError.internalError("Unknown error")
        }
        
        // Extract coordinates
        guard let coordValues = result["coordinates"] as? [NSValue] else {
            throw LoxxRouterError.internalError("Invalid coordinates in result")
        }
        
        let coordinates = coordValues.compactMap { value -> CLLocationCoordinate2D? in
            var coordinate = CLLocationCoordinate2D()
            value.getValue(&coordinate)
            return coordinate
        }
        
        // Extract distance and duration
        guard let distance = result["distance"] as? Double,
              let duration = result["duration"] as? Double else {
            throw LoxxRouterError.internalError("Invalid distance or duration in result")
        }
        
        return LoxxRoute(
            coordinates: coordinates,
            distance: distance,
            duration: duration
        )
    }
    
    /// Convert NSError from bridge to Swift LoxxRouterError
    private func convertError(_ nsError: NSError) -> LoxxRouterError {
        let message = nsError.localizedDescription
        
        switch nsError.code {
        case 1: // LoxxRouterErrorCodeDatabaseNotFound
            return .databaseNotFound
        case 2: // LoxxRouterErrorCodeNoRoute
            return .noRoute
        case 3: // LoxxRouterErrorCodeNoTile
            return .noTileData
        case 4: // LoxxRouterErrorCodeDataCorrupted
            return .dataCorrupted
        default: // LoxxRouterErrorCodeInternalError
            return .internalError(message)
        }
    }
}

