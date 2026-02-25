//
//  AppModel.swift
//  JoyzAVP
//

import SwiftUI
import RealityKit

@Observable
class AppModel {
    enum BoxState {
        case closed
        case opening
        case open
        case closing
    }

    var selectedToyIndex: Int = 0
    let toys: [ToyDefinition] = ToyDefinition.allToys

    var selectedToy: ToyDefinition { toys[selectedToyIndex] }

    var boxState: BoxState = .closed
    var immersiveSpaceIsShown = false
    var activeToyEntity: Entity?

    // --- Coordinate space conversion (volume → immersive space) ---

    /// Transform of the toybox root from volume RealityKit space → SwiftUI immersive space.
    /// Set by ToyboxView when the box opens.
    var immersiveSpaceFromToybox: simd_float4x4?

    /// Flags to coordinate the two-step conversion handoff
    var needsToyboxConversion = false
    var toyboxConvertedToScene = false

    /// Set once the fairy has been positioned and launched — prevents re-triggering
    var fairyHasLaunched = false

    /// Final toybox center in the immersive space's RealityKit scene coordinates
    var toyboxWorldCenter: SIMD3<Float>? {
        didSet { AppModel.toyboxAvoidanceCenter = toyboxWorldCenter }
    }
    var toyboxWorldHalfExtents: SIMD3<Float> = SIMD3(0.2, 0.3, 0.3)

    /// Static accessors for ECS systems
    @MainActor static var toyboxAvoidanceCenter: SIMD3<Float>?
    @MainActor static var toyboxAvoidanceHalfExtents: SIMD3<Float> = SIMD3(0.2, 0.3, 0.3)
}
