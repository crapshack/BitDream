import SwiftUI
import Foundation
import KeychainAccess
import CoreData

#if os(macOS)
struct macOSContentView: View {
    let viewContext: NSManagedObjectContext
    let hosts: FetchedResults<Host>
    @ObservedObject var store: Store
    
    @State var torrentSelection: Torrent?
    @State var sortBySelection: sortBy = .name
    @State var filterBySelection: [TorrentStatusCalc] = TorrentStatusCalc.allCases
    @State private var sidebarSelection: SidebarSelection = .allDreams
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            macOSSidebar
        } content: {
            // Content (middle pane)
            VStack(spacing: 0) {
                StatsHeaderView(store: store)
                
                VStack(spacing: 0) {
                    // Debug text to show torrent count
                    Text("Torrents: \(store.torrents.count)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 4)
                    
                    // Torrent list
                    List(selection: $torrentSelection) {
                        if store.torrents.isEmpty {
                            Text("No torrents available")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(store.torrents
                                    .filtered(by: filterBySelection)
                                    .sorted(by: sortBySelection), id: \.id) { torrent in
                                NavigationLink {
                                    TorrentDetail(store: store, viewContext: viewContext, torrent: binding(for: torrent, in: store))
                                } label: {
                                    TorrentListRow(torrent: binding(for: torrent, in: store), store: store)
                                }
                                .tag(torrent)
                                .listRowSeparator(.visible)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Dreams")
            .toolbar {
                // Content toolbar items
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button("All") {
                            filterBySelection = TorrentStatusCalc.allCases
                        }
                        Button("Downloading") {
                            filterBySelection = [.downloading]
                        }
                        Button("Complete") {
                            filterBySelection = [.complete]
                        }
                        Button("Paused") {
                            filterBySelection = [.paused]
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Menu {
                        ForEach(sortBy.allCases, id: \.self) { item in
                            Button(action: {
                                sortBySelection = item
                            }) {
                                Label(item.rawValue, systemImage: sortBySelection == item ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                
                // Add torrent button
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        store.isShowingAddAlert.toggle()
                    }) {
                        Label("Add Torrent", systemImage: "plus")
                    }
                }
                
                // Pause all button
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        playPauseAllTorrents(start: false, info: makeConfig(store: store), onResponse: { response in
                            updateList(store: store, update: {_ in})
                        })
                    }) {
                        Label("Pause All", systemImage: "pause")
                    }
                }
                
                // Resume all button
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        playPauseAllTorrents(start: true, info: makeConfig(store: store), onResponse: { response in
                            updateList(store: store, update: {_ in})
                        })
                    }) {
                        Label("Resume All", systemImage: "play")
                    }
                }
            }
            .refreshable {
                updateList(store: store, update: {_ in})
            }
            .frame(minWidth: 300)
        } detail: {
            // Detail (right pane)
            macOSDetail
        }
        .sheet(isPresented: $store.setup) {
            ServerDetail(store: store, viewContext: viewContext, hosts: hosts, isAddNew: true)
        }
        .sheet(isPresented: $store.editServers) {
            ServerList(viewContext: viewContext, store: store)
        }
        .sheet(isPresented: $store.isShowingAddAlert) {
            AddTorrent(store: store)
        }
        .sheet(isPresented: $store.isShowingTransferFiles) {
            FileSelectDialog(store: store)
                .frame(width: 400, height: 500)
        }
        .sheet(isPresented: $store.isError) {
            ErrorDialog(store: store)
                .frame(width: 400, height: 400)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            setupHost(hosts: hosts, store: store)
            // Force refresh data when view appears
            updateList(store: store, update: { _ in })
        }
    }
    
    // MARK: - macOS Views
    
    private var macOSSidebar: some View {
        List(selection: $sidebarSelection) {
            Section("Library") {
                ForEach(SidebarSelection.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon)
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
            }
        }
        .onChange(of: sidebarSelection) { newValue in
            filterBySelection = newValue.filter
            print("\(newValue.rawValue) selected")
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
    
    private var macOSDetail: some View {
        Group {
            if let selectedTorrent = torrentSelection {
                TorrentDetail(store: store, viewContext: viewContext, torrent: binding(for: selectedTorrent, in: store))
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "arrow.left")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Select a Dream")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
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