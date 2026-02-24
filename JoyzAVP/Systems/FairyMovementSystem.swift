//
//  FairyMovementSystem.swift
//  JoyzAVP
//

import RealityKit
import simd

struct FairyMovementSystem: System {
    static let query = EntityQuery(where: .has(FairyBehaviorComponent.self) && .has(BounceComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var fairy = entity.components[FairyBehaviorComponent.self],
                  var bounce = entity.components[BounceComponent.self],
                  let toy = entity.components[ToyComponent.self],
                  toy.isActive else { continue }

            fairy.totalTime += dt

            // Gentle spinning rotation around Y axis
            let currentSpinRate = fairy.isBeingHeld ? fairy.spinRate * 2.0 : fairy.spinRate
            let spinDelta = simd_quatf(angle: currentSpinRate * dt, axis: SIMD3<Float>(0, 1, 0))
            entity.transform.rotation = entity.transform.rotation * spinDelta

            if fairy.isBeingHeld {
                // When held: float upward, damp horizontal movement smoothly
                bounce.velocity.x *= (1.0 - 2.0 * dt)
                bounce.velocity.z *= (1.0 - 2.0 * dt)
                // Smoothly approach lift speed
                bounce.velocity.y += (fairy.liftSpeed - bounce.velocity.y) * 3.0 * dt
            } else {
                // Autonomous flight: steer toward target with smooth damping
                fairy.timeUntilNewTarget -= dt
                if fairy.timeUntilNewTarget <= 0 {
                    fairy.flightTarget = Self.randomRoomPoint()
                    fairy.timeUntilNewTarget = fairy.targetChangePeriod
                }

                let currentPos = entity.position(relativeTo: nil)
                let toTarget = fairy.flightTarget - currentPos
                let distance = simd_length(toTarget)

                if distance > 0.05 {
                    let targetDirection = toTarget / distance
                    // Smooth steering: blend current velocity direction toward target
                    let steerStrength: Float = 0.8 * dt  // gentle, dt-scaled
                    bounce.velocity += targetDirection * steerStrength
                }

                // Velocity damping for smooth, floaty feel
                bounce.velocity *= (1.0 - 0.5 * dt)

                // Gentle hovering oscillation
                let hover = sin(fairy.totalTime * 1.5) * 0.002
                bounce.velocity.y += hover
            }

            // Clamp speed
            let speed = simd_length(bounce.velocity)
            if speed > fairy.flightSpeed {
                bounce.velocity = simd_normalize(bounce.velocity) * fairy.flightSpeed
            }

            entity.components[FairyBehaviorComponent.self] = fairy
            entity.components[BounceComponent.self] = bounce
        }
    }

    private static func randomRoomPoint() -> SIMD3<Float> {
        SIMD3<Float>(
            Float.random(in: -1.5...1.5),
            Float.random(in: 0.8...2.0),
            Float.random(in: -1.5...1.5)
        )
    }
}
