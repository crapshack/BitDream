import SwiftUI
import Foundation

#if os(iOS)
struct iOSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingThemeSettings = false
    @ObservedObject var store: Store
    
    var body: some View {
        // iOS version with standard styling
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    HStack {
                        Button("Theme Settings") {
                            // Disabled for now
                        }
                        .disabled(true)
                        
                        Spacer()
                        
                        Text("Coming Soon")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Section(header: Text("Refresh Settings")) {
                    Picker("Poll Interval", selection: Binding(
                        get: { self.store.pollInterval },
                        set: { self.store.updatePollInterval($0) }
                    )) {
                        ForEach(SettingsView.pollIntervalOptions, id: \.self) { interval in
                            Text(SettingsView.formatInterval(interval)).tag(interval)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    iOSSettingsView(store: Store())
}
#else
// Empty struct for macOS to reference - this won't be compiled on macOS but provides the type
struct iOSSettingsView: View {
    @ObservedObject var store: Store
    
    var body: some View {
        EmptyView()
    }
}
#endif 