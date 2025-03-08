//
//  ContentView.swift
//  BitDream
//
//  Created by Austin Smith on 12/29/22.
//

import SwiftUI
import Foundation
import KeychainAccess

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Host.entity(),
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) var hosts: FetchedResults<Host>

    @ObservedObject var store: Store = Store()

    private var keychain = Keychain(service: "crapshack.BitDream")

    @State var torrentSelection: Torrent?
    @State var sortBySelection: sortBy = .name
    @State var filterBySelection: [TorrentStatusCalc] = TorrentStatusCalc.allCases

    var body: some View {
        NavigationSplitView {
            VStack {
                statsHeader
                
                #if os(iOS)
                List(selection: $torrentSelection) {
                    torrentRows
                }
                .listStyle(PlainListStyle())
                #else
                List {
                    torrentRows
                }
                .padding(.trailing, 12)
                #endif
            }
            .navigationTitle("Dreams")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .refreshable {
                updateList(store: store, update: {_ in})
            }
            .toolbar {
                serverToolbarItem
                actionToolbarItems
            }
            .onAppear(perform: setupHost)
        } detail: {
            if let selectedTorrent = torrentSelection {
                TorrentDetail(store: store, viewContext: viewContext, torrent: binding(for: selectedTorrent))
            } else {
                Text("No Selection")
            }
        }
        // Sheets
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
    }
    
    // MARK: - Extracted Views
    
    private var statsHeader: some View {
        VStack {
            Divider()
            HStack {
                Text(String("\(store.sessionStats?.activeTorrentCount ?? 0) active dreams"))
                Spacer()
                Text(String("▼ \(byteCountFormatter.string(fromByteCount: store.sessionStats?.downloadSpeed ?? 0))/s"))
                Text(String("▲ \(byteCountFormatter.string(fromByteCount: store.sessionStats?.uploadSpeed ?? 0))/s"))
            }
            .font(.subheadline)
            .padding([.leading, .trailing])
            Divider()
        }
    }
    
    private var torrentRows: some View {
        ForEach(sortTorrents(store.torrents.filter() {filterBySelection.contains([$0.statusCalc])}, sortBy: sortBySelection), id: \.id) { torrent in
            #if os(iOS)
            NavigationLink(value: torrent) {
                TorrentListRow(torrent: binding(for: torrent), store: store)
            }
            #else
            NavigationLink(destination: TorrentDetail(store: store, viewContext: viewContext, torrent: binding(for: torrent))) {
                TorrentListRow(torrent: binding(for: torrent), store: store)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        torrentSelection = torrent
                    }
                    .listRowSeparator(.hidden)
            }
            .listRowSeparator(.visible)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(torrent == torrentSelection ? Color.accentColor.opacity(0.5) : Color(.clear))
                    .padding(.leading, 12)
            )
            #endif
        }
    }
    
    private var serverToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Menu {
                Menu {
                    ForEach(hosts, id: \.self) { host in
                        Button(action: {
                            store.setHost(host: host)
                        }) {
                            Label(host.name!, systemImage: host == store.host ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label("Server", systemImage: "arrow.triangle.2.circlepath")
                }
                Divider()
                Button(action: {store.setup.toggle()}) {
                    Label("Add", systemImage: "plus")
                }
                Button(action: {store.editServers.toggle()}) {
                    Label("Edit", systemImage: "square.and.pencil")
                }
            } label: {
                Image(systemName: "server.rack")
            }
        }
    }
    
    private var actionToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Menu {
                Menu {
                    Section(header: Text("Include")) {
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
                    }
                    Section(header: Text("Exclude")) {
                        Button("Complete") {
                            filterBySelection = TorrentStatusCalc.allCases.filter {$0 != .complete}
                        }
                    }
                } label: {
                    Text("Filter By")
                    Image(systemName: "slider.horizontal.3")
                }.environment(\.menuOrder, .fixed)
                
                Menu {
                    Picker("Sort By", selection: $sortBySelection) {
                        ForEach(sortBy.allCases, id: \.self) { item in
                            Text(item.rawValue)
                        }
                        .pickerStyle(.automatic)
                    }
                } label: {
                    Text("Sort By")
                    Image(systemName: "arrow.up.arrow.down")
                }.environment(\.menuOrder, .fixed)
                
                Divider()
                
                Button(action: {
                    playPauseAllTorrents(start: false, info: makeConfig(store: store), onResponse: { response in
                        updateList(store: store, update: {_ in})
                    })
                }) {
                    Label("Pause All", systemImage: "pause")
                }
                
                Button(action: {
                    playPauseAllTorrents(start: true, info: makeConfig(store: store), onResponse: { response in
                        updateList(store: store, update: {_ in})
                    })
                }) {
                    Label("Resume All", systemImage: "play")
                }
                
                Divider()
                
                Button(action: {
                    store.isShowingAddAlert.toggle()
                }) {
                    Label("Add Torrent", systemImage: "plus")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupHost() {
        hosts.forEach { h in
            if (h.isDefault) {
                store.setHost(host: h)
            }
        }
        if (store.host != nil) {
            store.startTimer()
        } else {
            // Create a new host
            store.setup = true
        }
    }

    func binding(for torrent: Torrent) -> Binding<Torrent> {
        guard let scrumIndex = store.torrents.firstIndex(where: { $0.id == torrent.id }) else {
            fatalError("Can't find in array")
        }
        return $store.torrents[scrumIndex]
    }
}
