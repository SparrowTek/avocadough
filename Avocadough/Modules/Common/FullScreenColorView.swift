//
//  FullScreenColorView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/10/23.
//

import SwiftUI

fileprivate struct FullScreenColorView: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()
            content
        }
    }
}

extension View {
    func fullScreenColorView() -> some View {
        modifier(FullScreenColorView())
    }
}

#Preview {
    Text("common view")
        .fullScreenColorView()
        .foregroundStyle(.black)
}
