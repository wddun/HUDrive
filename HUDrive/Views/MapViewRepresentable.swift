//
//  MapViewRepresentable.swift
//  HUDrive
//

import SwiftUI
import MapKit

struct MapViewRepresentable: UIViewRepresentable {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var navigationManager: NavigationManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Dark map style
        let config = MKStandardMapConfiguration(emphasisStyle: .muted)
        config.pointOfInterestFilter = .excludingAll
        config.showsTraffic = false
        mapView.preferredConfiguration = config
        
        // Map settings
        mapView.overrideUserInterfaceStyle = .dark
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        
        // User tracking with heading
        mapView.userTrackingMode = .followWithHeading
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update route overlay
        let existingOverlays = mapView.overlays
        
        if let route = navigationManager.route {
            // Only update if route changed
            let hasRoute = existingOverlays.contains { overlay in
                guard let polyline = overlay as? MKPolyline else { return false }
                return polyline.pointCount == route.polyline.pointCount
            }
            
            if !hasRoute {
                mapView.removeOverlays(existingOverlays)
                mapView.addOverlay(route.polyline, level: .aboveRoads)
                
                // Set the camera to follow user with heading during navigation
                mapView.userTrackingMode = .followWithHeading
                
                // Set a nice camera angle
                if let userLocation = locationManager.currentLocation {
                    let camera = MKMapCamera(
                        lookingAtCenter: userLocation.coordinate,
                        fromDistance: 1000,
                        pitch: 45,
                        heading: locationManager.heading?.trueHeading ?? 0
                    )
                    mapView.setCamera(camera, animated: true)
                }
            }
        } else if !existingOverlays.isEmpty {
            mapView.removeOverlays(existingOverlays)
        }
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                // Bright cyan/white route for maximum HUD visibility
                renderer.strokeColor = UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.9)
                renderer.lineWidth = 8
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Use default for user location
            if annotation is MKUserLocation { return nil }
            return nil
        }
    }
}
