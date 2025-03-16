import SwiftUI
import Foundation
import KeychainAccess
import CoreData

#if os(macOS)
struct macOSContentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    @State private var showingThemeSettings = false
    let viewContext: NSManagedObjectContext
    let hosts: FetchedResults<Host>
    @ObservedObject var store: Store
    
    // Add ThemeManager to access accent color
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var selectedTorrentId: Int? = nil
    
    // Computed property to get the selected torrent from the ID
    private var torrentSelection: Binding<Torrent?> {
        createTorrentSelectionBinding(selectedId: $selectedTorrentId, in: store)
    }
    
    @State var sortBySelection: sortBy = UserDefaults.standard.sortBySelection
    @State var filterBySelection: [TorrentStatusCalc] = TorrentStatusCalc.allCases
    @State private var sidebarSelection: SidebarSelection = .allDreams
    @State private var isInspectorVisible: Bool = UserDefaults.standard.inspectorVisibility
    @State private var columnVisibility: NavigationSplitViewVisibility = UserDefaults.standard.sidebarVisibility
    @State private var searchText: String = ""
    @State private var titleRefreshTrigger: Bool = false
    
    // Helper function to check if a torrent matches the search query
    private func torrentMatchesSearch(_ torrent: Torrent, query: String) -> Bool {
        if query.isEmpty {
            return true
        }
        // Search in name
        if torrent.name.localizedCaseInsensitiveContains(query) {
            return true
        }
        // Search in labels
        return torrent.labels.contains { label in
            label.localizedCaseInsensitiveContains(query)
        }
    }
    
    // Computed property to get counts for each category
    private func torrentCount(for category: SidebarSelection) -> Int {
        let filteredByCategory = store.torrents.filtered(by: category.filter)
        let filteredBySearch = filteredByCategory.filter { torrent in
            torrentMatchesSearch(torrent, query: searchText)
        }
        return filteredBySearch.count
    }
    
    // Computed property to get completed torrents count
    private var completedTorrentsCount: Int {
        getCompletedTorrentsCount(in: store)
    }
    
    // Update the app badge
    private func updateAppBadge() {
        updateMacOSAppBadge(count: completedTorrentsCount)
    }
    
    // Computed property for navigation subtitle
    private var navigationSubtitle: String {
        let count = torrentCount(for: sidebarSelection)
        return "\(count) dream\(count == 1 ? "" : "s")"
    }
    
    var body: some View {       
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            List(selection: $sidebarSelection) {
                Section("Dreams") {
                    ForEach(SidebarSelection.allCases) { item in
                        Label(item.rawValue, systemImage: item.icon)
                            .badge(torrentCount(for: item))
                            .tag(item)
                    }
                }
                
                Section("Servers") {
                    ForEach(hosts, id: \.self) { host in
                        Button {
                            store.setHost(host: host)
                            // Force refresh data when changing host
                            updateList(store: store, update: { _ in })
                        } label: {
                            HStack {
                                Label(host.name!, systemImage: "server.rack")
                                Spacer()
                                if host == store.host {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button {
                        store.setup.toggle()
                    } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                }
                
                Section("Settings") {
                    Button {
                        store.editServers.toggle()
                    } label: {
                        Label("Manage Servers", systemImage: "gearshape")
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        openSettings()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(SidebarListStyle())
            .tint(themeManager.accentColor) // Apply accent color to sidebar selection
        } detail: {
            // Content (middle pane)
            VStack(spacing: 0) {
                StatsHeaderView(store: store)
                
                VStack {
                    // Torrent list
                    List(selection: torrentSelection) {
                        if store.torrents.isEmpty {
                            Text("No dreams available")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            // Break up the complex expression into steps
                            let filteredTorrents = store.torrents.filtered(by: filterBySelection)
                                .filter { torrent in
                                    torrentMatchesSearch(torrent, query: searchText)
                                }
                            let sortedTorrents = filteredTorrents.sorted(by: sortBySelection)
                            
                            ForEach(sortedTorrents, id: \.id) { torrent in
                                NavigationLink(value: torrent) {
                                    TorrentListRow(torrent: binding(for: torrent, in: store), store: store)
                                }
                                .tag(torrent)
                                .id(torrent.id)
                                .listRowSeparator(.visible)
                            }
                        }
                    }
                    .navigationDestination(for: Torrent.self) { torrent in
                        TorrentDetail(store: store, viewContext: viewContext, torrent: binding(for: torrent, in: store))
                    }
                    .listStyle(PlainListStyle())
                    .tint(themeManager.accentColor) // Apply accent color to list selection
                }
            }
            .navigationTitle(titleRefreshTrigger ? sidebarSelection.rawValue : sidebarSelection.rawValue)
            .navigationSubtitle(titleRefreshTrigger ? navigationSubtitle : navigationSubtitle)
            .searchable(text: $searchText, placement: .toolbar)
            .toolbar {              
                // Content toolbar items
                ToolbarItem(placement: .automatic) {
                    Picker("", selection: $sortBySelection) {
                        Group {
                            Text("Name ↑").tag(sortBy.nameAsc)
                            Text("Name ↓").tag(sortBy.nameDesc)
                        }
                        
                        Divider()
                        
                        Group {
                            Text("Date Added ↑").tag(sortBy.dateAddedAsc)
                            Text("Date Added ↓").tag(sortBy.dateAddedDesc)
                        }
                        
                        Divider()
                        
                        Group {
                            Text("Status ↑").tag(sortBy.statusAsc)
                            Text("Status ↓").tag(sortBy.statusDesc)
                        }
                        
                        Divider()
                        
                        Group {
                            Text("Remaining Time ↑").tag(sortBy.etaAsc)
                            Text("Remaining Time ↓").tag(sortBy.etaDesc)
                        }
                    }
                    .help("Sort by")
                }

                // Add torrent button
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        store.isShowingAddAlert.toggle()
                    }) {
                        Label("Add Torrent", systemImage: "document.badge.plus")
                    }
                    .help("Add a new torrent")
                }
                
                // // Pause all button
                // ToolbarItem(placement: .automatic) {
                //     Button(action: {
                //         playPauseAllTorrents(start: false, info: makeConfig(store: store), onResponse: { response in
                //             updateList(store: store, update: {_ in})
                //         })
                //     }) {
                //         Label("Pause All", systemImage: "pause")
                //     }
                //     .help("Pause all active torrents")
                // }
                
                // // Resume all button
                // ToolbarItem(placement: .automatic) {
                //     Button(action: {
                //         playPauseAllTorrents(start: true, info: makeConfig(store: store), onResponse: { response in
                //             updateList(store: store, update: {_ in})
                //         })
                //     }) {
                //         Label("Resume All", systemImage: "play")
                //     }
                //     .help("Resume all paused torrents")
                // }
                
                // Add spacer between sort and inspector buttons
                ToolbarItem(placement: .automatic) {
                    Spacer()
                }
                
                // Toggle inspector button
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        // Toggle inspector visibility
                        withAnimation {
                            isInspectorVisible.toggle()
                        }
                    }) {
                        Label("Inspector", systemImage: "sidebar.right")
                    }
                    .help(isInspectorVisible ? "Hide inspector" : "Show inspector")
                }
            }
            .refreshable {
                updateList(store: store, update: {_ in})
            }
            .inspector(isPresented: $isInspectorVisible) {
                macOSDetail
                    .inspectorColumnWidth(min: 350, ideal: 400, max: 500)
            }
        }
        .sheet(isPresented: $store.setup) {
            ServerDetail(store: store, viewContext: viewContext, hosts: hosts, isAddNew: true)
        }
        .sheet(isPresented: $store.editServers) {
            ServerList(store: store, viewContext: viewContext)
        }
        .sheet(isPresented: $store.isShowingAddAlert) {
            AddTorrent(store: store)
        }
        .sheet(isPresented: $store.isError) {
            ErrorDialog(store: store)
                .frame(width: 400, height: 400)
        }
        .tint(themeManager.accentColor) // Apply tint to NavigationSplitView
        .accentColor(themeManager.accentColor) // Apply accent color to the entire view
        .onChange(of: sidebarSelection) { oldValue, newValue in
            // Update the filter
            filterBySelection = newValue.filter
            
            // Only clear selection if the selected torrent isn't in the new filtered list
            if let selectedTorrent = torrentSelection.wrappedValue {
                // Break up the complex expression
                let filteredTorrents = store.torrents.filtered(by: newValue.filter)
                let isSelectedTorrentInFilteredList = filteredTorrents.contains { $0.id == selectedTorrent.id }
                
                if !isSelectedTorrentInFilteredList {
                    // Selected torrent is not in the new filtered list, clear selection
                    torrentSelection.wrappedValue = nil
                }
            }
            
            // Refresh the navigation title and subtitle
            titleRefreshTrigger.toggle()
            
            print("\(newValue.rawValue) selected")
        }
        .onReceive(store.$torrents) { _ in
            updateAppBadge()
            // Refresh the navigation title and subtitle
            titleRefreshTrigger.toggle()
        }
        .onAppear {
            setupHost(hosts: hosts, store: store)
            updateAppBadge()
        }
        .onChange(of: columnVisibility) { oldValue, newValue in
            UserDefaults.standard.sidebarVisibility = newValue
        }
        .onChange(of: isInspectorVisible) { oldValue, newValue in
            UserDefaults.standard.inspectorVisibility = newValue
        }
        .onChange(of: sortBySelection) { oldValue, newValue in
            UserDefaults.standard.sortBySelection = newValue
        }
        .onChange(of: searchText) { oldValue, newValue in
            // Only clear selection if the selected torrent isn't in the new filtered list
            if let selectedTorrent = torrentSelection.wrappedValue {
                // Check if the selected torrent matches the search filter
                let matchesSearch = torrentMatchesSearch(selectedTorrent, query: searchText)
                
                // Check if the selected torrent matches the category filter
                let filteredTorrents = store.torrents.filtered(by: filterBySelection)
                let isSelectedTorrentInFilteredList = filteredTorrents.contains { $0.id == selectedTorrent.id }
                
                if !matchesSearch || !isSelectedTorrentInFilteredList {
                    // Selected torrent is not in the new filtered list, clear selection
                    torrentSelection.wrappedValue = nil
                }
            }
            
            // Refresh the navigation title and subtitle
            titleRefreshTrigger.toggle()
        }
    }
    
    // MARK: - macOS Views
    
    private var macOSDetail: some View {
        Group {
            if let selectedTorrent = torrentSelection.wrappedValue {
                TorrentDetail(store: store, viewContext: viewContext, torrent: binding(for: selectedTorrent, in: store))
                    .id(selectedTorrent.id)
            } else {
                VStack {
                    Spacer()
                    Text("💭")
                        .font(.system(size: 40))
                        .padding(.bottom, 8)
                    Text("Select a Dream")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
#else
// Empty struct for iOS to reference - this won't be compiled on iOS but provides the type
struct macOSContentView: View {
    let viewContext: NSManagedObjectContext
    let hosts: FetchedResults<Host>
    @ObservedObject var store: Store
    
    var body: some View {
        EmptyView()
    }
}
#endif 
