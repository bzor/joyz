//
//  DebugLissajousSystem.swift
//  JoyzAVP
//
//  Debug-only system that drives the fairy along a 3D Lissajous curve.
//  Useful for testing secondary motion (wing bounce, body tilt, trails)
//  in the simulator without needing hand tracking or scene reconstruction.
//

import RealityKit
import simd

struct DebugLissajousSystem: System {
    static let query = EntityQuery(where: .has(FairyBehaviorComponent.self) && .has(BounceComponent.self))
    static let dependencies: [SystemDependency] = [.before(WallBounceSystem.self)]

    // Lissajous parameters — tweak these to change the flight path shape
    // Frequencies (a, b, c) with irrational ratios produce non-repeating paths
    private static let freqX: Float = 1.0
    private static let freqY: Float = 1.3
    private static let freqZ: Float = 0.7

    // Phase offsets — shift the axes relative to each other
    private static let phaseX: Float = 0
    private static let phaseY: Float = .pi / 4
    private static let phaseZ: Float = .pi / 2

    // Amplitude of each axis (meters)
    private static let ampX: Float = 0.4
    private static let ampY: Float = 0.2
    private static let ampZ: Float = 0.3

    // Center of the curve in world space
    private static let center = SIMD3<Float>(0, 1.4, -1.2)

    // Overall speed multiplier
    private static let speed: Float = 0.5

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var fairy = entity.components[FairyBehaviorComponent.self],
                  var bounce = entity.components[BounceComponent.self],
                  let toy = entity.components[ToyComponent.self],
                  toy.isActive,
                  fairy.debugLissajous else { continue }

            fairy.totalTime += dt
            let t = fairy.totalTime * Self.speed

            // Current position on the Lissajous curve
            let targetPos = SIMD3<Float>(
                Self.center.x + Self.ampX * sin(Self.freqX * t + Self.phaseX),
                Self.center.y + Self.ampY * sin(Self.freqY * t + Self.phaseY),
                Self.center.z + Self.ampZ * sin(Self.freqZ * t + Self.phaseZ)
            )

            // Velocity = derivative of position (for trail system and secondary motion)
            let vel = SIMD3<Float>(
                Self.ampX * Self.freqX * Self.speed * cos(Self.freqX * t + Self.phaseX),
                Self.ampY * Self.freqY * Self.speed * cos(Self.freqY * t + Self.phaseY),
                Self.ampZ * Self.freqZ * Self.speed * cos(Self.freqZ * t + Self.phaseZ)
            )

            // Set position directly — bypass steering/wall avoidance
            entity.setPosition(targetPos, relativeTo: nil)

            // Store velocity so trail/bounce systems can read it
            bounce.velocity = vel
            entity.components[BounceComponent.self] = bounce

            // Gentle spinning rotation around Y axis (same as normal flight)
            let spinDelta = simd_quatf(angle: fairy.spinRate * dt, axis: SIMD3<Float>(0, 1, 0))
            entity.transform.rotation = entity.transform.rotation * spinDelta

            entity.components[FairyBehaviorComponent.self] = fairy
        }
    }
}
