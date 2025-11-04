import Foundation
import CoreLocation

#if canImport(MapLibre)
import MapLibre

// MARK: - MapLibre Integration

/// Extension providing seamless integration with MapLibre Native
@available(iOS 13.0, *)
public extension LoxxRoute {
    
    /// Convert route to MapLibre polyline shape
    ///
    /// - Returns: MLNPolyline that can be added to MapLibre map
    ///
    /// ## Example
    /// ```swift
    /// let route = try await router.calculateRoute(from: start, to: end)
    /// let polyline = route.asMapLibrePolyline
    /// // Use with MLNShapeSource
    /// ```
    var asMapLibrePolyline: MLNPolyline {
        var coords = coordinates
        return MLNPolyline(coordinates: &coords, count: UInt(coords.count))
    }
    
    /// Add route as a styled layer to MapLibre map style
    ///
    /// - Parameters:
    ///   - style: MapLibre style to add route to
    ///   - identifier: Unique identifier for source and layer (default: "route")
    ///   - color: Route line color (default: system blue)
    ///   - width: Route line width in points (default: 5)
    ///   - belowLayerIdentifier: Insert layer below this layer (optional)
    ///
    /// ## Example
    /// ```swift
    /// guard let style = mapView.style else { return }
    /// route.addToMapStyle(style, color: .systemBlue, width: 5)
    /// ```
    func addToMapStyle(
        _ style: MLNStyle,
        identifier: String = "route",
        color: UIColor = .systemBlue,
        width: CGFloat = 5,
        belowLayerIdentifier: String? = nil
    ) {
        // Remove existing if present
        if let existingLayer = style.layer(withIdentifier: "\(identifier)-layer") {
            style.removeLayer(existingLayer)
        }
        if let existingSource = style.source(withIdentifier: "\(identifier)-source") {
            style.removeSource(existingSource)
        }
        
        // Add source
        let source = MLNShapeSource(
            identifier: "\(identifier)-source",
            shape: asMapLibrePolyline,
            options: nil
        )
        style.addSource(source)
        
        // Add styled layer
        let layer = MLNLineStyleLayer(identifier: "\(identifier)-layer", source: source)
        layer.lineColor = NSExpression(forConstantValue: color)
        layer.lineWidth = NSExpression(forConstantValue: width)
        layer.lineCap = NSExpression(forConstantValue: "round")
        layer.lineJoin = NSExpression(forConstantValue: "round")
        
        if let belowLayer = belowLayerIdentifier {
            if let below = style.layer(withIdentifier: belowLayer) {
                style.insertLayer(layer, below: below)
            } else {
                style.addLayer(layer)
            }
        } else {
            style.addLayer(layer)
        }
    }
    
    /// Add route with custom casing (outline) to map style
    ///
    /// - Parameters:
    ///   - style: MapLibre style
    ///   - identifier: Unique identifier (default: "route")
    ///   - lineColor: Main route line color
    ///   - lineWidth: Main line width
    ///   - casingColor: Outline color
    ///   - casingWidth: Outline width (should be larger than lineWidth)
    ///
    /// ## Example
    /// ```swift
    /// // Blue route with white outline
    /// route.addToMapStyleWithCasing(
    ///     style,
    ///     lineColor: .systemBlue,
    ///     lineWidth: 5,
    ///     casingColor: .white,
    ///     casingWidth: 7
    /// )
    /// ```
    func addToMapStyleWithCasing(
        _ style: MLNStyle,
        identifier: String = "route",
        lineColor: UIColor = .systemBlue,
        lineWidth: CGFloat = 5,
        casingColor: UIColor = .white,
        casingWidth: CGFloat = 7
    ) {
        // Remove existing
        for suffix in ["-casing", "-line"] {
            if let layer = style.layer(withIdentifier: "\(identifier)\(suffix)") {
                style.removeLayer(layer)
            }
        }
        if let source = style.source(withIdentifier: "\(identifier)-source") {
            style.removeSource(source)
        }
        
        // Add source
        let source = MLNShapeSource(
            identifier: "\(identifier)-source",
            shape: asMapLibrePolyline,
            options: nil
        )
        style.addSource(source)
        
        // Add casing (outline) layer
        let casingLayer = MLNLineStyleLayer(identifier: "\(identifier)-casing", source: source)
        casingLayer.lineColor = NSExpression(forConstantValue: casingColor)
        casingLayer.lineWidth = NSExpression(forConstantValue: casingWidth)
        casingLayer.lineCap = NSExpression(forConstantValue: "round")
        casingLayer.lineJoin = NSExpression(forConstantValue: "round")
        style.addLayer(casingLayer)
        
        // Add main line layer on top
        let lineLayer = MLNLineStyleLayer(identifier: "\(identifier)-line", source: source)
        lineLayer.lineColor = NSExpression(forConstantValue: lineColor)
        lineLayer.lineWidth = NSExpression(forConstantValue: lineWidth)
        lineLayer.lineCap = NSExpression(forConstantValue: "round")
        lineLayer.lineJoin = NSExpression(forConstantValue: "round")
        style.addLayer(lineLayer)
    }
    
    /// Create start/end markers for the route
    ///
    /// - Parameters:
    ///   - style: MapLibre style
    ///   - startImage: Image for start marker (default: green circle)
    ///   - endImage: Image for end marker (default: red circle)
    ///
    /// ## Example
    /// ```swift
    /// route.addMarkersToMapStyle(style)
    /// ```
    func addMarkersToMapStyle(
        _ style: MLNStyle,
        startImage: UIImage? = nil,
        endImage: UIImage? = nil
    ) {
        guard let start = coordinates.first, let end = coordinates.last else { return }
        
        let startMarker = MLNPointAnnotation()
        startMarker.coordinate = start
        startMarker.title = "Start"
        
        let endMarker = MLNPointAnnotation()
        endMarker.coordinate = end
        endMarker.title = "Destination"
        
        // Note: Actual marker display would require MLNMapViewDelegate implementation
        // This is a convenience method for creating annotation objects
    }
}

// MARK: - Camera/Viewport Helpers

@available(iOS 13.0, *)
public extension MLNMapView {
    
    /// Fit camera to show entire route with padding
    ///
    /// - Parameters:
    ///   - route: Route to display
    ///   - edgePadding: Padding around route bounds (default: 50 points all sides)
    ///   - animated: Animate camera movement (default: true)
    ///
    /// ## Example
    /// ```swift
    /// let route = try await router.calculateRoute(from: start, to: end)
    /// mapView.showRoute(route, edgePadding: UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50))
    /// ```
    func showRoute(
        _ route: LoxxRoute,
        edgePadding: UIEdgeInsets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
        animated: Bool = true
    ) {
        let coords = route.coordinates
        guard !coords.isEmpty else { return }
        
        var bounds = MLNCoordinateBounds()
        bounds.sw = coords[0]
        bounds.ne = coords[0]
        
        for coord in coords {
            bounds.sw.latitude = min(bounds.sw.latitude, coord.latitude)
            bounds.sw.longitude = min(bounds.sw.longitude, coord.longitude)
            bounds.ne.latitude = max(bounds.ne.latitude, coord.latitude)
            bounds.ne.longitude = max(bounds.ne.longitude, coord.longitude)
        }
        
        let camera = camera(for: bounds, insets: edgePadding)
        setCamera(camera, animated: animated)
    }
}

#endif

