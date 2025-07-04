//
//  ContentView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var appMode: AppMode = .tracking
    
    var body: some View {
        Group {
            switch appMode {
            case .tracking:
                TrackingView(appMode: $appMode)
            case .planning:
                POIView(appMode: $appMode)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: appMode)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
