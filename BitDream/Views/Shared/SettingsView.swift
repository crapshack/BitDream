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

class SessionSettingsEditModel: ObservableObject {
    @Published var values: [String: Any] = [:]
    private var saveTimer: Timer?
    private var store: Store?
    
    func setup(store: Store) {
        self.store = store
    }
    
    func setValue<T>(_ key: String, _ value: T, original: T) where T: Equatable {
        if value != original {
            values[key] = value
            scheduleAutoSave()
        } else {
            values.removeValue(forKey: key)
            if values.isEmpty {
                saveTimer?.invalidate()
            }
        }
    }
    
    func getValue<T>(_ key: String, fallback: T) -> T {
        return values[key] as? T ?? fallback
    }
    
    private func scheduleAutoSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            self.saveChanges()
        }
    }
    
    private func saveChanges() {
        guard !values.isEmpty, 
              let store = store,
              let serverInfo = store.currentServerInfo else { return }
        
        let args = buildSessionSetArgs()
        
        setSession(
            args: args,
            config: serverInfo.config,
            auth: serverInfo.auth
        ) { response in
            DispatchQueue.main.async {
                switch response {
                case .success:
                    self.values = [:]
                    store.refreshSessionConfiguration()
                case .unauthorized, .configError, .failed:
                    print("Failed to save session settings: \(response)")
                }
            }
        }
    }
    
    private func buildSessionSetArgs() -> TransmissionSessionSetRequestArgs {
        var args = TransmissionSessionSetRequestArgs()
        
        // Speed & Bandwidth
        args.speedLimitDown = values["speedLimitDown"] as? Int64
        args.speedLimitDownEnabled = values["speedLimitDownEnabled"] as? Bool
        args.speedLimitUp = values["speedLimitUp"] as? Int64
        args.speedLimitUpEnabled = values["speedLimitUpEnabled"] as? Bool
        args.altSpeedDown = values["altSpeedDown"] as? Int64
        args.altSpeedUp = values["altSpeedUp"] as? Int64
        args.altSpeedEnabled = values["altSpeedEnabled"] as? Bool
        args.altSpeedTimeBegin = values["altSpeedTimeBegin"] as? Int
        args.altSpeedTimeEnd = values["altSpeedTimeEnd"] as? Int
        args.altSpeedTimeEnabled = values["altSpeedTimeEnabled"] as? Bool
        args.altSpeedTimeDay = values["altSpeedTimeDay"] as? Int
        
        // File Management
        args.downloadDir = values["downloadDir"] as? String
        args.incompleteDir = values["incompleteDir"] as? String
        args.incompleteDirEnabled = values["incompleteDirEnabled"] as? Bool
        args.startAddedTorrents = values["startAddedTorrents"] as? Bool
        args.trashOriginalTorrentFiles = values["trashOriginalTorrentFiles"] as? Bool
        args.renamePartialFiles = values["renamePartialFiles"] as? Bool
        
        // Queue Management
        args.downloadQueueEnabled = values["downloadQueueEnabled"] as? Bool
        args.downloadQueueSize = values["downloadQueueSize"] as? Int
        args.seedQueueEnabled = values["seedQueueEnabled"] as? Bool
        args.seedQueueSize = values["seedQueueSize"] as? Int
        args.seedRatioLimited = values["seedRatioLimited"] as? Bool
        args.seedRatioLimit = values["seedRatioLimit"] as? Double
        args.idleSeedingLimit = values["idleSeedingLimit"] as? Int
        args.idleSeedingLimitEnabled = values["idleSeedingLimitEnabled"] as? Bool
        args.queueStalledEnabled = values["queueStalledEnabled"] as? Bool
        args.queueStalledMinutes = values["queueStalledMinutes"] as? Int
        
        // Network Settings
        args.peerPort = values["peerPort"] as? Int
        args.peerPortRandomOnStart = values["peerPortRandomOnStart"] as? Bool
        args.portForwardingEnabled = values["portForwardingEnabled"] as? Bool
        args.dhtEnabled = values["dhtEnabled"] as? Bool
        args.pexEnabled = values["pexEnabled"] as? Bool
        args.lpdEnabled = values["lpdEnabled"] as? Bool
        args.encryption = values["encryption"] as? String
        args.utpEnabled = values["utpEnabled"] as? Bool
        args.peerLimitGlobal = values["peerLimitGlobal"] as? Int
        args.peerLimitPerTorrent = values["peerLimitPerTorrent"] as? Int
        
        // Blocklist
        args.blocklistEnabled = values["blocklistEnabled"] as? Bool
        args.blocklistUrl = values["blocklistUrl"] as? String
        
        // Cache
        args.cacheSizeMb = values["cacheSizeMb"] as? Int
        
        // Scripts
        args.scriptTorrentDoneEnabled = values["scriptTorrentDoneEnabled"] as? Bool
        args.scriptTorrentDoneFilename = values["scriptTorrentDoneFilename"] as? String
        args.scriptTorrentAddedEnabled = values["scriptTorrentAddedEnabled"] as? Bool
        args.scriptTorrentAddedFilename = values["scriptTorrentAddedFilename"] as? String
        args.scriptTorrentDoneSeedingEnabled = values["scriptTorrentDoneSeedingEnabled"] as? Bool
        args.scriptTorrentDoneSeedingFilename = values["scriptTorrentDoneSeedingFilename"] as? String
        
        return args
    }
}

@ViewBuilder
func serverConfigurationContent(store: Store, editModel: SessionSettingsEditModel) -> some View {
    if let config = store.sessionConfiguration {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                speedLimitsSection(config: config, editModel: editModel)
                networkSection(config: config, editModel: editModel)
                queueManagementSection(config: config, editModel: editModel)
                fileManagementSection(config: config, editModel: editModel)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            editModel.setup(store: store)
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

// MARK: - Settings Sections

@ViewBuilder
func speedLimitsSection(config: TransmissionSessionResponseArguments, editModel: SessionSettingsEditModel) -> some View {
    GroupBox(label: Text("Speed Limits").font(.headline)) {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle("Download Limit", isOn: Binding(
                    get: { editModel.getValue("speedLimitDownEnabled", fallback: config.speedLimitDownEnabled) },
                    set: { editModel.setValue("speedLimitDownEnabled", $0, original: config.speedLimitDownEnabled) }
                ))
                .platformToggleStyle()
                Spacer()
                TextField("KB/s", value: Binding(
                    get: { editModel.getValue("speedLimitDown", fallback: config.speedLimitDown) },
                    set: { editModel.setValue("speedLimitDown", $0, original: config.speedLimitDown) }
                ), format: .number)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
                .disabled(!editModel.getValue("speedLimitDownEnabled", fallback: config.speedLimitDownEnabled))
            }
            
    HStack {
                Toggle("Upload Limit", isOn: Binding(
                    get: { editModel.getValue("speedLimitUpEnabled", fallback: config.speedLimitUpEnabled) },
                    set: { editModel.setValue("speedLimitUpEnabled", $0, original: config.speedLimitUpEnabled) }
                ))
                .platformToggleStyle()
                Spacer()
                TextField("KB/s", value: Binding(
                    get: { editModel.getValue("speedLimitUp", fallback: config.speedLimitUp) },
                    set: { editModel.setValue("speedLimitUp", $0, original: config.speedLimitUp) }
                ), format: .number)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
                .disabled(!editModel.getValue("speedLimitUpEnabled", fallback: config.speedLimitUpEnabled))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Alternate Speed Limits")
                    .font(.subheadline)
            .foregroundColor(.secondary)
                
                Toggle("Alternate Speed Mode", isOn: Binding(
                    get: { editModel.getValue("altSpeedEnabled", fallback: config.altSpeedEnabled) },
                    set: { editModel.setValue("altSpeedEnabled", $0, original: config.altSpeedEnabled) }
                ))
                .platformToggleStyle()
                
                HStack {
                    Text("Download")
                    Spacer()
                    TextField("KB/s", value: Binding(
                        get: { editModel.getValue("altSpeedDown", fallback: config.altSpeedDown) },
                        set: { editModel.setValue("altSpeedDown", $0, original: config.altSpeedDown) }
                    ), format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!editModel.getValue("altSpeedEnabled", fallback: config.altSpeedEnabled))
                }
                
                HStack {
                    Text("Upload")
                    Spacer()
                    TextField("KB/s", value: Binding(
                        get: { editModel.getValue("altSpeedUp", fallback: config.altSpeedUp) },
                        set: { editModel.setValue("altSpeedUp", $0, original: config.altSpeedUp) }
                    ), format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!editModel.getValue("altSpeedEnabled", fallback: config.altSpeedEnabled))
                }
            }
        }
        .padding(10)
    }
}

@ViewBuilder
func networkSection(config: TransmissionSessionResponseArguments, editModel: SessionSettingsEditModel) -> some View {
    GroupBox(label: Text("Network").font(.headline)) {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Peer Port")
                Spacer()
                TextField("Port", value: Binding(
                    get: { editModel.getValue("peerPort", fallback: config.peerPort) },
                    set: { editModel.setValue("peerPort", $0, original: config.peerPort) }
                ), format: .number.grouping(.never))
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
            }
            
            Toggle("Port Forwarding", isOn: Binding(
                get: { editModel.getValue("portForwardingEnabled", fallback: config.portForwardingEnabled) },
                set: { editModel.setValue("portForwardingEnabled", $0, original: config.portForwardingEnabled) }
            ))
            .platformToggleStyle()
            
            HStack {
                Text("Encryption")
                Spacer()
                Picker("", selection: Binding(
                    get: { editModel.getValue("encryption", fallback: config.encryption) },
                    set: { editModel.setValue("encryption", $0, original: config.encryption) }
                )) {
                    Text("Required").tag("required")
                    Text("Preferred").tag("preferred") 
                    Text("Tolerated").tag("tolerated")
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            
            Toggle("DHT", isOn: Binding(
                get: { editModel.getValue("dhtEnabled", fallback: config.dhtEnabled) },
                set: { editModel.setValue("dhtEnabled", $0, original: config.dhtEnabled) }
            ))
            .platformToggleStyle()
            Toggle("PEX", isOn: Binding(
                get: { editModel.getValue("pexEnabled", fallback: config.pexEnabled) },
                set: { editModel.setValue("pexEnabled", $0, original: config.pexEnabled) }
            ))
            .platformToggleStyle()
            Toggle("µTP", isOn: Binding(
                get: { editModel.getValue("utpEnabled", fallback: config.utpEnabled) },
                set: { editModel.setValue("utpEnabled", $0, original: config.utpEnabled) }
            ))
            .platformToggleStyle()
        }
        .padding(10)
    }
}

@ViewBuilder
func queueManagementSection(config: TransmissionSessionResponseArguments, editModel: SessionSettingsEditModel) -> some View {
    GroupBox(label: Text("Queue Management").font(.headline)) {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle("Download Queue", isOn: Binding(
                    get: { editModel.getValue("downloadQueueEnabled", fallback: config.downloadQueueEnabled) },
                    set: { editModel.setValue("downloadQueueEnabled", $0, original: config.downloadQueueEnabled) }
                ))
                .platformToggleStyle()
                Spacer()
                TextField("Size", value: Binding(
                    get: { editModel.getValue("downloadQueueSize", fallback: config.downloadQueueSize) },
                    set: { editModel.setValue("downloadQueueSize", $0, original: config.downloadQueueSize) }
                ), format: .number)
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)
                .disabled(!editModel.getValue("downloadQueueEnabled", fallback: config.downloadQueueEnabled))
            }
            
            HStack {
                Toggle("Seed Queue", isOn: Binding(
                    get: { editModel.getValue("seedQueueEnabled", fallback: config.seedQueueEnabled) },
                    set: { editModel.setValue("seedQueueEnabled", $0, original: config.seedQueueEnabled) }
                ))
                .platformToggleStyle()
                Spacer()
                TextField("Size", value: Binding(
                    get: { editModel.getValue("seedQueueSize", fallback: config.seedQueueSize) },
                    set: { editModel.setValue("seedQueueSize", $0, original: config.seedQueueSize) }
                ), format: .number)
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)
                .disabled(!editModel.getValue("seedQueueEnabled", fallback: config.seedQueueEnabled))
            }
            
            HStack {
                Toggle("Seed Ratio Limit", isOn: Binding(
                    get: { editModel.getValue("seedRatioLimited", fallback: config.seedRatioLimited) },
                    set: { editModel.setValue("seedRatioLimited", $0, original: config.seedRatioLimited) }
                ))
                .platformToggleStyle()
                Spacer()
                TextField("Ratio", value: Binding(
                    get: { editModel.getValue("seedRatioLimit", fallback: config.seedRatioLimit) },
                    set: { editModel.setValue("seedRatioLimit", $0, original: config.seedRatioLimit) }
                ), format: .number.precision(.fractionLength(2)))
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
                .disabled(!editModel.getValue("seedRatioLimited", fallback: config.seedRatioLimited))
            }
        }
        .padding(10)
    }
}

@ViewBuilder
func fileManagementSection(config: TransmissionSessionResponseArguments, editModel: SessionSettingsEditModel) -> some View {
    GroupBox(label: Text("File Management").font(.headline)) {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Download Directory")
                TextField("Path", text: Binding(
                    get: { editModel.getValue("downloadDir", fallback: config.downloadDir) },
                    set: { editModel.setValue("downloadDir", $0, original: config.downloadDir) }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Toggle("Incomplete Directory", isOn: Binding(
                    get: { editModel.getValue("incompleteDirEnabled", fallback: config.incompleteDirEnabled) },
                    set: { editModel.setValue("incompleteDirEnabled", $0, original: config.incompleteDirEnabled) }
                ))
                .platformToggleStyle()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Incomplete Directory Path")
                TextField("Path", text: Binding(
                    get: { editModel.getValue("incompleteDir", fallback: config.incompleteDir) },
                    set: { editModel.setValue("incompleteDir", $0, original: config.incompleteDir) }
                ))
                .textFieldStyle(.roundedBorder)
                .disabled(!editModel.getValue("incompleteDirEnabled", fallback: config.incompleteDirEnabled))
            }
            
            Toggle("Start Added Torrents", isOn: Binding(
                get: { editModel.getValue("startAddedTorrents", fallback: config.startAddedTorrents) },
                set: { editModel.setValue("startAddedTorrents", $0, original: config.startAddedTorrents) }
            ))
            .platformToggleStyle()
        }
        .padding(10)
    }
}


// Platform-specific toggle styling
extension View {
    func platformToggleStyle() -> some View {
        #if os(macOS)
        self.toggleStyle(.checkbox)
        #elseif os(iOS)
        self.toggleStyle(.switch)
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