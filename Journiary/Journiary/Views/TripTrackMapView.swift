import SwiftUI

/// Vollbild-Kartenansicht für einen Trip. Verwendet die bestehende `MapView`, jedoch ohne Editier-Modus.
struct TripTrackMapView: View {
    let trip: Trip

    var body: some View {
        MapView(tripToEdit: trip)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(trip.name ?? "Karte")
    }
} 