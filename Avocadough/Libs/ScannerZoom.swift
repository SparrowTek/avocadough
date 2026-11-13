//
//  ScannerZoom.swift
//  Avocadough
//

import Foundation

/// How far to zoom the scanner's camera so a small code can be read without holding the
/// phone closer than its lens can focus.
///
/// Recent iPhone cameras cannot focus on anything nearer than 15 to 20 cm. From that far
/// away a code the size a card terminal draws covers only a sliver of the picture, so
/// people move in until it fills the screen, and the camera then shows a blur that never
/// decodes. Zooming lets the code fill the frame from a distance that stays in focus.
/// This is the remedy Apple describes in "What's new in camera capture" (WWDC21).
enum ScannerZoom {
    /// The width in millimetres of the smallest code the scanner should read with ease:
    /// about what a card terminal or a receipt gives a Lightning invoice.
    static let smallestCodeWidth = 30.0

    /// The share of the picture's width such a code should span when held at the nearest
    /// distance the camera can focus at. The preview shows only the middle of the
    /// picture, so on screen this is roughly twice as large.
    static let frameFill = 0.2

    /// More zoom than this and a code on a monitor no longer fits from arm's length.
    static let maximumFactor = 2.0

    /// The zoom factor for a camera with these optics, or 1 when it needs none.
    ///
    /// - Parameters:
    ///   - minimumFocusDistance: The nearest distance the camera focuses at, in
    ///     millimetres. Cameras that can't say report a negative number.
    ///   - fieldOfView: The horizontal field of view of the picture, in degrees.
    ///   - availableFactors: The zoom factors the camera accepts. Anything outside this
    ///     range is a programmer error to set, so the result never leaves it.
    static func factor(
        minimumFocusDistance: Int,
        fieldOfView: Double,
        availableFactors: ClosedRange<Double>
    ) -> Double {
        let unzoomed = max(1, availableFactors.lowerBound)
        guard minimumFocusDistance > 0, fieldOfView > 0, fieldOfView < 180 else { return unzoomed }

        // The width of the scene the picture takes in at the nearest focusable distance.
        let halfAngle = fieldOfView / 2 * .pi / 180
        let sceneWidth = 2 * Double(minimumFocusDistance) * tan(halfAngle)

        let wanted = frameFill * sceneWidth / smallestCodeWidth
        let ceiling = max(unzoomed, min(maximumFactor, availableFactors.upperBound))
        return min(max(wanted, unzoomed), ceiling)
    }
}
