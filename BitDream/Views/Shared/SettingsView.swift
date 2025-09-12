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
    
    // Shared reset for both platforms
    static func resetAllSettings(store: Store) {
        let theme = ThemeManager.shared
        theme.setAccentColor(AppDefaults.accentColor)
        theme.setThemeMode(AppDefaults.themeMode)
        
        // Persist AppStorage-backed flags
        UserDefaults.standard.set(AppDefaults.showContentTypeIcons, forKey: UserDefaultsKeys.showContentTypeIcons)
        UserDefaults.standard.set(AppDefaults.startupConnectionBehavior.rawValue, forKey: UserDefaultsKeys.startupConnectionBehavior)
        
        // Poll interval via Store API
        store.updatePollInterval(AppDefaults.pollInterval)
    }
    
    var body: some View {
        #if os(iOS)
        iOSSettingsView(store: store)
        #elseif os(macOS)
        macOSSettingsView(store: store)
        #endif
    }
}

// Shared extension for creating a Binding<StartupConnectionBehavior> from a raw String binding
extension Binding where Value == StartupConnectionBehavior {
    static func fromRawValue(rawValue: Binding<String>, defaultValue: StartupConnectionBehavior) -> Binding<StartupConnectionBehavior> {
        Binding<StartupConnectionBehavior>(
            get: { StartupConnectionBehavior(rawValue: rawValue.wrappedValue) ?? defaultValue },
            set: { rawValue.wrappedValue = $0.rawValue }
        )
    }
}

#Preview {
    SettingsView(store: Store())
} 