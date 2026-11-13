//
//  ScannerZoomTests.swift
//  AvocadoughTests
//

import Foundation
import Testing
@testable import Avocadough

@Suite("Scanner zoom")
struct ScannerZoomTests {
    /// The horizontal field of view of an iPhone's main camera, give or take a degree.
    private let wideFieldOfView = 69.0
    private let anyZoom = 1.0...100.0

    @Test("A camera that focuses up close needs no zoom")
    func nearFocusingCamera() {
        let factor = ScannerZoom.factor(minimumFocusDistance: 80, fieldOfView: wideFieldOfView, availableFactors: anyZoom)

        #expect(factor == 1)
    }

    @Test("The further away a camera has to stay, the more it zooms")
    func zoomGrowsWithFocusDistance() {
        let at120 = ScannerZoom.factor(minimumFocusDistance: 120, fieldOfView: wideFieldOfView, availableFactors: anyZoom)
        let at150 = ScannerZoom.factor(minimumFocusDistance: 150, fieldOfView: wideFieldOfView, availableFactors: anyZoom)
        let at200 = ScannerZoom.factor(minimumFocusDistance: 200, fieldOfView: wideFieldOfView, availableFactors: anyZoom)

        #expect(at120 > 1)
        #expect(at150 > at120)
        #expect(at200 > at150)
    }

    @Test("At the nearest focusable distance the smallest code spans the wanted share of the picture")
    func smallestCodeFillsTheFrame() {
        let distance = 200
        let factor = ScannerZoom.factor(minimumFocusDistance: distance, fieldOfView: wideFieldOfView, availableFactors: anyZoom)

        let sceneWidth = 2 * Double(distance) * tan(wideFieldOfView / 2 * .pi / 180) / factor
        let fill = ScannerZoom.smallestCodeWidth / sceneWidth

        #expect(abs(fill - ScannerZoom.frameFill) < 0.001)
    }

    @Test("Zoom stops where a code on a monitor would no longer fit")
    func cappedAtTheMaximum() {
        let factor = ScannerZoom.factor(minimumFocusDistance: 600, fieldOfView: wideFieldOfView, availableFactors: anyZoom)

        #expect(factor == ScannerZoom.maximumFactor)
    }

    @Test("Zoom never leaves the range the camera accepts")
    func staysWithinTheCameraRange() {
        let limited = ScannerZoom.factor(minimumFocusDistance: 200, fieldOfView: wideFieldOfView, availableFactors: 1.0...1.5)
        let fixed = ScannerZoom.factor(minimumFocusDistance: 200, fieldOfView: wideFieldOfView, availableFactors: 1.0...1.0)
        let startsHigher = ScannerZoom.factor(minimumFocusDistance: 80, fieldOfView: wideFieldOfView, availableFactors: 2.0...10.0)
        let startsBeyondTheCap = ScannerZoom.factor(minimumFocusDistance: 600, fieldOfView: wideFieldOfView, availableFactors: 3.0...10.0)

        #expect(limited == 1.5)
        #expect(fixed == 1)
        #expect(startsHigher == 2)
        #expect(startsBeyondTheCap == 3)
    }

    @Test("A camera that can't report its optics is left alone", arguments: [-1, 0])
    func unknownFocusDistance(distance: Int) {
        let factor = ScannerZoom.factor(minimumFocusDistance: distance, fieldOfView: wideFieldOfView, availableFactors: anyZoom)

        #expect(factor == 1)
    }

    @Test("A field of view that makes no sense is ignored", arguments: [0.0, -10.0, 180.0, 400.0])
    func nonsenseFieldOfView(fieldOfView: Double) {
        let factor = ScannerZoom.factor(minimumFocusDistance: 200, fieldOfView: fieldOfView, availableFactors: anyZoom)

        #expect(factor == 1)
    }
}
