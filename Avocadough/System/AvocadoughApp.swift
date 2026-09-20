//
//  AvocadoughApp.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/9/23.
//

import SwiftUI

@main
struct AvocadoughApp: App {
    @State private var state = AppState()
    @State private var reachability = Reachability()
    @State private var nwc = NWC()
    
    var body: some Scene {
        WindowGroup {
            AppPresenter()
                .setTheme()
                .environment(state)
                .setupModel()
                .environment(\.nwc, nwc)
                .environment(\.reachability, reachability)
                .environment(\.diagnostics, DiagnosticsLog.shared)
        }
    }
}
