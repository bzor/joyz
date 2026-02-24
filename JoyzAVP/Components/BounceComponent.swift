//
//  BounceComponent.swift
//  JoyzAVP
//

import RealityKit
import simd

struct BounceComponent: Component {
    var velocity: SIMD3<Float> = SIMD3<Float>(0.1, 0.05, -0.08)  // gentler initial velocity
    var bounciness: Float = 0.5
    var maxSpeed: Float = 0.5
}
