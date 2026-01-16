//
//  AvocadoCard.swift
//  Avocadough
//

import SwiftUI

// MARK: - Card Style

enum AvocadoCardStyle {
    /// Standard card with secondary background
    case standard
    /// Elevated card with shadow
    case elevated
    /// Outlined card with border
    case outlined
    /// Filled card with accent background
    case filled
    /// Transparent card
    case transparent
}

// MARK: - AvocadoCard

/// A versatile card container component for grouping related content
struct AvocadoCard<Content: View>: View {
    let style: AvocadoCardStyle
    let padding: CGFloat
    let cornerRadius: CGFloat
    let isInteractive: Bool
    let action: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @State private var isPressed = false
    @State private var tapTrigger = false

    init(
        style: AvocadoCardStyle = .standard,
        padding: CGFloat = DesignTokens.Spacing.md,
        cornerRadius: CGFloat = DesignTokens.Radius.lg,
        isInteractive: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive || action != nil
        self.action = action
        self.content = content
    }

    var body: some View {
        Group {
            if isInteractive {
                Button(action: handleTap) {
                    cardContent
                }
                .buttonStyle(.plain)
                .sensoryFeedback(AppHaptics.buttonTap, trigger: tapTrigger)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(overlayBorder)
            .shadow(
                color: shadowProperties.color,
                radius: shadowProperties.radius,
                x: shadowProperties.x,
                y: shadowProperties.y
            )
            .scaleEffect(isInteractive && isPressed ? 0.98 : 1)
            .animation(DesignTokens.Animation.snappy, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if isInteractive { isPressed = true }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }

    private func handleTap() {
        tapTrigger.toggle()
        action?()
    }

    // MARK: - Style Properties

    private var backgroundColor: Color {
        switch style {
        case .standard:
            DesignTokens.Colors.Background.secondary
        case .elevated:
            DesignTokens.Colors.Background.tertiary
        case .outlined:
            DesignTokens.Colors.Background.primary
        case .filled:
            DesignTokens.Colors.Accent.primary
        case .transparent:
            .clear
        }
    }

    @ViewBuilder
    private var overlayBorder: some View {
        if style == .outlined {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(DesignTokens.Colors.Component.border, lineWidth: 1)
        }
    }

    private var shadowProperties: DesignTokens.Shadow.Properties {
        switch style {
        case .elevated:
            DesignTokens.Shadow.md
        default:
            DesignTokens.Shadow.none
        }
    }
}

// MARK: - Balance Card (Specialized)

/// A specialized card for displaying balance information
struct BalanceCard<Content: View>: View {
    let isLoading: Bool
    @ViewBuilder let content: () -> Content

    @State private var shimmerPhase: CGFloat = 0

    init(
        isLoading: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.content = content
    }

    var body: some View {
        AvocadoCard(style: .elevated, padding: DesignTokens.Spacing.lg) {
            if isLoading {
                shimmerContent
            } else {
                content()
            }
        }
    }

    private var shimmerContent: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(shimmerGradient)
                .frame(width: 200, height: 48)

            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(shimmerGradient)
                .frame(width: 120, height: 24)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                DesignTokens.Colors.Component.fill,
                DesignTokens.Colors.Component.fillSecondary,
                DesignTokens.Colors.Component.fill
            ]),
            startPoint: .init(x: shimmerPhase - 1, y: 0.5),
            endPoint: .init(x: shimmerPhase, y: 0.5)
        )
    }
}

// MARK: - Transaction Card

/// A card optimized for displaying transaction information
struct TransactionCard: View {
    let type: TransactionDisplayType
    let amount: String
    let description: String
    let timestamp: String
    let action: (() -> Void)?

    enum TransactionDisplayType {
        case incoming
        case outgoing

        var icon: String {
            switch self {
            case .incoming: "arrow.down.left"
            case .outgoing: "arrow.up.right"
            }
        }

        var color: Color {
            switch self {
            case .incoming: DesignTokens.Colors.Semantic.incoming
            case .outgoing: DesignTokens.Colors.Semantic.outgoing
            }
        }

        var prefix: String {
            switch self {
            case .incoming: "+"
            case .outgoing: "-"
            }
        }
    }

    init(
        type: TransactionDisplayType,
        amount: String,
        description: String,
        timestamp: String,
        action: (() -> Void)? = nil
    ) {
        self.type = type
        self.amount = amount
        self.description = description
        self.timestamp = timestamp
        self.action = action
    }

    var body: some View {
        AvocadoCard(style: .standard, padding: DesignTokens.Spacing.md, action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Icon
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(type.color)
                    .frame(width: 36, height: 36)
                    .background(type.color.opacity(0.15))
                    .clipShape(Circle())

                // Details
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("\(type.prefix)\(amount)")
                        .font(DesignTokens.Typography.amountRow)
                        .foregroundStyle(type.color)

                    Text(description)
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(Color.ds.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Timestamp
                Text(timestamp)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(Color.ds.textTertiary)
            }
        }
    }
}

// MARK: - Info Card

/// A card for displaying information with an icon
struct InfoCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let iconColor: Color
    let style: AvocadoCardStyle
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        iconColor: Color = DesignTokens.Colors.Accent.primary,
        style: AvocadoCardStyle = .standard,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.iconColor = iconColor
        self.style = style
        self.action = action
    }

    var body: some View {
        AvocadoCard(style: style, action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(Color.ds.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.subheadline)
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                }

                Spacer()

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.ds.textTertiary)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Card Styles") {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.md) {
            AvocadoCard(style: .standard) {
                Text("Standard Card")
            }

            AvocadoCard(style: .elevated) {
                Text("Elevated Card")
            }

            AvocadoCard(style: .outlined) {
                Text("Outlined Card")
            }

            AvocadoCard(style: .filled) {
                Text("Filled Card")
                    .foregroundStyle(.white)
            }

            AvocadoCard(style: .standard, isInteractive: true) {
                Text("Interactive Card")
            }
        }
        .padding()
    }
}

#Preview("Balance Card") {
    VStack(spacing: DesignTokens.Spacing.md) {
        BalanceCard {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("1,234,567")
                    .balanceStyle()
                Text("sats")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(Color.ds.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }

        BalanceCard(isLoading: true) {
            EmptyView()
        }
    }
    .padding()
}

#Preview("Transaction Card") {
    VStack(spacing: DesignTokens.Spacing.sm) {
        TransactionCard(
            type: .incoming,
            amount: "21,000 sats",
            description: "Zap from @jack",
            timestamp: "2:34 PM"
        )

        TransactionCard(
            type: .outgoing,
            amount: "5,000 sats",
            description: "Coffee payment",
            timestamp: "Yesterday"
        )
    }
    .padding()
}

#Preview("Info Card") {
    VStack(spacing: DesignTokens.Spacing.md) {
        InfoCard(
            icon: "bolt.fill",
            title: "Alby Wallet",
            subtitle: "Connected",
            iconColor: .yellow
        ) {}

        InfoCard(
            icon: "plus",
            title: "Add Wallet",
            iconColor: DesignTokens.Colors.Accent.primary
        ) {}
    }
    .padding()
}
