//
//  FairyBehaviorComponent.swift
//  JoyzAVP
//

import RealityKit
import simd

struct FairyBehaviorComponent: Component {
    var flightTarget: SIMD3<Float> = .zero
    var flightSpeed: Float = 0.35          // slower, more gentle cruising speed
    var timeUntilNewTarget: Float = 0
    var targetChangePeriod: Float = 4.0    // longer between target changes
    var spinRate: Float = 1.2              // gentler spin
    var isBeingHeld: Bool = false
    var liftSpeed: Float = 0.2
    var totalTime: Float = 0
}
