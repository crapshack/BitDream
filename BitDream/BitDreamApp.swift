//
//  BitDreamApp.swift
//  BitDream
//
//  Created by Austin Smith on 12/29/22.
//

import SwiftUI
import UserNotifications
import CoreData
// Import Store from the main module
import Foundation

@main
struct BitDreamApp: App {
    let persistenceController = PersistenceController.shared
    
    // Create a shared store instance that will be used by both the main app and settings
    @StateObject private var store = Store()
    
    init() {
        // Register default values for view state
        UserDefaults.standard.register(defaults: [
            "sidebarVisibility": true, // true = show sidebar (.all), false = hide sidebar (.detailOnly)
            "inspectorVisibility": true,
            "sortBySelection": "nameAsc" // Default sort by name ascending
        ])
        
        // Request permission to use badges on macOS
        #if os(macOS)
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(store) // Pass the shared store to the ContentView
                .accentColor(ThemeManager.shared.accentColor) // Apply the accent color to the entire app
                .environmentObject(ThemeManager.shared) // Pass the ThemeManager to all views
        }
        
        #if os(macOS)
        Settings {
            SettingsView(store: store) // Use the same store instance
                .frame(minWidth: 500, idealWidth: 550, maxWidth: 650, minHeight: 300, idealHeight: 350, maxHeight: 450)
                .environmentObject(ThemeManager.shared) // Pass the ThemeManager to the Settings view
        }
        #endif
    }
}
