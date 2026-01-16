//
//  SlideToConfirm.swift
//  Avocadough
//

import SwiftUI

// MARK: - SlideToConfirm

/// A slide-to-confirm button for high-stakes actions like sending payments
struct SlideToConfirm: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let isLoading: Bool
    let onComplete: () -> Void

    @State private var sliderOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isComplete = false
    @State private var completeTrigger = false

    private let sliderSize: CGFloat = 56
    private let trackPadding: CGFloat = 4

    init(
        title: LocalizedStringKey = "Slide to Send",
        subtitle: LocalizedStringKey? = nil,
        isLoading: Bool = false,
        onComplete: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isLoading = isLoading
        self.onComplete = onComplete
    }

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width
            let maxOffset = trackWidth - sliderSize - (trackPadding * 2)
            let progress = min(sliderOffset / maxOffset, 1.0)

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: (sliderSize + trackPadding * 2) / 2)
                    .fill(DesignTokens.Colors.Background.tertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: (sliderSize + trackPadding * 2) / 2)
                            .strokeBorder(DesignTokens.Colors.Component.border, lineWidth: 1)
                    )

                // Progress fill
                RoundedRectangle(cornerRadius: (sliderSize + trackPadding * 2) / 2)
                    .fill(DesignTokens.Colors.Accent.primary.opacity(0.2))
                    .frame(width: sliderOffset + sliderSize + trackPadding * 2)

                // Label
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text(title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(Color.ds.textSecondary)

                        if let subtitle {
                            Text(subtitle)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(Color.ds.textTertiary)
                        }
                    }
                    .opacity(1 - progress)
                    Spacer()
                }

                // Slider thumb
                Circle()
                    .fill(isComplete ? DesignTokens.Colors.Semantic.connected : DesignTokens.Colors.Accent.primary)
                    .frame(width: sliderSize, height: sliderSize)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else if isComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .offset(x: isDragging ? 2 : 0)
                        }
                    }
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .offset(x: trackPadding + sliderOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !isComplete && !isLoading else { return }
                                isDragging = true
                                sliderOffset = min(max(0, value.translation.width), maxOffset)
                            }
                            .onEnded { _ in
                                isDragging = false
                                if sliderOffset >= maxOffset * 0.9 {
                                    // Complete!
                                    withAnimation(DesignTokens.Animation.bouncy) {
                                        sliderOffset = maxOffset
                                        isComplete = true
                                        completeTrigger.toggle()
                                    }
                                    onComplete()
                                } else {
                                    // Reset
                                    withAnimation(DesignTokens.Animation.bouncy) {
                                        sliderOffset = 0
                                    }
                                }
                            }
                    )
                    .animation(isDragging ? nil : DesignTokens.Animation.bouncy, value: sliderOffset)
            }
        }
        .frame(height: sliderSize + trackPadding * 2)
        .sensoryFeedback(AppHaptics.slideComplete, trigger: completeTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: isDragging)
        .disabled(isLoading || isComplete)
    }

    /// Reset the slider to initial state
    func reset() {
        withAnimation(DesignTokens.Animation.snappy) {
            sliderOffset = 0
            isComplete = false
        }
    }
}

// MARK: - Preview

#Preview("Slide to Confirm") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        SlideToConfirm(title: "Slide to Send", subtitle: "21,000 sats") {
            print("Confirmed!")
        }

        SlideToConfirm(title: "Slide to Confirm", isLoading: true) {
            print("Loading...")
        }
    }
    .padding()
}
