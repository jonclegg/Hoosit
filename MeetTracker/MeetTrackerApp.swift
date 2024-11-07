//
//  MeetTrackerApp.swift
//  MeetTracker
//
//  Created by Jonathan Clegg on 11/7/24.
//

import SwiftUI

@main
struct MeetTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
