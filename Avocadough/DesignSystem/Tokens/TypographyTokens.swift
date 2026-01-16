//
//  TypographyTokens.swift
//  Avocadough
//

import SwiftUI

extension DesignTokens {
    /// Typography tokens defining the type scale with Dynamic Type support.
    /// All styles automatically adapt to the user's accessibility settings.
    enum Typography {
        // MARK: - Display Styles (for hero content)

        /// 48pt Bold - Hero balance display
        static let displayLarge = Font.system(size: 48, weight: .bold, design: .rounded)

        /// 40pt Bold - Large feature numbers
        static let displayMedium = Font.system(size: 40, weight: .bold, design: .rounded)

        /// 34pt Bold - Balance display
        static let displaySmall = Font.system(size: 34, weight: .bold, design: .rounded)

        // MARK: - Title Styles

        /// 34pt Bold - Large title (Dynamic Type)
        static let largeTitle = Font.largeTitle.weight(.bold)

        /// 28pt Bold - Sheet titles
        static let title1 = Font.title.weight(.bold)

        /// 22pt Bold - Section headers
        static let title2 = Font.title2.weight(.bold)

        /// 20pt Semibold - Card titles
        static let title3 = Font.title3.weight(.semibold)

        // MARK: - Body Styles

        /// 17pt Semibold - Buttons, labels
        static let headline = Font.headline

        /// 17pt Regular - Body text
        static let body = Font.body

        /// 16pt Regular - Secondary info
        static let callout = Font.callout

        /// 15pt Regular - Metadata
        static let subheadline = Font.subheadline

        // MARK: - Caption Styles

        /// 13pt Regular - Timestamps
        static let footnote = Font.footnote

        /// 12pt Regular - Badges, small labels
        static let caption = Font.caption

        /// 11pt Regular - Tiny labels
        static let caption2 = Font.caption2

        // MARK: - Numeric Styles (Monospace for alignment)

        /// Monospaced digits for amounts - Large
        static let amountLarge = Font.system(size: 48, weight: .bold, design: .rounded).monospacedDigit()

        /// Monospaced digits for amounts - Medium
        static let amountMedium = Font.system(size: 34, weight: .bold, design: .rounded).monospacedDigit()

        /// Monospaced digits for amounts - Small
        static let amountSmall = Font.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit()

        /// Monospaced digits for transaction rows
        static let amountRow = Font.body.monospacedDigit().weight(.medium)

        /// Monospaced for codes, addresses, invoices
        static let monospace = Font.system(.body, design: .monospaced)

        /// Small monospace for hashes, technical data
        static let monospaceSmall = Font.system(.caption, design: .monospaced)
    }
}

// MARK: - View Extension for Typography

extension View {
    /// Apply a design system typography style
    func typography(_ style: Font) -> some View {
        self.font(style)
    }

    /// Large balance display style
    func balanceStyle() -> some View {
        self
            .font(DesignTokens.Typography.amountLarge)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }

    /// Secondary amount style (fiat conversion)
    func secondaryAmountStyle() -> some View {
        self
            .font(DesignTokens.Typography.title3)
            .foregroundStyle(Color.ds.textSecondary)
    }

    /// Transaction row amount style
    func transactionAmountStyle() -> some View {
        self
            .font(DesignTokens.Typography.amountRow)
    }
}

// MARK: - Text Style Modifiers

extension Text {
    /// Apply primary text styling
    func primaryStyle() -> Text {
        self
            .font(DesignTokens.Typography.body)
            .foregroundColor(Color.ds.textPrimary)
    }

    /// Apply secondary text styling
    func secondaryStyle() -> Text {
        self
            .font(DesignTokens.Typography.subheadline)
            .foregroundColor(Color.ds.textSecondary)
    }

    /// Apply caption text styling
    func captionStyle() -> Text {
        self
            .font(DesignTokens.Typography.caption)
            .foregroundColor(Color.ds.textTertiary)
    }
}
