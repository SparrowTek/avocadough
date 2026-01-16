//
//  AvocadoTextField.swift
//  Avocadough
//

import SwiftUI

// MARK: - TextField State

enum AvocadoTextFieldState {
    case normal
    case focused
    case error
    case success
    case disabled

    var borderColor: Color {
        switch self {
        case .normal: DesignTokens.Colors.Component.border
        case .focused: DesignTokens.Colors.Accent.primary
        case .error: DesignTokens.Colors.Semantic.error
        case .success: DesignTokens.Colors.Semantic.connected
        case .disabled: DesignTokens.Colors.Component.border.opacity(0.5)
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .focused, .error, .success: 2
        default: 1
        }
    }
}

// MARK: - AvocadoTextField

/// A styled text field component with icon support and validation states
struct AvocadoTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String?
    let trailingIcon: String?
    let errorMessage: String?
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let autocapitalization: TextInputAutocapitalization
    let onSubmit: (() -> Void)?
    let onTrailingIconTap: (() -> Void)?

    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var clearTrigger = false
    @State private var trailingTrigger = false

    init(
        text: Binding<String>,
        placeholder: String,
        icon: String? = nil,
        trailingIcon: String? = nil,
        errorMessage: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        onSubmit: (() -> Void)? = nil,
        onTrailingIconTap: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.trailingIcon = trailingIcon
        self.errorMessage = errorMessage
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
        self.onSubmit = onSubmit
        self.onTrailingIconTap = onTrailingIconTap
    }

    private var fieldState: AvocadoTextFieldState {
        if !isEnabled {
            return .disabled
        }
        if errorMessage != nil {
            return .error
        }
        if isFocused {
            return .focused
        }
        return .normal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Leading icon
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                        .frame(width: 20)
                }

                // Text field
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(DesignTokens.Typography.body)
                .foregroundStyle(Color.ds.textPrimary)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

                // Trailing icon/button
                if let trailingIcon {
                    Button(action: {
                        trailingTrigger.toggle()
                        onTrailingIconTap?()
                    }) {
                        Image(systemName: trailingIcon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DesignTokens.Colors.Accent.primary)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(AppHaptics.buttonTap, trigger: trailingTrigger)
                }

                // Clear button
                if !text.isEmpty && isFocused && trailingIcon == nil {
                    Button(action: clearText) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.ds.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(AppHaptics.buttonTap, trigger: clearTrigger)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(height: DesignTokens.ComponentSize.TextField.lg)
            .background(DesignTokens.Colors.Background.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .strokeBorder(fieldState.borderColor, lineWidth: fieldState.borderWidth)
            )
            .animation(DesignTokens.Animation.snappy, value: fieldState)

            // Error message
            if let errorMessage {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))

                    Text(errorMessage)
                        .font(DesignTokens.Typography.caption)
                }
                .foregroundStyle(DesignTokens.Colors.Semantic.error)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(DesignTokens.Animation.snappy, value: errorMessage)
    }

    private var iconColor: Color {
        if fieldState == .error {
            return DesignTokens.Colors.Semantic.error
        }
        if isFocused {
            return DesignTokens.Colors.Accent.primary
        }
        return Color.ds.textSecondary
    }

    private func clearText() {
        clearTrigger.toggle()
        text = ""
    }
}

// MARK: - Search Field

/// A specialized text field for search functionality
struct AvocadoSearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: (() -> Void)?

    init(
        text: Binding<String>,
        placeholder: String = "Search",
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    var body: some View {
        AvocadoTextField(
            text: $text,
            placeholder: placeholder,
            icon: "magnifyingglass",
            keyboardType: .default,
            autocapitalization: .never,
            onSubmit: onSubmit
        )
    }
}

// MARK: - Invoice/Address Field

/// A specialized text field for Lightning addresses and invoices
struct InvoiceTextField: View {
    @Binding var text: String
    let placeholder: String
    let onPaste: (() -> Void)?
    let onScan: (() -> Void)?

    @State private var pasteTrigger = false

    init(
        text: Binding<String>,
        placeholder: String = "Enter address or invoice",
        onPaste: (() -> Void)? = nil,
        onScan: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onPaste = onPaste
        self.onScan = onScan
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            AvocadoTextField(
                text: $text,
                placeholder: placeholder,
                icon: "bolt.fill",
                keyboardType: .default,
                autocapitalization: .never
            )

            HStack(spacing: DesignTokens.Spacing.sm) {
                Button(action: pasteFromClipboard) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.avocado(variant: .secondary, size: .small, isFullWidth: false))

                if onScan != nil {
                    Button(action: { onScan?() }) {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(.avocado(variant: .secondary, size: .small, isFullWidth: false))
                }
            }
        }
        .sensoryFeedback(AppHaptics.copy, trigger: pasteTrigger)
    }

    private func pasteFromClipboard() {
        if let clipboardText = UIPasteboard.general.string {
            text = clipboardText
            pasteTrigger.toggle()
            onPaste?()
        }
    }
}

// MARK: - Amount Input Field

/// A numeric input field optimized for amount entry
struct AmountTextField: View {
    @Binding var amount: UInt64
    let maxAmount: UInt64?
    let btcPrice: Double?

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    init(
        amount: Binding<UInt64>,
        maxAmount: UInt64? = nil,
        btcPrice: Double? = nil
    ) {
        self._amount = amount
        self.maxAmount = maxAmount
        self.btcPrice = btcPrice
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Large amount display
            AmountInputDisplay(amount: amount, btcPrice: btcPrice)

            // Hidden text field for keyboard input
            TextField("", text: $textValue)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .opacity(0)
                .frame(height: 0)
                .onChange(of: textValue) { _, newValue in
                    updateAmount(from: newValue)
                }

            // Tap to focus
            Color.clear
                .frame(height: 1)
                .contentShape(Rectangle())
                .onTapGesture {
                    isFocused = true
                }
        }
        .sensoryFeedback(.selection, trigger: amount)
        .onAppear {
            if amount > 0 {
                textValue = "\(amount)"
            }
        }
    }

    private func updateAmount(from text: String) {
        let filtered = text.filter { $0.isNumber }
        if let value = UInt64(filtered) {
            if let max = maxAmount, value > max {
                amount = max
                textValue = "\(max)"
            } else {
                amount = value
            }
        } else if filtered.isEmpty {
            amount = 0
        }
    }
}

// MARK: - Previews

#Preview("Text Field States") {
    VStack(spacing: DesignTokens.Spacing.md) {
        AvocadoTextField(
            text: .constant(""),
            placeholder: "Enter text",
            icon: "envelope"
        )

        AvocadoTextField(
            text: .constant("hello@example.com"),
            placeholder: "Enter text",
            icon: "envelope"
        )

        AvocadoTextField(
            text: .constant("invalid"),
            placeholder: "Enter text",
            icon: "envelope",
            errorMessage: "Please enter a valid email"
        )

        AvocadoTextField(
            text: .constant(""),
            placeholder: "Search",
            icon: "magnifyingglass"
        )
    }
    .padding()
}

#Preview("Invoice Field") {
    InvoiceTextField(
        text: .constant(""),
        onPaste: {},
        onScan: {}
    )
    .padding()
}

#Preview("Search Field") {
    AvocadoSearchField(text: .constant(""))
        .padding()
}
