import XCTest
import CoreLocation
@testable import LoxxRouter

final class LoxxRouterTests: XCTestCase {
    
    var router: LoxxRouter?
    
    override func setUp() {
        super.setUp()
        
        // Try to load test database from bundle
        // Note: In real tests, you would include a small test.routingdb file
        do {
            router = try LoxxRouter.bundled(resourceName: "test", bundle: Bundle.module)
        } catch {
            // If test database not available, tests will be skipped
            print("Warning: Test database not available: \(error)")
        }
    }
    
    override func tearDown() {
        router = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitWithValidPath() throws {
        // Test initialization with valid path
        // This requires a test database in Resources/
        guard let _ = router else {
            throw XCTSkip("Test database not available")
        }
        XCTAssertNotNil(router)
    }
    
    func testInitWithInvalidPath() {
        // Test that initialization fails with invalid path
        XCTAssertThrowsError(try LoxxRouter(databasePath: "/invalid/path.routingdb")) { error in
            XCTAssertTrue(error is LoxxRouterError)
            if let routerError = error as? LoxxRouterError {
                XCTAssertEqual(routerError, LoxxRouterError.databaseNotFound)
            }
        }
    }
    
    func testBundledInitializer() {
        // Test bundled initializer
        XCTAssertNoThrow(try LoxxRouter.bundled(resourceName: "test", bundle: Bundle.module))
    }
    
    // MARK: - Route Calculation Tests
    
    func testCalculateCarRoute() throws {
        guard let router = router else {
            throw XCTSkip("Test database not available")
        }
        
        // Coordinates in test region (adjust based on your test data)
        let start = CLLocationCoordinate2D(latitude: 64.589700, longitude: 40.507520)
        let end = CLLocationCoordinate2D(latitude: 64.541891, longitude: 40.539648)
        
        let route = try router.calculateRoute(from: start, to: end, profile: .car)
        
        XCTAssertFalse(route.coordinates.isEmpty, "Route should have coordinates")
        XCTAssertGreaterThan(route.distance, 0, "Route distance should be positive")
        XCTAssertGreaterThan(route.duration, 0, "Route duration should be positive")
        XCTAssertEqual(route.coordinates.first?.latitude, start.latitude, accuracy: 0.001)
        XCTAssertEqual(route.coordinates.last?.latitude, end.latitude, accuracy: 0.001)
    }
    
    func testCalculateFootRoute() throws {
        guard let router = router else {
            throw XCTSkip("Test database not available")
        }
        
        let start = CLLocationCoordinate2D(latitude: 64.589700, longitude: 40.507520)
        let end = CLLocationCoordinate2D(latitude: 64.541891, longitude: 40.539648)
        
        let route = try router.calculateRoute(from: start, to: end, profile: .foot)
        
        XCTAssertFalse(route.coordinates.isEmpty)
        XCTAssertGreaterThan(route.distance, 0)
        XCTAssertGreaterThan(route.duration, 0)
    }
    
    func testCarVsFootProfileDifference() throws {
        guard let router = router else {
            throw XCTSkip("Test database not available")
        }
        
        let start = CLLocationCoordinate2D(latitude: 64.589700, longitude: 40.507520)
        let end = CLLocationCoordinate2D(latitude: 64.541891, longitude: 40.539648)
        
        let carRoute = try router.calculateRoute(from: start, to: end, profile: .car)
        let footRoute = try router.calculateRoute(from: start, to: end, profile: .foot)
        
        // Foot route should take significantly longer
        XCTAssertGreaterThan(footRoute.duration, carRoute.duration * 3, "Foot route should be much slower")
    }
    
    // MARK: - Async Tests (iOS 15+)
    
    @available(iOS 15.0, *)
    func testCalculateRouteAsync() async throws {
        guard let router = router else {
            throw XCTSkip("Test database not available")
        }
        
        let start = CLLocationCoordinate2D(latitude: 64.589700, longitude: 40.507520)
        let end = CLLocationCoordinate2D(latitude: 64.541891, longitude: 40.539648)
        
        let route = try await router.calculateRoute(from: start, to: end, profile: .car)
        
        XCTAssertFalse(route.coordinates.isEmpty)
        XCTAssertGreaterThan(route.distance, 0)
    }
    
    // MARK: - LoxxRoute Tests
    
    func testRouteFormatting() {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 64.5, longitude: 40.5),
            CLLocationCoordinate2D(latitude: 64.6, longitude: 40.6)
        ]
        
        let route = LoxxRoute(
            coordinates: coordinates,
            distance: 11307.52,
            duration: 298.28
        )
        
        XCTAssertFalse(route.distanceFormatted.isEmpty)
        XCTAssertFalse(route.durationFormatted.isEmpty)
        XCTAssertGreaterThan(route.averageSpeed, 0)
    }
    
    func testRouteAverageSpeed() {
        let route = LoxxRoute(
            coordinates: [],
            distance: 10000, // 10 km
            duration: 600    // 10 minutes
        )
        
        let expectedSpeed = 60.0 // km/h
        XCTAssertEqual(route.averageSpeed, expectedSpeed, accuracy: 0.1)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCoordinates() throws {
        guard let router = router else {
            throw XCTSkip("Test database not available")
        }
        
        // Coordinates outside database region
        let start = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let end = CLLocationCoordinate2D(latitude: 1, longitude: 1)
        
        XCTAssertThrowsError(try router.calculateRoute(from: start, to: end, profile: .car)) { error in
            // Should throw either noTileData or noRoute error
            XCTAssertTrue(error is LoxxRouterError)
        }
    }
    
    // MARK: - CLLocation Integration Tests
    
    func testCalculateRouteFromCLLocation() throws {
        guard let router = router else {
            throw XCTSkip("Test database not available")
        }
        
        let startLocation = CLLocation(latitude: 64.589700, longitude: 40.507520)
        let endCoord = CLLocationCoordinate2D(latitude: 64.541891, longitude: 40.539648)
        
        let route = try router.calculateRoute(from: startLocation, to: endCoord, profile: .car)
        
        XCTAssertFalse(route.coordinates.isEmpty)
    }
    
    // MARK: - Completion Handler Tests
    
    func testCalculateRouteWithCompletionHandler() {
        guard let router = router else {
            XCTSkip("Test database not available")
            return
        }
        
        let expectation = expectation(description: "Route calculation")
        let start = CLLocationCoordinate2D(latitude: 64.589700, longitude: 40.507520)
        let end = CLLocationCoordinate2D(latitude: 64.541891, longitude: 40.539648)
        
        router.calculateRoute(from: start, to: end, profile: .car) { result in
            switch result {
            case .success(let route):
                XCTAssertFalse(route.coordinates.isEmpty)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Route calculation failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

