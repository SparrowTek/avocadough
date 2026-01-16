//
//  ConfigView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/31/23.
//

import SwiftUI

struct ConfigView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showContent = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Logo with pulse
            ZStack {
                if !reduceMotion {
                    Circle()
                        .stroke(DesignTokens.Colors.Accent.primary.opacity(0.2), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseScale)
                }

                Circle()
                    .fill(DesignTokens.Colors.Accent.primary)
                    .frame(width: 80, height: 80)

                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                    Image(systemName: "bolt.fill")
                }
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            }
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.8)

            // Loading text
            VStack(spacing: DesignTokens.Spacing.md) {
                Text("Preparing your wallet")
                    .font(DesignTokens.Typography.title2)
                    .foregroundStyle(Color.ds.textPrimary)

                ProgressView()
                    .scaleEffect(1.2)
                    .tint(DesignTokens.Colors.Accent.primary)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            Spacer()
        }
        .fullScreenColorView()
        .syncConfigData()
        .onAppear(perform: animateIn)
        .animation(reduceMotion ? .none : DesignTokens.Animation.smooth, value: showContent)
    }

    private func animateIn() {
        showContent = true

        if !reduceMotion {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.2
            }
        }
    }
}

#Preview {
    ConfigView()
        .environment(AppState())
}
