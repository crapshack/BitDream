import SwiftUI
import Foundation
import KeychainAccess

/// Platform-agnostic wrapper for SettingsView
/// This view simply delegates to the appropriate platform-specific implementation
struct SettingsView: View {
    @ObservedObject var store: Store
    
    // Shared poll interval options
    static let pollIntervalOptions: [Double] = [1.0, 2.0, 5.0, 10.0, 30.0, 60.0]
    
    // Helper to format the interval options
    static func formatInterval(_ interval: Double) -> String {
        if interval == 1.0 {
            return "1 second"
        } else if interval < 60.0 {
            return "\(Int(interval)) seconds"
        } else {
            return "\(Int(interval / 60)) minute\(interval == 60.0 ? "" : "s")"
        }
    }
    
    var body: some View {
        #if os(iOS)
        iOSSettingsView(store: store)
        #elseif os(macOS)
        macOSSettingsView(store: store)
        #endif
    }
}

#Preview {
    SettingsView(store: Store())
} 