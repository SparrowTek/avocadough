//
//  DesignTokens.swift
//  Avocadough
//

import SwiftUI

/// Design Tokens namespace for the Avocadough design system.
/// These tokens provide a consistent foundation for colors, typography, spacing, and more.
enum DesignTokens {
    // MARK: - Spacing (4pt grid system)

    enum Spacing {
        /// 4pt - Tight spacing within components
        static let xs: CGFloat = 4
        /// 8pt - Related elements
        static let sm: CGFloat = 8
        /// 16pt - Section spacing
        static let md: CGFloat = 16
        /// 24pt - Major sections
        static let lg: CGFloat = 24
        /// 32pt - Screen margins (compact)
        static let xl: CGFloat = 32
        /// 48pt - Screen margins (regular)
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum Radius {
        /// 8pt - Small buttons, tags
        static let sm: CGFloat = 8
        /// 12pt - Cards, inputs
        static let md: CGFloat = 12
        /// 16pt - Sheets, large cards
        static let lg: CGFloat = 16
        /// 24pt - Feature cards
        static let xl: CGFloat = 24
        /// Pills, circular elements
        static let full: CGFloat = 9999
    }

    // MARK: - Shadows / Elevation

    enum Shadow {
        struct Properties {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        /// No elevation
        static let none = Properties(color: .clear, radius: 0, x: 0, y: 0)

        /// Subtle elevation for cards
        static let sm = Properties(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )

        /// Medium elevation for floating elements
        static let md = Properties(
            color: Color.black.opacity(0.12),
            radius: 16,
            x: 0,
            y: 4
        )

        /// High elevation for modals
        static let lg = Properties(
            color: Color.black.opacity(0.16),
            radius: 24,
            x: 0,
            y: 8
        )
    }

    // MARK: - Timing / Animation

    enum Animation {
        /// Snappy spring for button taps, toggles (0.3s)
        static let snappy: SwiftUI.Animation = .spring(response: 0.3, dampingFraction: 0.7)

        /// Smooth easeInOut for view transitions (0.35s)
        static let smooth: SwiftUI.Animation = .easeInOut(duration: 0.35)

        /// Bouncy spring for success animations (0.5s)
        static let bouncy: SwiftUI.Animation = .spring(response: 0.5, dampingFraction: 0.5)

        /// Gentle easeOut for entry animations (0.6s)
        static let gentle: SwiftUI.Animation = .easeOut(duration: 0.6)

        /// Quick animation for micro-interactions (0.15s)
        static let quick: SwiftUI.Animation = .easeOut(duration: 0.15)

        /// Duration constants
        enum Duration {
            static let quick: Double = 0.15
            static let snappy: Double = 0.3
            static let smooth: Double = 0.35
            static let bouncy: Double = 0.5
            static let gentle: Double = 0.6
        }
    }

    // MARK: - Icon Sizes

    enum IconSize {
        /// 16pt - Small inline icons
        static let sm: CGFloat = 16
        /// 20pt - Standard icons
        static let md: CGFloat = 20
        /// 24pt - Prominent icons
        static let lg: CGFloat = 24
        /// 32pt - Feature icons
        static let xl: CGFloat = 32
        /// 48pt - Hero icons
        static let xxl: CGFloat = 48
    }

    // MARK: - Component Sizes

    enum ComponentSize {
        /// Button heights
        enum Button {
            static let sm: CGFloat = 36
            static let md: CGFloat = 44
            static let lg: CGFloat = 52
        }

        /// Text field heights
        enum TextField {
            static let sm: CGFloat = 36
            static let md: CGFloat = 44
            static let lg: CGFloat = 52
        }

        /// QR Code sizes
        enum QRCode {
            static let sm: CGFloat = 150
            static let md: CGFloat = 200
            static let lg: CGFloat = 250
        }
    }
}
