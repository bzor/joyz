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
    /// Closest hand joint distance (0 = touching, large = far away)
    var handDistance: Float = 10.0
    /// Proximity influence range (meters)
    var handInfluenceRange: Float = 0.5
    var totalTime: Float = 0

    /// Accumulated wing flap phase (incremented by WingFlapSystem each frame)
    var wingFlapPhase: Float = 0

    /// Hair spring state — angles and angular velocities on X and Z axes
    var hairAngleX: Float = 0
    var hairAngleZ: Float = 0
    var hairVelocityX: Float = 0
    var hairVelocityZ: Float = 0
    /// Previous frame velocity for computing acceleration
    var prevVelocity: SIMD3<Float> = .zero

    /// Dress spring state — X axis sway driven by Y velocity
    var dressAngleX: Float = 0
    var dressVelocityX: Float = 0

    /// Arms spring state — Z axis sway driven by Y velocity
    var armsAngleZ: Float = 0
    var armsVelocityZ: Float = 0

    /// Legs spring state — tilts opposite to velocity in local space
    var legsAngleX: Float = 0
    var legsAngleZ: Float = 0
    var legsVelocityX: Float = 0
    var legsVelocityZ: Float = 0

    /// Accumulated foot flutter phase
    var footFlutterPhase: Float = 0

    /// When true, DebugLissajousSystem drives the fairy on a parametric curve
    /// and FairyMovementSystem/WallBounceSystem are bypassed.
    var debugLissajous: Bool = false
}
