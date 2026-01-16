//
//  Haptics.swift
//  Avocadough
//

import SwiftUI

// MARK: - Semantic Haptic Feedback

/// Semantic haptic feedback types for Avocadough.
/// Use these with the `.sensoryFeedback()` modifier for SwiftUI-native haptics.
///
/// Usage:
/// ```swift
/// .sensoryFeedback(.success, trigger: paymentSent)
/// .sensoryFeedback(AppHaptics.buttonTap, trigger: isPressed)
/// ```
enum AppHaptics {
    /// Button tap feedback
    static let buttonTap: SensoryFeedback = .impact(weight: .light)

    /// Copy to clipboard feedback
    static let copy: SensoryFeedback = .impact(weight: .medium)

    /// Selection change (picker, amount adjustment)
    static let selection: SensoryFeedback = .selection

    /// Amount value changed
    static let amountChanged: SensoryFeedback = .selection

    /// Payment sent successfully
    static let paymentSent: SensoryFeedback = .success

    /// Payment received
    static let paymentReceived: SensoryFeedback = .success

    /// Slide-to-send completed
    static let slideComplete: SensoryFeedback = .success

    /// Operation failed
    static let failed: SensoryFeedback = .error

    /// Warning (approaching limit, etc.)
    static let warning: SensoryFeedback = .warning

    /// Pull to refresh
    static let refresh: SensoryFeedback = .impact(weight: .light, intensity: 0.5)

    /// Heavy impact for major state changes
    static let heavyImpact: SensoryFeedback = .impact(weight: .heavy)

    /// Soft impact for subtle feedback
    static let softImpact: SensoryFeedback = .impact(flexibility: .soft)
}

// MARK: - View Extensions for Common Haptic Patterns

extension View {
    /// Add haptic feedback when a value changes
    /// - Parameters:
    ///   - feedback: The type of sensory feedback to play
    ///   - trigger: The value to observe for changes
    func hapticFeedback<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        self.sensoryFeedback(feedback, trigger: trigger)
    }

    /// Add success haptic feedback when a condition becomes true
    func hapticOnSuccess<T: Equatable>(trigger: T) -> some View {
        self.sensoryFeedback(.success, trigger: trigger)
    }

    /// Add error haptic feedback when a condition becomes true
    func hapticOnError<T: Equatable>(trigger: T) -> some View {
        self.sensoryFeedback(.error, trigger: trigger)
    }

    /// Add selection haptic feedback when a value changes
    func hapticOnSelection<T: Equatable>(trigger: T) -> some View {
        self.sensoryFeedback(.selection, trigger: trigger)
    }

    /// Add impact haptic feedback when a value changes
    func hapticOnImpact<T: Equatable>(trigger: T) -> some View {
        self.sensoryFeedback(.impact, trigger: trigger)
    }

    /// Add conditional haptic feedback
    /// - Parameters:
    ///   - feedback: The type of sensory feedback to play
    ///   - trigger: The value to observe for changes
    ///   - condition: A closure that determines if feedback should play
    func hapticFeedback<T: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: T,
        condition: @escaping (T, T) -> Bool
    ) -> some View {
        self.sensoryFeedback(feedback, trigger: trigger, condition: { oldValue, newValue in
            condition(oldValue, newValue)
        })
    }
}

// MARK: - Button with Built-in Haptics

/// A button style that provides haptic feedback on press
struct HapticButtonStyle: ButtonStyle {
    let feedback: SensoryFeedback

    init(_ feedback: SensoryFeedback = .impact(weight: .light)) {
        self.feedback = feedback
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sensoryFeedback(feedback, trigger: configuration.isPressed) { oldValue, newValue in
                // Only trigger on press down, not release
                !oldValue && newValue
            }
    }
}

extension ButtonStyle where Self == HapticButtonStyle {
    /// Button style with light impact haptic on press
    static var haptic: HapticButtonStyle { HapticButtonStyle() }

    /// Button style with custom haptic feedback
    static func haptic(_ feedback: SensoryFeedback) -> HapticButtonStyle {
        HapticButtonStyle(feedback)
    }
}

// MARK: - Haptic Trigger Helper

/// A simple trigger value for haptic feedback that can be toggled
struct HapticTrigger: Equatable {
    private var value = false

    mutating func fire() {
        value.toggle()
    }
}

extension View {
    /// Add haptic feedback with a manual trigger
    /// - Parameters:
    ///   - feedback: The type of sensory feedback to play
    ///   - trigger: A HapticTrigger binding that fires the feedback when toggled
    func hapticFeedback(_ feedback: SensoryFeedback, trigger: HapticTrigger) -> some View {
        self.sensoryFeedback(feedback, trigger: trigger)
    }
}

// MARK: - Usage Examples
/*

 BASIC USAGE:

 // Trigger haptic when a boolean changes
 @State private var isPressed = false

 Button("Tap me") { }
     .sensoryFeedback(.impact, trigger: isPressed)

 // Trigger haptic on success
 @State private var paymentComplete = false

 PaymentView()
     .sensoryFeedback(.success, trigger: paymentComplete)

 // Trigger haptic on selection change
 @State private var selectedIndex = 0

 Picker("Options", selection: $selectedIndex) { ... }
     .sensoryFeedback(.selection, trigger: selectedIndex)


 USING APP-SPECIFIC HAPTICS:

 // Use semantic haptic constants
 .sensoryFeedback(AppHaptics.paymentSent, trigger: paymentComplete)
 .sensoryFeedback(AppHaptics.amountChanged, trigger: amount)


 CONDITIONAL HAPTICS:

 // Only trigger when value increases
 @State private var amount: UInt64 = 0

 AmountView()
     .sensoryFeedback(.increase, trigger: amount) { old, new in
         new > old
     }


 MANUAL TRIGGER:

 @State private var hapticTrigger = HapticTrigger()

 Button("Copy") {
     copyToClipboard()
     hapticTrigger.fire()  // Manually trigger haptic
 }
 .sensoryFeedback(AppHaptics.copy, trigger: hapticTrigger)

*/
