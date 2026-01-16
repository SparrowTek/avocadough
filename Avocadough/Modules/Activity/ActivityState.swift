//
//  ActivityState.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 1/16/26.
//

import SwiftUI

@MainActor
@Observable
class ActivityState {
    unowned var parentState: AppState
    
    enum Sheet: Identifiable {
        case open(Transaction)

        var id: Int {
            switch self {
            case .open: 0
            }
        }
    }
    
    var sheet: Sheet?
    
    init(parentState: AppState) {
        self.parentState = parentState
    }
    
    func refresh() async {
        parentState.refresh()
    }
    
    func getMoreTransactions() {
        parentState.getMoreTransactions()
    }
}
