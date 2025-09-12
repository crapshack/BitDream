import SwiftUI
import Foundation

#if os(iOS)
struct iOSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingThemeSettings = false
    @ObservedObject var store: Store
    @ObservedObject private var themeManager = ThemeManager.shared
    @AppStorage(UserDefaultsKeys.showContentTypeIcons) private var showContentTypeIcons: Bool = AppDefaults.showContentTypeIcons
    @AppStorage(UserDefaultsKeys.startupConnectionBehavior) private var startupBehaviorRaw: String = AppDefaults.startupConnectionBehavior.rawValue
    
    private var startupBehavior: StartupConnectionBehavior {
        get { StartupConnectionBehavior(rawValue: startupBehaviorRaw) ?? AppDefaults.startupConnectionBehavior }
        set { startupBehaviorRaw = newValue.rawValue }
    }
    
    var body: some View {
        // iOS version with standard styling
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $themeManager.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    
                    NavigationLink(destination: AccentColorPicker(selection: $themeManager.currentAccentColorOption)) {
                        HStack {
                            Text("Accent Color")
                            Spacer()
                            Circle()
                                .fill(themeManager.currentAccentColorOption.color)
                                .frame(width: 16, height: 16)
                            Text(themeManager.currentAccentColorOption.name)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle("Show file type icons", isOn: $showContentTypeIcons)
                }
                
                Section(header: Text("Startup")) {
                    NavigationLink(destination: StartupConnectionPicker(selected: Binding<StartupConnectionBehavior>(
                        get: { StartupConnectionBehavior(rawValue: startupBehaviorRaw) ?? AppDefaults.startupConnectionBehavior },
                        set: { startupBehaviorRaw = $0.rawValue }
                    ))) {
                        HStack {
                            Text("Startup connection")
                            Spacer()
                            Text((StartupConnectionBehavior(rawValue: startupBehaviorRaw) ?? .lastUsed) == .lastUsed ? "Last used server" : "Default server")
                                .foregroundColor(.secondary)
                        }
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
                
                Section(header: Text("Reset")) {
                    Button(action: {
                        // Reset to shared defaults
                        themeManager.setAccentColor(AppDefaults.accentColor)
                        themeManager.setThemeMode(AppDefaults.themeMode)
                        showContentTypeIcons = AppDefaults.showContentTypeIcons
                        store.updatePollInterval(AppDefaults.pollInterval)
                        startupBehaviorRaw = AppDefaults.startupConnectionBehavior.rawValue
                    }) {
                        Text("Reset All Settings")
                            .foregroundColor(.accentColor)
                    }
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

struct StartupConnectionPicker: View {
    @Binding var selected: StartupConnectionBehavior
    
    var body: some View {
        List {
            Button(action: { selected = .lastUsed }) {
                HStack {
                    Text("Last used server")
                    Spacer()
                    if selected == .lastUsed { Image(systemName: "checkmark") }
                }
            }
            Button(action: { selected = .defaultServer }) {
                HStack {
                    Text("Default server")
                    Spacer()
                    if selected == .defaultServer { Image(systemName: "checkmark") }
                }
            }
        }
        .navigationTitle("Startup connection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccentColorPicker: View {
    @Binding var selection: AccentColorOption
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(AccentColorOption.allCases) { option in
                HStack {
                    Circle()
                        .fill(option.color)
                        .frame(width: 20, height: 20)
                    
                    Text(option.name)
                    
                    Text(option.rawValue)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if selection == option {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        selection = option
                        ThemeManager.shared.setAccentColor(option)
                    }
                }
            }
        }
        .navigationTitle("Accent Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    iOSSettingsView(store: Store())
}
#else
// Empty struct for macOS to reference - this won't be compiled on iOS but provides the type
struct iOSSettingsView: View {
    @ObservedObject var store: Store
    
    var body: some View {
        EmptyView()
    }
}
#endif 