import SwiftUI
import MapLibre
import CoreLocation
import LoxxRouter

struct ContentView: View {
    @StateObject private var viewModel = MapViewModel()
    
    var body: some View {
        ZStack {
            // Map view
            MapLibreMapView(route: $viewModel.route)
                .ignoresSafeArea()
            
            VStack {
                // Top controls
                HStack {
                    Picker("Profile", selection: $viewModel.selectedProfile) {
                        Text("🚗 Car").tag(LoxxRoutingProfile.car)
                        Text("🚶 Foot").tag(LoxxRoutingProfile.foot)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }
                .background(.regularMaterial)
                
                Spacer()
                
                // Route info card
                if let route = viewModel.route {
                    RouteInfoCard(route: route, profile: viewModel.selectedProfile)
                        .padding()
                }
                
                // Bottom controls
                VStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView("Calculating route...")
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        Task {
                            await viewModel.buildRoute()
                        }
                    } label: {
                        Label("Build Route", systemImage: "map.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)
                    
                    if viewModel.route != nil {
                        Button(role: .destructive) {
                            viewModel.clearRoute()
                        } label: {
                            Label("Clear Route", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            
            // Error alert
            if let error = viewModel.error {
                VStack {
                    Spacer()
                    ErrorBanner(message: error)
                        .padding()
                        .onTapGesture {
                            viewModel.error = nil
                        }
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class MapViewModel: ObservableObject {
    @Published var route: LoxxRoute?
    @Published var selectedProfile: LoxxRoutingProfile = .car
    @Published var isLoading = false
    @Published var error: String?
    
    private lazy var router: LoxxRouter? = {
        do {
            return try LoxxRouter.bundled(resourceName: "arkhangelsk/routing")
        } catch {
            self.error = "Failed to load routing database: \(error.localizedDescription)"
            return nil
        }
    }()
    
    // Example coordinates in Arkhangelsk
    private let startCoord = CLLocationCoordinate2D(latitude: 64.589700, longitude: 40.507520)
    private let endCoord = CLLocationCoordinate2D(latitude: 64.541891, longitude: 40.539648)
    
    func buildRoute() async {
        guard let router = router else {
            error = "Router not initialized"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let calculatedRoute = try await router.calculateRoute(
                from: startCoord,
                to: endCoord,
                profile: selectedProfile
            )
            
            route = calculatedRoute
            
        } catch let routerError as LoxxRouterError {
            error = routerError.localizedDescription
            
        } catch {
            error = "Unexpected error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func clearRoute() {
        route = nil
    }
}

// MARK: - MapLibre View

struct MapLibreMapView: UIViewRepresentable {
    @Binding var route: LoxxRoute?
    
    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView()
        mapView.delegate = context.coordinator
        
        // Set to OpenFreeMap style
        mapView.styleURL = URL(string: "https://tiles.openfreemap.org/styles/liberty")
        
        // Center on Arkhangelsk
        mapView.centerCoordinate = CLLocationCoordinate2D(latitude: 64.56, longitude: 40.52)
        mapView.zoomLevel = 11
        
        return mapView
    }
    
    func updateUIView(_ mapView: MLNMapView, context: Context) {
        // Update route when it changes
        context.coordinator.updateRoute(mapView: mapView, route: route)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapLibreMapView
        
        init(_ parent: MapLibreMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // Style loaded, ready to add route
            if let route = parent.route {
                updateRoute(mapView: mapView, route: route)
            }
        }
        
        func updateRoute(mapView: MLNMapView, route: LoxxRoute?) {
            guard let style = mapView.style else { return }
            
            // Remove existing route
            if let existingCasing = style.layer(withIdentifier: "route-casing") {
                style.removeLayer(existingCasing)
            }
            if let existingLine = style.layer(withIdentifier: "route-line") {
                style.removeLayer(existingLine)
            }
            if let existingSource = style.source(withIdentifier: "route-source") {
                style.removeSource(existingSource)
            }
            
            // Add new route if available
            if let route = route {
                route.addToMapStyleWithCasing(
                    style,
                    identifier: "route",
                    lineColor: .systemBlue,
                    lineWidth: 5,
                    casingColor: .white,
                    casingWidth: 7
                )
                
                // Fit camera to route
                mapView.showRoute(route, edgePadding: UIEdgeInsets(top: 150, left: 50, bottom: 250, right: 50))
            }
        }
    }
}

// MARK: - Route Info Card

struct RouteInfoCard: View {
    let route: LoxxRoute
    let profile: LoxxRoutingProfile
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: profile == .car ? "car.fill" : "figure.walk")
                    .font(.title)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.distanceFormatted)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(route.durationFormatted)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(route.averageSpeed))")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("km/h")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                Label("\(route.coordinates.count) points", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Label(profile == .car ? "Car Route" : "Pedestrian Route", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
            Text(message)
                .font(.callout)
            
            Spacer()
            
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

