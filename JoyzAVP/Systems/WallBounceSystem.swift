//
//  WallBounceSystem.swift
//  JoyzAVP
//

import RealityKit
import simd

struct WallBounceSystem: System {
    static let query = EntityQuery(where: .has(BounceComponent.self))
    static let dependencies: [SystemDependency] = [.after(FairyMovementSystem.self)]

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var bounce = entity.components[BounceComponent.self] else { continue }

            // Apply velocity to position
            entity.position += bounce.velocity * dt

            // Raycast in velocity direction to detect nearby surfaces
            let speed = simd_length(bounce.velocity)
            guard speed > 0.01, let scene = entity.scene else { continue }

            let origin = entity.position(relativeTo: nil)
            let direction = simd_normalize(bounce.velocity)
            let lookAhead: Float = 0.15

            let results = scene.raycast(
                origin: origin,
                direction: direction,
                length: lookAhead,
                query: .nearest,
                mask: .sceneUnderstanding
            )

            if let hit = results.first {
                // Reflect velocity off the surface normal
                let normal = hit.normal
                bounce.velocity = Self.reflect(bounce.velocity, normal: normal) * bounce.bounciness

                // Push entity slightly away from surface to prevent sticking
                let pushBack = normal * 0.02
                entity.position += pushBack
            }

            // Also check downward to prevent falling through floor
            let downResults = scene.raycast(
                origin: origin,
                direction: SIMD3<Float>(0, -1, 0),
                length: 0.1,
                query: .nearest,
                mask: .sceneUnderstanding
            )
            if let floorHit = downResults.first, bounce.velocity.y < 0 {
                bounce.velocity.y = abs(bounce.velocity.y) * bounce.bounciness
                entity.position.y = floorHit.position.y + 0.1
            }

            entity.components[BounceComponent.self] = bounce
        }
    }

    private static func reflect(_ v: SIMD3<Float>, normal n: SIMD3<Float>) -> SIMD3<Float> {
        return v - 2 * simd_dot(v, n) * n
    }
}
