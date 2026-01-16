//
//  AvocadoButton.swift
//  Avocadough
//

import SwiftUI

// MARK: - Button Variant

/// Available button variants for different use cases
enum AvocadoButtonVariant {
    /// Primary action button - filled background
    case primary
    /// Secondary action button - outlined
    case secondary
    /// Ghost/text button - minimal styling
    case ghost
    /// Destructive action - red styling
    case destructive
}

// MARK: - Button Size

/// Available button sizes
enum AvocadoButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: DesignTokens.ComponentSize.Button.sm
        case .medium: DesignTokens.ComponentSize.Button.md
        case .large: DesignTokens.ComponentSize.Button.lg
        }
    }

    var font: Font {
        switch self {
        case .small: DesignTokens.Typography.subheadline
        case .medium: DesignTokens.Typography.headline
        case .large: DesignTokens.Typography.headline
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: DesignTokens.Spacing.md
        case .medium: DesignTokens.Spacing.lg
        case .large: DesignTokens.Spacing.xl
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: DesignTokens.Radius.sm
        case .medium: DesignTokens.Radius.md
        case .large: DesignTokens.Radius.md
        }
    }
}

// MARK: - AvocadoButton Style

struct AvocadoButtonStyle: ButtonStyle {
    let variant: AvocadoButtonVariant
    let size: AvocadoButtonSize
    let isFullWidth: Bool
    let isLoading: Bool

    @Environment(\.isEnabled) private var isEnabled

    init(
        variant: AvocadoButtonVariant = .primary,
        size: AvocadoButtonSize = .large,
        isFullWidth: Bool = true,
        isLoading: Bool = false
    ) {
        self.variant = variant
        self.size = size
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
    }

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        HStack(spacing: DesignTokens.Spacing.sm) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                    .scaleEffect(0.8)
            }

            configuration.label
                .opacity(isLoading ? 0 : 1)
        }
        .font(size.font)
        .fontWeight(.semibold)
        .foregroundStyle(foregroundColor)
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .frame(height: size.height)
        .padding(.horizontal, size.horizontalPadding)
        .background(backgroundView(isPressed: isPressed))
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
        .overlay(overlayView)
        .opacity(isEnabled ? 1 : 0.5)
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(DesignTokens.Animation.snappy, value: isPressed)
        .contentShape(Rectangle())
        .sensoryFeedback(AppHaptics.buttonTap, trigger: isPressed) { oldValue, newValue in
            !oldValue && newValue // Only on press down
        }
    }

    // MARK: - Computed Properties

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            Color.white
        case .secondary:
            DesignTokens.Colors.Accent.primary
        case .ghost:
            DesignTokens.Colors.Accent.primary
        case .destructive:
            Color.white
        }
    }

    @ViewBuilder
    private func backgroundView(isPressed: Bool) -> some View {
        switch variant {
        case .primary:
            DesignTokens.Colors.Accent.primary
                .opacity(isPressed ? 0.8 : 1)
        case .secondary:
            Color.clear
        case .ghost:
            Color.clear
                .opacity(isPressed ? 0.1 : 0)
        case .destructive:
            DesignTokens.Colors.Semantic.error
                .opacity(isPressed ? 0.8 : 1)
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        switch variant {
        case .secondary:
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .strokeBorder(DesignTokens.Colors.Accent.primary, lineWidth: 2)
        default:
            EmptyView()
        }
    }
}

// MARK: - Button Style Extension

extension ButtonStyle where Self == AvocadoButtonStyle {
    /// Primary filled button
    static var avocadoPrimary: AvocadoButtonStyle {
        AvocadoButtonStyle(variant: .primary)
    }

    /// Secondary outlined button
    static var avocadoSecondary: AvocadoButtonStyle {
        AvocadoButtonStyle(variant: .secondary)
    }

    /// Ghost/text button
    static var avocadoGhost: AvocadoButtonStyle {
        AvocadoButtonStyle(variant: .ghost)
    }

    /// Destructive button
    static var avocadoDestructive: AvocadoButtonStyle {
        AvocadoButtonStyle(variant: .destructive)
    }

    /// Custom configuration
    static func avocado(
        variant: AvocadoButtonVariant = .primary,
        size: AvocadoButtonSize = .large,
        isFullWidth: Bool = true,
        isLoading: Bool = false
    ) -> AvocadoButtonStyle {
        AvocadoButtonStyle(
            variant: variant,
            size: size,
            isFullWidth: isFullWidth,
            isLoading: isLoading
        )
    }
}

// MARK: - Convenience Button View

/// A pre-styled button component using the Avocadough design system
struct AvocadoButton: View {
    let title: LocalizedStringKey
    let icon: String?
    let variant: AvocadoButtonVariant
    let size: AvocadoButtonSize
    let isFullWidth: Bool
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        icon: String? = nil,
        variant: AvocadoButtonVariant = .primary,
        size: AvocadoButtonSize = .large,
        isFullWidth: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.size = size
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
        }
        .buttonStyle(.avocado(
            variant: variant,
            size: size,
            isFullWidth: isFullWidth,
            isLoading: isLoading
        ))
    }
}

// MARK: - Icon-Only Button

/// A circular icon button
struct AvocadoIconButton: View {
    let icon: String
    let variant: AvocadoButtonVariant
    let size: CGFloat
    let action: () -> Void

    @State private var tapTrigger = false

    init(
        icon: String,
        variant: AvocadoButtonVariant = .secondary,
        size: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.variant = variant
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: {
            tapTrigger.toggle()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
                .overlay(overlayView)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(AppHaptics.buttonTap, trigger: tapTrigger)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: .white
        case .secondary: DesignTokens.Colors.Accent.primary
        case .ghost: DesignTokens.Colors.Accent.primary
        case .destructive: .white
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: DesignTokens.Colors.Accent.primary
        case .secondary: .clear
        case .ghost: DesignTokens.Colors.Component.fillTertiary
        case .destructive: DesignTokens.Colors.Semantic.error
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        if variant == .secondary {
            Circle()
                .strokeBorder(DesignTokens.Colors.Accent.primary, lineWidth: 2)
        }
    }
}

// MARK: - Previews

#Preview("Button Variants") {
    VStack(spacing: DesignTokens.Spacing.md) {
        AvocadoButton("Primary Button", icon: "arrow.up.right", variant: .primary) {}

        AvocadoButton("Secondary Button", icon: "arrow.down.left", variant: .secondary) {}

        AvocadoButton("Ghost Button", variant: .ghost) {}

        AvocadoButton("Destructive", icon: "trash", variant: .destructive) {}

        AvocadoButton("Loading...", variant: .primary, isLoading: true) {}
    }
    .padding()
}

#Preview("Button Sizes") {
    VStack(spacing: DesignTokens.Spacing.md) {
        AvocadoButton("Large Button", size: .large) {}

        AvocadoButton("Medium Button", size: .medium) {}

        AvocadoButton("Small Button", size: .small) {}
    }
    .padding()
}

#Preview("Icon Buttons") {
    HStack(spacing: DesignTokens.Spacing.md) {
        AvocadoIconButton(icon: "qrcode.viewfinder", variant: .primary) {}
        AvocadoIconButton(icon: "doc.on.doc", variant: .secondary) {}
        AvocadoIconButton(icon: "square.and.arrow.up", variant: .ghost) {}
        AvocadoIconButton(icon: "xmark", variant: .destructive) {}
    }
}
