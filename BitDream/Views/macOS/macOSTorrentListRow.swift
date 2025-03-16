//
//  macOSTorrentListRow.swift
//  BitDream
//
//  Created by Austin Smith on 12/29/22.
//

import Foundation
import SwiftUI
import KeychainAccess

#if os(macOS)
struct macOSTorrentListRow: View {
    @Binding var torrent: Torrent
    var store: Store
    
    @State var deleteDialog: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            HStack {
                Text(torrent.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Display labels inline if present
                createLabelTagsView(for: torrent)
            }
            
            createStatusView(for: torrent)
                .font(.custom("sub", size: 10))
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .foregroundColor(.secondary)
            
            // Logic here is kind of funky, but we are going to fill up the entire progress bar if the
            // torrent is still retrieving metadata (as the bar will be colored red)
            ProgressView(value: torrent.metadataPercentComplete < 1 ? 1 : torrent.percentDone)
                .tint(progressColorForTorrent(torrent))
            
            Text(formatTorrentSubtext(torrent))
                .font(.custom("sub", size: 10))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .padding([.top, .bottom, .leading, .trailing], 10)
        .contextMenu {
            // Play/Pause Button
            Button(action: {
                let info = makeConfig(store: store)
                playPauseTorrent(torrent: torrent, config: info.config, auth: info.auth, onResponse: { response in
                    // TODO: Handle response
                })
            }) {
                HStack {
                    Image(systemName: torrent.status == TorrentStatus.stopped.rawValue ? "play" : "pause")
                    Text(torrent.status == TorrentStatus.stopped.rawValue ? "Resume Dream" : "Pause Dream")
                }
            }
            
            // Priority Menu
            Menu {
                Button(action: {
                    updateTorrentPriority(torrent: torrent, priority: TorrentPriority.high, info: makeConfig(store: store), onComplete: { r in })
                }) {
                    HStack {
                        Image(systemName: "arrow.up")
                        Text("High")
                    }
                }
                Button(action: {
                    updateTorrentPriority(torrent: torrent, priority: TorrentPriority.normal, info: makeConfig(store: store), onComplete: { r in })
                }) {
                    HStack {
                        Image(systemName: "minus")
                        Text("Normal")
                    }
                }
                Button(action: {
                    updateTorrentPriority(torrent: torrent, priority: TorrentPriority.low, info: makeConfig(store: store), onComplete: { r in })
                }) {
                    HStack {
                        Image(systemName: "arrow.down")
                        Text("Low")
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "flag.badge.ellipsis")
                    Text("Update Priority")
                }
            }
            
            Divider()
            
            // Copy Magnet Link Button
            Button(action: {
                copyMagnetLinkToClipboard(torrent.magnetLink)
            }) {
                HStack {
                    Image(systemName: "document.on.document.fill")
                    Text("Copy Magnet Link")
                }
            }
            
            Divider()
            
            // Delete Button
            Button(role: .destructive, action: {
                deleteDialog.toggle()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete")
                }
            }
        }
        .id(torrent.id)
        // Ask to delete files on disk when removing transfer
        .alert(
            "Delete Torrent",
            isPresented: $deleteDialog) {
                Button(role: .destructive) {
                    let info = makeConfig(store: store)
                    deleteTorrent(torrent: torrent, erase: true, config: info.config, auth: info.auth, onDel: { response in
                        // TODO: Handle response
                    })
                    deleteDialog.toggle()
                } label: {
                    Text("Delete file(s)")
                }
                Button("Remove from list only") {
                    let info = makeConfig(store: store)
                    deleteTorrent(torrent: torrent, erase: false, config: info.config, auth: info.auth, onDel: { response in
                        // TODO: Handle response
                    })
                    deleteDialog.toggle()
                }
            } message: {
                Text("Do you want to delete the file(s) from the disk?")
            }
            .interactiveDismissDisabled(false)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
        )
    }
}

// Shared function to create label tags view
func createLabelTagsView(for torrent: Torrent) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 4) {
            ForEach(torrent.labels, id: \.self) { label in
                Text(label)
                    .font(.caption)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                    )
            }
        }
    }
}

#else
// Empty struct for iOS to reference - this won't be compiled on iOS but provides the type
struct macOSTorrentListRow: View {
    @Binding var torrent: Torrent
    var store: Store
    
    var body: some View {
        EmptyView()
    }
}
#endif 