//
//  ColorTokens.swift
//  Avocadough
//

import SwiftUI

extension DesignTokens {
    /// Semantic color tokens for consistent theming across the app.
    /// These colors adapt automatically to light and dark modes.
    enum Colors {
        // MARK: - Background Colors

        enum Background {
            /// Main app background - Light: #FAFAFA, Dark: #0A0A0A
            static let primary = Color("backgroundPrimary", bundle: .main)

            /// Cards, sheets background - Light: #F2F2F7, Dark: #1C1C1E
            static let secondary = Color("backgroundSecondary", bundle: .main)

            /// Elevated surfaces - Light: #FFFFFF, Dark: #2C2C2E
            static let tertiary = Color("backgroundTertiary", bundle: .main)

            /// Grouped content background
            static let grouped = Color(uiColor: .systemGroupedBackground)

            /// Secondary grouped content background
            static let groupedSecondary = Color(uiColor: .secondarySystemGroupedBackground)
        }

        // MARK: - Accent Colors

        enum Accent {
            /// Bitcoin orange - Primary brand color
            /// Light: #FF9500, Dark: #FFB340
            static let primary = Color("accentPrimary", bundle: .main)

            /// Success states, incoming transactions
            /// Light: #30D158, Dark: #32D74B
            static let success = Color("accentSuccess", bundle: .main)

            /// Warnings, outgoing transactions
            /// Light: #FF3B30, Dark: #FF453A
            static let warning = Color("accentWarning", bundle: .main)

            /// Informational elements
            /// Light: #007AFF, Dark: #0A84FF
            static let info = Color(uiColor: .systemBlue)

            /// Lightning bolt yellow
            static let lightning = Color.yellow
        }

        // MARK: - Text Colors

        enum Text {
            /// Primary text - Headlines, amounts
            static let primary = Color(uiColor: .label)

            /// Secondary text - Descriptions
            static let secondary = Color(uiColor: .secondaryLabel)

            /// Tertiary text - Placeholders, timestamps
            static let tertiary = Color(uiColor: .tertiaryLabel)

            /// Quaternary text - Disabled state
            static let quaternary = Color(uiColor: .quaternaryLabel)

            /// Inverted text for dark backgrounds
            static let inverted = Color(uiColor: .systemBackground)
        }

        // MARK: - Semantic Colors

        enum Semantic {
            /// Incoming transaction color
            static let incoming = Accent.success

            /// Outgoing transaction color
            static let outgoing = Accent.warning

            /// Error state color
            static let error = Color(uiColor: .systemRed)

            /// Connected/online status
            static let connected = Accent.success

            /// Disconnected/offline status
            static let disconnected = Color(uiColor: .systemGray)

            /// Syncing/pending status
            static let pending = Color(uiColor: .systemOrange)
        }

        // MARK: - Component Colors

        enum Component {
            /// Separator lines
            static let separator = Color(uiColor: .separator)

            /// Opaque separator
            static let separatorOpaque = Color(uiColor: .opaqueSeparator)

            /// Border color for inputs, cards
            static let border = Color(uiColor: .separator)

            /// Fill color for UI elements
            static let fill = Color(uiColor: .systemFill)

            /// Secondary fill
            static let fillSecondary = Color(uiColor: .secondarySystemFill)

            /// Tertiary fill
            static let fillTertiary = Color(uiColor: .tertiarySystemFill)
        }
    }
}

// MARK: - Color Convenience Extensions

extension Color {
    /// Quick access to design system background colors
    enum ds {
        static var backgroundPrimary: Color { DesignTokens.Colors.Background.primary }
        static var backgroundSecondary: Color { DesignTokens.Colors.Background.secondary }
        static var backgroundTertiary: Color { DesignTokens.Colors.Background.tertiary }

        static var accentPrimary: Color { DesignTokens.Colors.Accent.primary }
        static var accentSuccess: Color { DesignTokens.Colors.Accent.success }
        static var accentWarning: Color { DesignTokens.Colors.Accent.warning }

        static var textPrimary: Color { DesignTokens.Colors.Text.primary }
        static var textSecondary: Color { DesignTokens.Colors.Text.secondary }
        static var textTertiary: Color { DesignTokens.Colors.Text.tertiary }

        static var incoming: Color { DesignTokens.Colors.Semantic.incoming }
        static var outgoing: Color { DesignTokens.Colors.Semantic.outgoing }
    }
}
