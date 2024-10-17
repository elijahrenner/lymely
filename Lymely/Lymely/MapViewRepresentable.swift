import SwiftUI
import UIKit
import MapboxMaps
import CoreLocation

/// A SwiftUI representation of a Mapbox map view.
struct MapViewRepresentable: UIViewRepresentable {
    /// The location manager that provides the user's current location.
    @ObservedObject var locationManager: LocationManager
    
    /// A flag to track whether the initial location has been set.
    @State private var didSetInitialLocation = false
    
    /// A coordinator class to manage the map view and its annotations.
    class Coordinator: NSObject {
        /// The annotation manager for the user's location marker.
        var locationAnnotationManager: PointAnnotationManager?
        /// The pulsing effect layer for the user's location.
        var pulsingLayer: CAShapeLayer?
        /// The image used for the user's location marker.
        var userMarkerImage: UIImage?
    }
    
    /// Creates and returns a new coordinator for the map view.
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    /// Creates and configures the Mapbox map view.
    /// - Parameter context: The context in which the map view is created.
    /// - Returns: A configured MapView instance.
    func makeUIView(context: Context) -> MapView {
        let mapView = MapView(frame: .zero)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        
        var gestureOptions = GestureOptions()
        gestureOptions.rotateEnabled = false
        mapView.gestures.options = gestureOptions
        
        let cameraOptions = CameraOptions(
            center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
            zoom: 2.5
        )
        mapView.mapboxMap.setCamera(to: cameraOptions)
        
        let southWest = CLLocationCoordinate2D(latitude: 24.7433195, longitude: -124.7844079)
        let northEast = CLLocationCoordinate2D(latitude: 49.3457868, longitude: -66.9513812)
        
        let cameraBoundsOptions = CameraBoundsOptions(
            bounds: CoordinateBounds(southwest: southWest, northeast: northEast),
            maxZoom: 10.0,
            minZoom: 2.5
        )
        
        do {
            try mapView.mapboxMap.setCameraBounds(with: cameraBoundsOptions)
        } catch {
            print("Error setting camera bounds: \(error)")
        }
        
        if let styleURL = URL(string: "mapbox://styles/elijahrenner/cm0x9y1u601vk01pw00ong646"),
           let styleURI = StyleURI(url: styleURL) {
            mapView.mapboxMap.loadStyle(styleURI) { error in
                if let error = error {
                    print("Failed to load style: \(error)")
                } else {
                    context.coordinator.locationAnnotationManager = mapView.annotations.makePointAnnotationManager()
                    if let userLocation = locationManager.userLocation {
                        self.updateUserLocationMarker(on: mapView, coordinator: context.coordinator, coordinate: userLocation)
                    }
                }
            }
        } else {
            mapView.mapboxMap.loadStyle(.streets)
        }
        
        return mapView
    }
    
    /// Updates the map view when the view's state changes.
    /// - Parameters:
    ///   - uiView: The map view to update.
    ///   - context: The context in which the update occurs.
    func updateUIView(_ uiView: MapView, context: Context) {
        guard let userLocation = locationManager.userLocation else { return }
        
        if !didSetInitialLocation {
            let cameraOptions = CameraOptions(center: userLocation, zoom: 7.0)
            uiView.mapboxMap.setCamera(to: cameraOptions)
            
            DispatchQueue.main.async {
                self.didSetInitialLocation = true
            }
        }
        
        updateUserLocationMarker(on: uiView, coordinator: context.coordinator, coordinate: userLocation)
    }
    
    /// Updates the user's location marker on the map.
    /// - Parameters:
    ///   - mapView: The map view to update.
    ///   - coordinator: The coordinator managing the map view.
    ///   - coordinate: The new coordinate for the user's location.
    private func updateUserLocationMarker(on mapView: MapView, coordinator: Coordinator, coordinate: CLLocationCoordinate2D) {
        guard let locationAnnotationManager = coordinator.locationAnnotationManager else {
            print("Annotation manager is not initialized yet. Retrying...")
            return
        }
        
        locationAnnotationManager.annotations.removeAll()
        
        var userLocationAnnotation = PointAnnotation(coordinate: coordinate)
        
        if let image = UIImage(named: "marker"),
           let resizedImage = resizeImage(image: image, targetSize: CGSize(width: 50, height: 50)) {
            userLocationAnnotation.image = .init(image: resizedImage, name: "userLocationMarker")
            coordinator.userMarkerImage = image
        } else if let systemImage = UIImage(systemName: "mappin.circle.fill") {
            let configuredSystemImage = systemImage.withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
            if let resizedSystemImage = resizeImage(image: configuredSystemImage, targetSize: CGSize(width: 50, height: 50)) {
                userLocationAnnotation.image = .init(image: resizedSystemImage, name: "defaultMarker")
                coordinator.userMarkerImage = configuredSystemImage
            }
        }
        
        locationAnnotationManager.annotations = [userLocationAnnotation]
        
        if coordinator.pulsingLayer == nil {
            addPulsingEffect(to: mapView, at: coordinate, coordinator: coordinator)
        } else {
            updatePulsingLayerPosition(coordinator.pulsingLayer!, mapView: mapView, coordinate: coordinate)
        }
        
        print("Location marker added at \(coordinate.latitude), \(coordinate.longitude)")
    }

    /// Adds a pulsing effect to the user's location marker.
    /// - Parameters:
    ///   - mapView: The map view to add the effect to.
    ///   - coordinate: The coordinate of the user's location.
    ///   - coordinator: The coordinator managing the map view.
    private func addPulsingEffect(to mapView: MapView, at coordinate: CLLocationCoordinate2D, coordinator: Coordinator) {
        let pulsingLayer = CAShapeLayer()
        
        let pulseDiameter: CGFloat = 60
        let pulseOrigin = CGPoint(x: -pulseDiameter / 2, y: -pulseDiameter / 2)
        
        let pulsePath = UIBezierPath(ovalIn: CGRect(origin: pulseOrigin, size: CGSize(width: pulseDiameter, height: pulseDiameter)))
        
        pulsingLayer.path = pulsePath.cgPath
        pulsingLayer.position = mapView.mapboxMap.point(for: coordinate)
        pulsingLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        pulsingLayer.opacity = 0.7
        pulsingLayer.name = "pulsingLayer"
        
        mapView.layer.addSublayer(pulsingLayer)
        
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.8
        animation.toValue = 2.0
        animation.duration = 1.5
        animation.repeatCount = .infinity
        animation.autoreverses = true
        
        pulsingLayer.add(animation, forKey: "pulseAnimation")
        
        coordinator.pulsingLayer = pulsingLayer
        mapView.mapboxMap.onEvery(event: .cameraChanged) { _ in
            self.updatePulsingLayerPosition(pulsingLayer, mapView: mapView, coordinate: coordinate)
        }
    }
    
    /// Updates the position of the pulsing effect layer.
    /// - Parameters:
    ///   - pulsingLayer: The pulsing effect layer to update.
    ///   - mapView: The map view containing the layer.
    ///   - coordinate: The new coordinate for the layer.
    private func updatePulsingLayerPosition(_ pulsingLayer: CAShapeLayer, mapView: MapView, coordinate: CLLocationCoordinate2D) {
        let screenPoint = mapView.mapboxMap.point(for: coordinate)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pulsingLayer.position = screenPoint
        CATransaction.commit()
    }
    
    /// Resizes an image to a target size.
    /// - Parameters:
    ///   - image: The image to resize.
    ///   - targetSize: The desired size for the image.
    /// - Returns: The resized image, or nil if resizing fails.
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size

        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)

        let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }
}

/// A view that displays a map, with the ability to toggle between a small and fullscreen view.
struct FullscreenMapView: View {
    /// The location manager that provides the user's current location.
    @StateObject private var locationManager = LocationManager()
    /// A flag to determine if the map is in fullscreen mode.
    @State private var isFullscreen: Bool = false
    
    var body: some View {
        ZStack {
            if isFullscreen {
                MapViewRepresentable(locationManager: locationManager)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        Button(action: {
                            withAnimation {
                                isFullscreen.toggle()
                            }
                        }) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .padding(8)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                                .shadow(radius: 1)
                        }
                        .padding(.trailing, 30)
                        .padding(.top, 10),
                        alignment: .topTrailing
                    )
            } else {
                ZStack(alignment: .topTrailing) {
                    MapViewRepresentable(locationManager: locationManager)
                        .frame(height: 300)
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    
                    Button(action: {
                        withAnimation {
                            isFullscreen.toggle()
                        }
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .padding(6)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(8)
                            .shadow(radius: 1)
                    }
                    .padding(.trailing, 30)
                    .padding(.top, 10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            FullscreenMapViewContent(isFullscreen: $isFullscreen, locationManager: locationManager)
        }
    }
}

/// A view that displays the map in fullscreen mode.
struct FullscreenMapViewContent: View {
    /// A binding to the fullscreen state of the map.
    @Binding var isFullscreen: Bool
    /// The location manager that provides the user's current location.
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapViewRepresentable(locationManager: locationManager)
                .edgesIgnoringSafeArea(.all)

            Button(action: {
                isFullscreen = false
            }) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .padding(8)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(8)
                    .shadow(radius: 1)
            }
            .padding(.trailing, 30)
            .padding(.top, 10)
        }
    }
}
