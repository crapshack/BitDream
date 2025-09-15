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

// MARK: - Shared Server Configuration Components

@ViewBuilder
func serverConfigurationContent(store: Store) -> some View {
    if let config = store.sessionConfiguration {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Speed Limits
                GroupBox(label: Text("Speed Limits").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        keyValueRow("Download Limit", config.speedLimitDownEnabled ? "\(config.speedLimitDown) KB/s" : "Unlimited")
                        keyValueRow("Download Limit Enabled", config.speedLimitDownEnabled ? "Yes" : "No")
                        keyValueRow("Upload Limit", config.speedLimitUpEnabled ? "\(config.speedLimitUp) KB/s" : "Unlimited")
                        keyValueRow("Upload Limit Enabled", config.speedLimitUpEnabled ? "Yes" : "No")
                        keyValueRow("Alternate Download Limit", "\(config.altSpeedDown) KB/s")
                        keyValueRow("Alternate Upload Limit", "\(config.altSpeedUp) KB/s")
                        keyValueRow("Alternate Speed Mode", config.altSpeedEnabled ? "Active" : "Inactive")
                    }
                    .padding(10)
                }
                
                // Network Settings
                GroupBox(label: Text("Network").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        keyValueRow("Peer Port", String(config.peerPort))
                        keyValueRow("Port Forwarding", config.portForwardingEnabled ? "Enabled" : "Disabled")
                        keyValueRow("Encryption", config.encryption.capitalized)
                        keyValueRow("DHT", config.dhtEnabled ? "Enabled" : "Disabled")
                        keyValueRow("PEX", config.pexEnabled ? "Enabled" : "Disabled")
                        keyValueRow("µTP", config.utpEnabled ? "Enabled" : "Disabled")
                    }
                    .padding(10)
                }
                
                // Queue Management
                GroupBox(label: Text("Queue Management").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        keyValueRow("Download Queue Enabled", config.downloadQueueEnabled ? "Yes" : "No")
                        keyValueRow("Download Queue Size", String(config.downloadQueueSize))
                        keyValueRow("Seed Queue Enabled", config.seedQueueEnabled ? "Yes" : "No")
                        keyValueRow("Seed Queue Size", String(config.seedQueueSize))
                        keyValueRow("Seed Ratio Limited", config.seedRatioLimited ? "Yes" : "No")
                        keyValueRow("Seed Ratio Limit", String(format: "%.2f", config.seedRatioLimit))
                    }
                    .padding(10)
                }
                
                // File Management
                GroupBox(label: Text("File Management").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        keyValueRow("Download Directory", config.downloadDir)
                        keyValueRow("Incomplete Directory", config.incompleteDir)
                        keyValueRow("Incomplete Directory Enabled", config.incompleteDirEnabled ? "Yes" : "No")
                        keyValueRow("Start Added Torrents", config.startAddedTorrents ? "Yes" : "No")
                    }
                    .padding(10)
                }
            }
            .padding(.bottom, 20)
        }
    } else {
        ContentUnavailableView(
            "No Server Configuration",
            systemImage: "server.rack",
            description: Text("Server configuration will appear when connected to a server.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@ViewBuilder
func keyValueRow(_ key: String, _ value: String) -> some View {
    HStack {
        Text(key)
        Spacer(minLength: 16)
        Text(value)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.secondary)
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