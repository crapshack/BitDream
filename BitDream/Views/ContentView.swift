//
//  ContentView.swift
//  BitDream
//
//  Created by Austin Smith on 12/29/22.
//

import SwiftUI
import Foundation
import KeychainAccess
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Host.entity(),
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) var hosts: FetchedResults<Host>

    @ObservedObject var store: Store = Store()

    var body: some View {
        #if os(iOS)
        iOSContentView(viewContext: viewContext, hosts: hosts, store: store)
        #elseif os(macOS)
        macOSContentView(viewContext: viewContext, hosts: hosts, store: store)
        #endif
    }
}
