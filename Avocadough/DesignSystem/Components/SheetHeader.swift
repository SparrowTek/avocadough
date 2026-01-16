//
//  SheetHeader.swift
//  Avocadough
//

import SwiftUI

// MARK: - SheetHeader

/// A consistent header component for modal sheets
struct SheetHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let leadingAction: SheetHeaderAction?
    let trailingAction: SheetHeaderAction?

    @State private var leadingTapTrigger = false
    @State private var trailingTapTrigger = false

    struct SheetHeaderAction {
        let icon: String?
        let label: LocalizedStringKey?
        let action: () -> Void

        init(icon: String, action: @escaping () -> Void) {
            self.icon = icon
            self.label = nil
            self.action = action
        }

        init(label: LocalizedStringKey, action: @escaping () -> Void) {
            self.icon = nil
            self.label = label
            self.action = action
        }

        static func close(action: @escaping () -> Void) -> SheetHeaderAction {
            SheetHeaderAction(icon: "xmark", action: action)
        }

        static func back(action: @escaping () -> Void) -> SheetHeaderAction {
            SheetHeaderAction(icon: "chevron.left", action: action)
        }

        static func done(action: @escaping () -> Void) -> SheetHeaderAction {
            SheetHeaderAction(label: "Done", action: action)
        }

        static func cancel(action: @escaping () -> Void) -> SheetHeaderAction {
            SheetHeaderAction(label: "Cancel", action: action)
        }
    }

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        leadingAction: SheetHeaderAction? = nil,
        trailingAction: SheetHeaderAction? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingAction = leadingAction
        self.trailingAction = trailingAction
    }

    var body: some View {
        HStack(alignment: .center) {
            // Leading action
            if let action = leadingAction {
                headerButton(action, trigger: $leadingTapTrigger)
                    .sensoryFeedback(AppHaptics.buttonTap, trigger: leadingTapTrigger)
            } else {
                Spacer()
                    .frame(width: 44)
            }

            Spacer()

            // Title
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(Color.ds.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                }
            }

            Spacer()

            // Trailing action
            if let action = trailingAction {
                headerButton(action, trigger: $trailingTapTrigger)
                    .sensoryFeedback(AppHaptics.buttonTap, trigger: trailingTapTrigger)
            } else {
                Spacer()
                    .frame(width: 44)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.primary)
    }

    @ViewBuilder
    private func headerButton(_ action: SheetHeaderAction, trigger: Binding<Bool>) -> some View {
        Button(action: {
            trigger.wrappedValue.toggle()
            action.action()
        }) {
            if let icon = action.icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ds.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            } else if let label = action.label {
                Text(label)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.Accent.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Navigation Header (for NavigationStack)

/// A toolbar configuration for consistent navigation headers
struct NavigationHeader: ViewModifier {
    let title: LocalizedStringKey
    let showBackButton: Bool
    let trailingAction: SheetHeader.SheetHeaderAction?

    @Environment(\.dismiss) private var dismiss
    @State private var tapTrigger = false

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let action = trailingAction {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            tapTrigger.toggle()
                            action.action()
                        }) {
                            if let icon = action.icon {
                                Image(systemName: icon)
                            } else if let label = action.label {
                                Text(label)
                            }
                        }
                        .sensoryFeedback(AppHaptics.buttonTap, trigger: tapTrigger)
                    }
                }
            }
    }
}

extension View {
    func navigationHeader(
        _ title: LocalizedStringKey,
        showBackButton: Bool = true,
        trailingAction: SheetHeader.SheetHeaderAction? = nil
    ) -> some View {
        modifier(NavigationHeader(
            title: title,
            showBackButton: showBackButton,
            trailingAction: trailingAction
        ))
    }
}

// MARK: - Empty State View

/// A view for displaying empty states with icon and action
struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey?
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    init(
        icon: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.ds.textTertiary)

            // Text
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(DesignTokens.Typography.title3)
                    .foregroundStyle(Color.ds.textPrimary)
                    .multilineTextAlignment(.center)

                if let message {
                    Text(message)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(Color.ds.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Action button
            if let actionTitle, let action {
                AvocadoButton(actionTitle, variant: .secondary, size: .medium, isFullWidth: false, action: action)
            }
        }
        .padding(DesignTokens.Spacing.xl)
    }
}

// MARK: - Status Badge

/// A small badge for displaying status information
struct StatusBadge: View {
    let status: Status
    let label: LocalizedStringKey?

    enum Status {
        case connected
        case disconnected
        case syncing
        case pending
        case error

        var color: Color {
            switch self {
            case .connected: DesignTokens.Colors.Semantic.connected
            case .disconnected: DesignTokens.Colors.Semantic.disconnected
            case .syncing: DesignTokens.Colors.Semantic.pending
            case .pending: DesignTokens.Colors.Semantic.pending
            case .error: DesignTokens.Colors.Semantic.error
            }
        }

        var icon: String {
            switch self {
            case .connected: "checkmark.circle.fill"
            case .disconnected: "xmark.circle.fill"
            case .syncing: "arrow.triangle.2.circlepath"
            case .pending: "clock.fill"
            case .error: "exclamationmark.circle.fill"
            }
        }

        var defaultLabel: LocalizedStringKey {
            switch self {
            case .connected: "Connected"
            case .disconnected: "Disconnected"
            case .syncing: "Syncing"
            case .pending: "Pending"
            case .error: "Error"
            }
        }
    }

    init(_ status: Status, label: LocalizedStringKey? = nil) {
        self.status = status
        self.label = label
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: status.icon)
                .font(.system(size: 10))

            Text(label ?? status.defaultLabel)
                .font(DesignTokens.Typography.caption)
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(status.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Toast View

/// A non-blocking notification toast
struct ToastView: View {
    let message: LocalizedStringKey
    let type: ToastType
    let onDismiss: (() -> Void)?

    @State private var dismissTrigger = false

    enum ToastType {
        case success
        case error
        case info
        case warning

        var icon: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .error: "xmark.circle.fill"
            case .info: "info.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: DesignTokens.Colors.Semantic.connected
            case .error: DesignTokens.Colors.Semantic.error
            case .info: DesignTokens.Colors.Accent.info
            case .warning: DesignTokens.Colors.Semantic.pending
            }
        }
    }

    init(
        _ message: LocalizedStringKey,
        type: ToastType = .info,
        onDismiss: (() -> Void)? = nil
    ) {
        self.message = message
        self.type = type
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)

            Text(message)
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(Color.ds.textPrimary)

            Spacer()

            if onDismiss != nil {
                Button(action: {
                    dismissTrigger.toggle()
                    onDismiss?()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.ds.textTertiary)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(AppHaptics.buttonTap, trigger: dismissTrigger)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.Background.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .shadow(
            color: DesignTokens.Shadow.md.color,
            radius: DesignTokens.Shadow.md.radius,
            x: DesignTokens.Shadow.md.x,
            y: DesignTokens.Shadow.md.y
        )
    }
}

// MARK: - Previews

#Preview("Sheet Headers") {
    VStack(spacing: 0) {
        SheetHeader(
            "Send Bitcoin",
            leadingAction: .close {},
            trailingAction: nil
        )

        Divider()

        SheetHeader(
            "Transaction Details",
            subtitle: "December 14, 2024",
            leadingAction: .back {},
            trailingAction: .done {}
        )
    }
}

#Preview("Status Badges") {
    HStack(spacing: DesignTokens.Spacing.md) {
        StatusBadge(.connected)
        StatusBadge(.disconnected)
        StatusBadge(.syncing)
        StatusBadge(.pending)
        StatusBadge(.error)
    }
    .padding()
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "bolt.slash.fill",
        title: "No Transactions",
        message: "Your transactions will appear here once you send or receive Bitcoin.",
        actionTitle: "Receive Bitcoin"
    ) {}
}

#Preview("Toast") {
    VStack(spacing: DesignTokens.Spacing.md) {
        ToastView("Payment sent successfully!", type: .success) {}
        ToastView("Failed to connect", type: .error) {}
        ToastView("Syncing transactions...", type: .info) {}
        ToastView("Low balance warning", type: .warning) {}
    }
    .padding()
}
