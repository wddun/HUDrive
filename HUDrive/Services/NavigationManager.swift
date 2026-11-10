//
//  NavigationManager.swift
//  HUDrive
//

import Foundation
import MapKit
import Combine

class NavigationManager: ObservableObject {
    
    // MARK: - Published State
    @Published var route: MKRoute?
    @Published var steps: [MKRoute.Step] = []
    @Published var currentStepIndex: Int = 0
    @Published var distanceToNextManeuver: CLLocationDistance = 0
    @Published var eta: Date?
    @Published var remainingDistance: CLLocationDistance = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var isNavigating: Bool = false
    @Published var isCalculatingRoute: Bool = false
    @Published var destination: MKMapItem?
    @Published var errorMessage: String?
    /// Set when the user adds a stop mid-route. After arriving at the stop, navigate here.
    @Published var pendingDestination: MKMapItem?
    
    // MARK: - Dependencies
    private let locationManager: LocationManager
    let voiceGuidance: VoiceGuidanceService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    private let stepAdvanceThreshold: CLLocationDistance = 40 // meters
    private let rerouteThreshold: CLLocationDistance = 100 // meters off route
    private var lastRerouteTime: Date?
    private let rerouteCooldown: TimeInterval = 15 // seconds between reroutes
    
    var currentStep: MKRoute.Step? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
    
    var nextStep: MKRoute.Step? {
        let nextIndex = currentStepIndex + 1
        guard nextIndex < steps.count else { return nil }
        return steps[nextIndex]
    }
    
    // MARK: - Init
    
    init(locationManager: LocationManager, voiceGuidance: VoiceGuidanceService) {
        self.locationManager = locationManager
        self.voiceGuidance = voiceGuidance
        
        setupLocationTracking()
    }
    
    // MARK: - Navigation Control
    
    func startNavigation(to mapItem: MKMapItem) {
        destination = mapItem
        isNavigating = true
        locationManager.setNavigationAccuracy()
        calculateRoute(to: mapItem)
    }
    
    func stopNavigation() {
        isNavigating = false
        route = nil
        steps = []
        currentStepIndex = 0
        distanceToNextManeuver = 0
        eta = nil
        remainingDistance = 0
        remainingTime = 0
        destination = nil
        errorMessage = nil
        lastRerouteTime = nil
        voiceGuidance.reset()
        locationManager.setIdleAccuracy()
    }
    
    func recalculateRoute() {
        guard let dest = destination else { return }
        calculateRoute(to: dest)
    }

    /// Add an intermediate stop. Saves the current destination as pending,
    /// then navigates to the stop. When the user ends navigation at the stop,
    /// pendingDestination will hold the original final destination.
    func addStop(_ stop: MKMapItem) {
        if destination != nil {
            pendingDestination = destination
        }
        startNavigation(to: stop)
    }
    
    // MARK: - Route Calculation
    
    private func calculateRoute(to mapItem: MKMapItem) {
        guard locationManager.currentLocation != nil else {
            errorMessage = "Unable to determine current location"
            return
        }
        
        isCalculatingRoute = true
        errorMessage = nil
        
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = mapItem
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isCalculatingRoute = false
                
                if let error = error {
                    self.errorMessage = "Route error: \(error.localizedDescription)"
                    return
                }
                
                guard let route = response?.routes.first else {
                    self.errorMessage = "No route found"
                    return
                }
                
                self.route = route
                // Filter out steps with empty instructions (usually the first "depart" step)
                self.steps = route.steps.filter { !$0.instructions.isEmpty }
                self.currentStepIndex = 0
                self.eta = route.expectedTravelTime > 0
                    ? Date().addingTimeInterval(route.expectedTravelTime)
                    : nil
                self.remainingDistance = route.distance
                self.remainingTime = route.expectedTravelTime
                
                // Announce first step
                if let firstStep = self.steps.first {
                    self.distanceToNextManeuver = firstStep.distance
                    self.voiceGuidance.announceRouteStart(
                        instruction: firstStep.instructions,
                        distance: firstStep.distance
                    )
                }
            }
        }
    }
    
    // MARK: - Location Tracking
    
    private func setupLocationTracking() {
        locationManager.$currentLocation
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.updateNavigation(with: location)
            }
            .store(in: &cancellables)
    }
    
    private func updateNavigation(with location: CLLocation) {
        guard isNavigating, !steps.isEmpty, currentStepIndex < steps.count else { return }
        
        let currentStep = steps[currentStepIndex]
        
        // Calculate distance to the next maneuver point
        let maneuverPoint: CLLocation
        if currentStepIndex + 1 < steps.count {
            let nextStepPolyline = steps[currentStepIndex + 1].polyline
            let firstPoint = nextStepPolyline.points()[0]
            maneuverPoint = CLLocation(
                latitude: firstPoint.coordinate.latitude,
                longitude: firstPoint.coordinate.longitude
            )
        } else {
            // Last step — use the endpoint of the route
            if let route = route {
                let polyline = route.polyline
                let pointCount = polyline.pointCount
                let lastPoint = polyline.points()[pointCount - 1]
                maneuverPoint = CLLocation(
                    latitude: lastPoint.coordinate.latitude,
                    longitude: lastPoint.coordinate.longitude
                )
            } else {
                return
            }
        }
        
        let distToManeuver = location.distance(from: maneuverPoint)
        distanceToNextManeuver = distToManeuver
        
        // Voice announcement
        voiceGuidance.announceIfNeeded(
            instruction: currentStep.instructions,
            distance: distToManeuver,
            stepIndex: currentStepIndex
        )
        
        // Check if we should advance to next step
        if distToManeuver < stepAdvanceThreshold {
            advanceStep()
        }
        
        // Update remaining distance/time (rough estimate)
        updateRemainingEstimates(location: location)
        
        // Check if off route
        checkForReroute(location: location)
    }
    
    private func advanceStep() {
        if currentStepIndex + 1 < steps.count {
            currentStepIndex += 1
        } else {
            // Arrived at destination
            voiceGuidance.announceArrival()
            // Don't stop automatically — let user dismiss
        }
    }
    
    private func updateRemainingEstimates(location: CLLocation) {
        guard let route = route else { return }
        
        // Simple estimation: sum distances of remaining steps + distance to current maneuver
        var remaining = distanceToNextManeuver
        for i in (currentStepIndex + 1)..<steps.count {
            remaining += steps[i].distance
        }
        remainingDistance = remaining
        
        // Estimate time based on proportion of distance remaining
        if route.distance > 0 {
            let proportion = remaining / route.distance
            remainingTime = route.expectedTravelTime * proportion
            eta = Date().addingTimeInterval(remainingTime)
        }
    }
    
    private func checkForReroute(location: CLLocation) {
        guard let route = route else { return }
        
        // Don't reroute too frequently
        if let lastReroute = lastRerouteTime,
           Date().timeIntervalSince(lastReroute) < rerouteCooldown {
            return
        }
        
        // Check distance from the route polyline
        let distFromRoute = distanceFromPolyline(location: location, polyline: route.polyline)
        
        if distFromRoute > rerouteThreshold {
            lastRerouteTime = Date()
            recalculateRoute()
        }
    }
    
    private func distanceFromPolyline(location: CLLocation, polyline: MKPolyline) -> CLLocationDistance {
        let points = polyline.points()
        let pointCount = polyline.pointCount
        
        var minDistance: CLLocationDistance = .greatestFiniteMagnitude
        
        // Sample points along the polyline for efficiency
        let sampleStride = max(1, pointCount / 50)
        for i in Swift.stride(from: 0, to: pointCount, by: sampleStride) {
            let point = points[i]
            let pointLocation = CLLocation(
                latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude
            )
            let dist = location.distance(from: pointLocation)
            minDistance = min(minDistance, dist)
        }
        
        return minDistance
    }
    
    // MARK: - Helpers
    
    var formattedETA: String {
        guard let eta = eta else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: eta)
    }
    
    var formattedRemainingDistance: String {
        if remainingDistance < 160 { // ~500 ft
            let feet = Int(remainingDistance * 3.28084)
            return "\(feet) ft"
        } else {
            let miles = remainingDistance / 1609.34
            if miles < 10 {
                return String(format: "%.1f mi", miles)
            } else {
                return String(format: "%.0f mi", miles)
            }
        }
    }
    
    var formattedRemainingTime: String {
        let minutes = Int(remainingTime / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
    
    var formattedDistanceToManeuver: String {
        let distance = distanceToNextManeuver
        if distance < 160 { // ~500 feet
            let feet = Int(round(distance * 3.28084 / 50) * 50)
            return "\(max(50, feet)) ft"
        } else {
            let miles = distance / 1609.34
            if miles < 10 {
                return String(format: "%.1f mi", miles)
            } else {
                return String(format: "%.0f mi", miles)
            }
        }
    }
    
    /// Return an SF Symbol name for the current step's maneuver
    var currentManeuverIcon: String {
        guard let step = currentStep else { return "arrow.up" }
        return iconForInstruction(step.instructions)
    }
    
    func iconForInstruction(_ instruction: String) -> String {
        let lower = instruction.lowercased()
        
        if lower.contains("left") && lower.contains("slight") {
            return "arrow.up.left"
        } else if lower.contains("right") && lower.contains("slight") {
            return "arrow.up.right"
        } else if lower.contains("sharp") && lower.contains("left") {
            return "arrow.turn.down.left"
        } else if lower.contains("sharp") && lower.contains("right") {
            return "arrow.turn.down.right"
        } else if lower.contains("left") && lower.contains("u-turn") {
            return "arrow.uturn.left"
        } else if lower.contains("right") && lower.contains("u-turn") {
            return "arrow.uturn.right"
        } else if lower.contains("u-turn") {
            return "arrow.uturn.left"
        } else if lower.contains("left") {
            return "arrow.turn.up.left"
        } else if lower.contains("right") {
            return "arrow.turn.up.right"
        } else if lower.contains("merge") {
            return "arrow.merge"
        } else if lower.contains("ramp") || lower.contains("exit") {
            return "arrow.up.right"
        } else if lower.contains("arrive") || lower.contains("destination") {
            return "mappin.circle.fill"
        } else if lower.contains("roundabout") || lower.contains("circle") {
            return "arrow.triangle.turn.up.right.circle"
        } else {
            return "arrow.up"
        }
    }
}
