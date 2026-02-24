//
//  TrailEmitterComponent.swift
//  JoyzAVP
//

import RealityKit

struct TrailEmitterComponent: Component {
    var emissionRate: Float = 5.0
    var timeSinceLastEmission: Float = 0
    var surfaceProximityThreshold: Float = 0.3
    var decorationTypes: [String] = ["flower", "star", "heart"]
}
