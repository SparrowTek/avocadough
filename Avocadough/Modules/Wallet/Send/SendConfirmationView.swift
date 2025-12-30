//
//  SendConfirmationView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 3/23/24.
//

import SwiftUI
import LightningDevKit

struct SendConfirmationView: View {
    @Environment(SendState.self) private var state
    @Environment(\.nwc) private var nwc
    var bolt11: Bolt11Invoice
    @State private var confirmationTrigger = PlainTaskTrigger()
    @State private var requestInProgress = false
    @State private var errorMessage: LocalizedStringKey?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Confirm invoice:")
                .bold()
                .padding(.horizontal)
            Text("\((bolt11.amountMilliSatoshis() ?? 0) / 1000) sats")
                .bold()
                .padding([.horizontal, .bottom])
            
            Text(bolt11.toStr())
                .padding(.horizontal)
            
            Button(action: triggerConfirmation) {
                ZStack {
                    Text("confirm")
                        .opacity(requestInProgress ? 0 : 1)
                    ProgressView()
                        .opacity(requestInProgress ? 1 : 0)
                }
            }
            .buttonStyle(.avocadough)
            .padding()
        }
        .task($confirmationTrigger) { await confirm() }
        .alert($errorMessage)
    }
    
    private func triggerConfirmation() {
        confirmationTrigger.trigger()
    }
    
    private func confirm() async {
        defer { requestInProgress = false }
        requestInProgress = true
        
        do {
            try await nwc.payInvoice(bolt11.toStr())
        } catch {
            errorMessage = "There was a problem confirming your payment. Please try again later"
        }
    }
}

#Preview {
    SendConfirmationView(bolt11: Bolt11Invoice.fromStr(s: "lnbc20u1pn2hnhmpp5hf964hhc77lf4vjpltdnuma0fdl2pp2afagzueg8h2gv8x2ju5tqdpzw3jhxarfdenjqnzyfvsxjm3qgfhk7um50gcqzzsxqyz5vqsp5a8ayrhgzyhgce6y49m9z5ypvngslkkajjfz8dx3qeg94gtl6dg9q9qxpqysgq53s3ddmvy0x2lq3jm06lh9eul0w8mtmgpct09g68uuketgw2xvsyfwmm6qjj9t7hrtu8ul859c93ggaz69quj9ltpszt4022cca6znsq9v2lmp").getValue()!)
        .environment(SendState(parentState: .init(parentState: .init())))
}
