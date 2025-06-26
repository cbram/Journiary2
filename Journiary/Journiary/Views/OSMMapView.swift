//
//  OSMMapView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import MapKit
import CoreLocation

struct OSMMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let routePoints: [RoutePoint]
    let selectedRoutePoint: RoutePoint?
    let isTrackEditMode: Bool
    let mapType: MapType
    let onPointTap: (RoutePoint) -> Void
    let onPointDrag: (RoutePoint, DragGesture.Value) -> Void
    let onPointDragEnd: (RoutePoint, DragGesture.Value) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // Entsprechende Tile Overlay basierend auf MapType hinzufügen
        addTileOverlay(to: mapView, for: mapType)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Region aktualisieren wenn nötig
        if !mapView.region.isEqual(to: region) {
            mapView.setRegion(region, animated: true)
            
            // Auto-Download für betrachtete Region registrieren
            Task { @MainActor in
                MapCacheManager.shared.registerViewedRegion(region)
            }
        }
        
        // Alle bestehenden Overlays und Annotations entfernen (außer User Location)
        mapView.removeOverlays(mapView.overlays)
        let annotationsToRemove = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(annotationsToRemove)
        
        // Entsprechende Tile Overlay wieder hinzufügen
        addTileOverlay(to: mapView, for: mapType)
        
        // Route-Linie hinzufügen
        if routePoints.count > 1 {
            let coordinates = routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }
        
        // Route-Punkte als Annotations hinzufügen
        if isTrackEditMode {
            for point in routePoints {
                let annotation = RoutePointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                annotation.routePoint = point
                annotation.isSelected = selectedRoutePoint?.objectID == point.objectID
                annotation.isTrackEditMode = isTrackEditMode
                mapView.addAnnotation(annotation)
            }
        }
    }
    
    private func addTileOverlay(to mapView: MKMapView, for mapType: MapType) {
        let tileOverlay: MKTileOverlay
        
        switch mapType {
        case .osmStandard:
            tileOverlay = CachedOSMTileOverlay()
        case .tracesTrackTopo:
            tileOverlay = TracesTrackTopoTileOverlay()
        case .tracesTrackVector:
            tileOverlay = TracesTrackVectorTileOverlay()
        default:
            tileOverlay = CachedOSMTileOverlay() // Fallback
        }
        
        tileOverlay.canReplaceMapContent = true
        mapView.addOverlay(tileOverlay, level: .aboveRoads)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: OSMMapView
        
        init(_ parent: OSMMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is CachedOSMTileOverlay || 
               overlay is TracesTrackTopoTileOverlay || 
               overlay is TracesTrackVectorTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: overlay as! MKTileOverlay)
                return renderer
            } else if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemRed
                renderer.lineWidth = parent.isTrackEditMode ? 6 : 5  // Dicker für bessere Sichtbarkeit
                renderer.lineCap = .round
                renderer.lineJoin = .round
                // Stroke-Border für bessere Sichtbarkeit über OSM-Tiles
                renderer.alpha = 0.9
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let routeAnnotation = annotation as? RoutePointAnnotation else {
                return nil
            }
            
            let identifier = "RoutePoint"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? RoutePointAnnotationView
            
            if annotationView == nil {
                annotationView = RoutePointAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            annotationView?.configure(with: routeAnnotation, isTrackEditMode: parent.isTrackEditMode)
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let routeAnnotation = view.annotation as? RoutePointAnnotation,
                  let routePoint = routeAnnotation.routePoint else { return }
            
            parent.onPointTap(routePoint)
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
                
                // Auto-Download für neue Region registrieren
                Task { @MainActor in
                    MapCacheManager.shared.registerViewedRegion(mapView.region)
                }
            }
        }
    }
}

// MARK: - Cached OSM Tile Overlay

class CachedOSMTileOverlay: MKTileOverlay {
    private let mapCache: MapCacheManager
    
    @MainActor override init(urlTemplate: String?) {
        // Initialisiere mapCache vor super.init
        self.mapCache = MapCacheManager.shared
        // OSM Standard Tile Template
        super.init(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
        self.maximumZ = 18
        self.minimumZ = 1
    }
    
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        // Prüfe zuerst, ob Tile im lokalen Cache verfügbar ist
        if mapCache.isTileCached(x: path.x, y: path.y, z: path.z) {
            // Gibt lokale Cache-URL zurück
            return mapCache.getTilePath(x: path.x, y: path.y, z: path.z)
        }
        
        // Starte asynchronen Download für fehlende Tile
        Task { @MainActor in
            await downloadMissingTile(path: path)
        }
        
        // Standard OSM URL für ersten Load
        return URL(string: "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png")!
    }
    
    @MainActor private func downloadMissingTile(path: MKTileOverlayPath) async {
        // Download mit Fallback-Servern
        let servers = [
            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png",
            "https://b.tile.openstreetmap.org/{z}/{x}/{y}.png",
            "https://c.tile.openstreetmap.org/{z}/{x}/{y}.png"
        ]
        
        for serverTemplate in servers {
            do {
                let urlString = serverTemplate
                    .replacingOccurrences(of: "{z}", with: "\(path.z)")
                    .replacingOccurrences(of: "{x}", with: "\(path.x)")
                    .replacingOccurrences(of: "{y}", with: "\(path.y)")
                
                guard let url = URL(string: urlString) else { continue }
                
                var request = URLRequest(url: url)
                request.setValue("Journiary iOS App", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 10.0
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    // Erfolgreich - im Cache speichern
                    mapCache.cacheTile(data: data, x: path.x, y: path.y, z: path.z)
                    print("✅ Tile gecacht: \(path.z)/\(path.x)/\(path.y)")
                    return
                }
            } catch {
                // Weiter mit nächstem Server versuchen
                continue
            }
        }
        
        print("⚠️ Tile konnte nicht geladen werden: \(path.z)/\(path.x)/\(path.y)")
    }
}

// MARK: - TracesTrack Topo Tile Overlay

class TracesTrackTopoTileOverlay: MKTileOverlay {
    private let mapCache: MapCacheManager
    
    @MainActor override init(urlTemplate: String?) {
        self.mapCache = MapCacheManager.shared
        // TracesTrack Topo Tile Template - kostenlos nutzbar
        super.init(urlTemplate: TracesTrackConfig.topoTileBaseURL + "/{z}/{x}/{y}.png")
        self.maximumZ = TracesTrackConfig.maxZoomLevel
        self.minimumZ = TracesTrackConfig.minZoomLevel
    }
    
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        // TracesTrack Topo URLs verwenden
        return TracesTrackConfig.topoTileURL(x: path.x, y: path.y, z: path.z) ?? 
               URL(string: "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png")!
    }
    
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        Task {
            await downloadTracesTrackTile(path: path, result: result)
        }
    }
    
    func downloadTracesTrackTile(path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) async {
        // Versuche zuerst TracesTrack
        guard let url = TracesTrackConfig.topoTileURL(x: path.x, y: path.y, z: path.z) else {
            await fallbackToOSM(path: path, result: result)
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue(TracesTrackConfig.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("https://www.openstreetmap.org/", forHTTPHeaderField: "Referer")
            request.timeoutInterval = TracesTrackConfig.downloadTimeout
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    result(data, nil)
                    return
                case 404, 500...599: // Server-Fehler oder nicht verfügbar
                    print("⚠️ TracesTrack Topo nicht verfügbar (\(httpResponse.statusCode)), fallback zu OSM")
                    await fallbackToOSM(path: path, result: result)
                    return
                case 429:
                    print("⚠️ TracesTrack Rate Limit erreicht, fallback zu OSM")
                    await fallbackToOSM(path: path, result: result)
                    return
                default:
                    print("⚠️ TracesTrack HTTP \(httpResponse.statusCode), fallback zu OSM")
                    await fallbackToOSM(path: path, result: result)
                    return
                }
            } else {
                result(data, nil)
            }
        } catch {
            print("⚠️ TracesTrack Download-Fehler: \(error.localizedDescription), fallback zu OSM")
            await fallbackToOSM(path: path, result: result)
        }
    }
    
    private func fallbackToOSM(path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) async {
        let osmURL = URL(string: "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png")!
        
        do {
            var request = URLRequest(url: osmURL)
            request.setValue(TracesTrackConfig.userAgent, forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10.0
            
            let (data, _) = try await URLSession.shared.data(for: request)
            result(data, nil)
        } catch {
            result(nil, TracesTrackError.downloadFailed("Fallback fehlgeschlagen: \(error.localizedDescription)"))
        }
    }
}

// MARK: - TracesTrack Vector Tile Overlay

class TracesTrackVectorTileOverlay: MKTileOverlay {
    private let mapCache: MapCacheManager
    
    @MainActor override init(urlTemplate: String?) {
        self.mapCache = MapCacheManager.shared
        // Vector Tiles Template mit API Key Support
        super.init(urlTemplate: TracesTrackConfig.vectorTileBaseURL + "/{z}/{x}/{y}.mvt")
        self.maximumZ = TracesTrackConfig.maxZoomLevel
        self.minimumZ = TracesTrackConfig.minZoomLevel
    }
    
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        // Vector Tiles wenn API Key verfügbar, sonst Fallback zu Topo
        return TracesTrackConfig.vectorTileURL(x: path.x, y: path.y, z: path.z) ??
               TracesTrackConfig.topoTileURL(x: path.x, y: path.y, z: path.z) ??
               URL(string: "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png")!
    }
    
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        Task {
            await downloadTracesTrackVectorTile(path: path, result: result)
        }
    }
    
    private func downloadTracesTrackVectorTile(path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) async {
        // Prüfe API Key Verfügbarkeit für Vector Tiles
        if !TracesTrackConfig.hasAPIKey {
            print("⚠️ Kein API Key für Vector Tiles, fallback zu Topo")
            // Fallback auf Topo Tiles
            let topoOverlay = TracesTrackTopoTileOverlay()
            await topoOverlay.downloadTracesTrackTile(path: path, result: result)
            return
        }
        
        guard let url = TracesTrackConfig.vectorTileURL(x: path.x, y: path.y, z: path.z) else {
            print("⚠️ Ungültige Vector Tile URL, fallback zu Topo")
            let topoOverlay = TracesTrackTopoTileOverlay()
            await topoOverlay.downloadTracesTrackTile(path: path, result: result)
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue(TracesTrackConfig.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("https://www.openstreetmap.org/", forHTTPHeaderField: "Referer")
            request.timeoutInterval = TracesTrackConfig.downloadTimeout
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    result(data, nil)
                    return
                case 401, 403:
                    print("⚠️ TracesTrack API Key ungültig, fallback zu Topo")
                    let topoOverlay = TracesTrackTopoTileOverlay()
                    await topoOverlay.downloadTracesTrackTile(path: path, result: result)
                    return
                case 404, 500...599:
                    print("⚠️ TracesTrack Vector nicht verfügbar (\(httpResponse.statusCode)), fallback zu Topo")
                    let topoOverlay = TracesTrackTopoTileOverlay()
                    await topoOverlay.downloadTracesTrackTile(path: path, result: result)
                    return
                case 429:
                    print("⚠️ TracesTrack Vector Rate Limit, fallback zu Topo")
                    let topoOverlay = TracesTrackTopoTileOverlay()
                    await topoOverlay.downloadTracesTrackTile(path: path, result: result)
                    return
                default:
                    print("⚠️ TracesTrack Vector HTTP \(httpResponse.statusCode), fallback zu Topo")
                    let topoOverlay = TracesTrackTopoTileOverlay()
                    await topoOverlay.downloadTracesTrackTile(path: path, result: result)
                    return
                }
            } else {
                result(data, nil)
            }
        } catch {
            print("⚠️ TracesTrack Vector Download-Fehler: \(error.localizedDescription), fallback zu Topo")
            let topoOverlay = TracesTrackTopoTileOverlay()
            await topoOverlay.downloadTracesTrackTile(path: path, result: result)
        }
    }
}

// MARK: - Custom Annotation Classes

class RoutePointAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D()
    var routePoint: RoutePoint?
    var isSelected: Bool = false
    var isTrackEditMode: Bool = false
}

class RoutePointAnnotationView: MKAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        centerOffset = CGPoint(x: 0, y: 0)
        canShowCallout = false
        isDraggable = true
    }
    
    func configure(with annotation: RoutePointAnnotation, isTrackEditMode: Bool) {
        // Größere Punkte für bessere Sichtbarkeit in OSM
        let size: CGFloat = isTrackEditMode ? (annotation.isSelected ? 24 : 18) : 12
        let color: UIColor = isTrackEditMode ? (annotation.isSelected ? .systemBlue : .systemRed) : .systemRed
        
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        
        // Erstelle einen farbigen Kreis mit besserer Sichtbarkeit
        let circleView = UIView(frame: bounds)
        circleView.backgroundColor = color
        circleView.layer.cornerRadius = size / 2
        circleView.layer.borderWidth = 3
        circleView.layer.borderColor = UIColor.white.cgColor
        
        // Shadow für bessere Sichtbarkeit
        circleView.layer.shadowColor = UIColor.black.cgColor
        circleView.layer.shadowOffset = CGSize(width: 0, height: 1)
        circleView.layer.shadowOpacity = 0.3
        circleView.layer.shadowRadius = 2
        
        // Entferne alle vorherigen Subviews
        subviews.forEach { $0.removeFromSuperview() }
        addSubview(circleView)
        
        isDraggable = isTrackEditMode && annotation.isSelected
    }
}

// MARK: - MKCoordinateRegion Extension

extension MKCoordinateRegion {
    func isEqual(to other: MKCoordinateRegion, tolerance: Double = 0.0001) -> Bool {
        return abs(center.latitude - other.center.latitude) < tolerance &&
               abs(center.longitude - other.center.longitude) < tolerance &&
               abs(span.latitudeDelta - other.span.latitudeDelta) < tolerance &&
               abs(span.longitudeDelta - other.span.longitudeDelta) < tolerance
    }
} 