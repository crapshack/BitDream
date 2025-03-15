import SwiftUI
import Foundation

#if os(macOS)
struct macOSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingThemeSettings = false
    @ObservedObject var store: Store
    
    var body: some View {
        // macOS version with custom styling to match the screenshot
        VStack(spacing: 0) {
            // Header
            Text("Settings")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Appearance section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Button("Theme Settings") {
                            // Disabled for now
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(true)
                        
                        Text("Coming Soon")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Divider()
                
                // Refresh Settings section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Refresh Settings")
                        .font(.headline)
                    
                    HStack {
                        Text("Poll Interval")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { self.store.pollInterval },
                            set: { self.store.updatePollInterval($0) }
                        )) {
                            ForEach(SettingsView.pollIntervalOptions, id: \.self) { interval in
                                Text(SettingsView.formatInterval(interval)).tag(interval)
                            }
                        }
                        .frame(width: 120)
                        .pickerStyle(.menu)
                    }
                }
                
                Divider()
                
                // About section
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Done button
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
            }
            .padding()
            .frame(width: 400)
        }
        .cornerRadius(8)
    }
}

#Preview {
    macOSSettingsView(store: Store())
}
#else
// Empty struct for iOS to reference - this won't be compiled on iOS but provides the type
struct macOSSettingsView: View {
    @ObservedObject var store: Store
    
    var body: some View {
        EmptyView()
    }
}
#endif 