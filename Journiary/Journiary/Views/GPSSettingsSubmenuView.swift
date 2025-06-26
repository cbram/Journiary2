import SwiftUI
import CoreData

struct GPSSettingsSubmenuView: View {
    @ObservedObject var locationManager: LocationManager
    var viewContext: NSManagedObjectContext

    var body: some View {
        List {
            NavigationLink {
                GPSSettingsView(locationManager: locationManager)
            } label: {
                SettingsRowNavigable(
                    title: "GPS-Tracking",
                    icon: "location.circle.fill",
                    status: locationManager.trackingAccuracy.displayName
                )
            }

            NavigationLink {
                SpeedOptimizationSettingsView()
                    .environmentObject(locationManager)
            } label: {
                SettingsRowNavigable(
                    title: "Track-Optimierung",
                    icon: "speedometer",
                    status: locationManager.automaticOptimizationEnabled ? "Automatisch" : optimizationLevelDisplayName()
                )
            }

            SettingsRow(
                title: "Standortdienste",
                icon: "location.fill",
                status: locationPermissionStatus
            )
        }
        .navigationTitle("GPS & Tracking")
    }

    private var locationPermissionStatus: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Erlaubt"
        case .denied, .restricted:
            return "Verweigert"
        case .notDetermined:
            return "Nicht festgelegt"
        @unknown default:
            return "Unbekannt"
        }
    }

    private func optimizationLevelDisplayName() -> String {
        switch locationManager.optimizationLevel.maxDeviation {
        case 5.0: return "Konservativ"
        case 10.0: return "Ausgewogen"
        case 20.0: return "Aggressiv"
        case 30.0: return "Highway"
        default: return "Ausgewogen"
        }
    }
} 