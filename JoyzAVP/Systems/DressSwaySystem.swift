//
//  DressSwaySystem.swift
//  JoyzAVP
//
//  Damped spring sway for the fairy's dress petals on the X axis.
//  Driven by Y velocity: moving up flares the dress out, moving down tucks it in.
//  Preserves original Y/Z rotations from the USD, only modifies X.
//

import RealityKit
import simd

struct DressSwaySystem: System {
    static let query = EntityQuery(where: .has(FairyBehaviorComponent.self) && .has(BounceComponent.self))

    // Original rotations captured on first frame, keyed by entity ID
    private static var originalRotations: [Entity.ID: simd_quatf] = [:]

    // Spring parameters
    private static let stiffness: Float = 15.0
    private static let damping: Float = 1.2
    private static let velocityInfluence: Float = 80.0

    private static let swayUp: Float = 4.0 * (.pi / 180.0)    // 4° tuck in (avoid leg clipping)
    private static let swayDown: Float = 10.0 * (.pi / 180.0) // 10° flare out

    private static let petalCount: Int = 12

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        guard dt > 0 && dt < 0.1 else { return }

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var fairy = entity.components[FairyBehaviorComponent.self],
                  let bounce = entity.components[BounceComponent.self],
                  let toy = entity.components[ToyComponent.self],
                  toy.isActive else { continue }

            // Compute clamped target from Y velocity
            let rawTarget = -bounce.velocity.y * Self.velocityInfluence
            let target = max(-Self.swayUp, min(Self.swayDown, rawTarget))

            // Spring pulls toward the clamped target — free to overshoot
            let force = -Self.stiffness * (fairy.dressAngleX - target) - Self.damping * fairy.dressVelocityX

            // Semi-implicit Euler
            fairy.dressVelocityX += force * dt
            fairy.dressAngleX += fairy.dressVelocityX * dt

            let swayQuat = simd_quatf(angle: fairy.dressAngleX, axis: SIMD3<Float>(1, 0, 0))

            // Apply to all dress pivots
            guard let fairy001 = findDescendant(named: "fairy_001", in: entity),
                  let dress = findChild(named: "dress", in: fairy001) else {
                entity.components[FairyBehaviorComponent.self] = fairy
                continue
            }

            for i in 1...Self.petalCount {
                guard let pivot = findChild(named: "dress_pivot_\(i)", in: dress) else { continue }

                // Capture original rotation on first encounter
                if Self.originalRotations[pivot.id] == nil {
                    Self.originalRotations[pivot.id] = pivot.transform.rotation
                }

                let original = Self.originalRotations[pivot.id]!
                // Apply sway on top of the original rotation
                pivot.transform.rotation = original * swayQuat
            }

            entity.components[FairyBehaviorComponent.self] = fairy
        }
    }

    private func findChild(named name: String, in entity: Entity) -> Entity? {
        entity.children.first { $0.name == name }
    }

    private func findDescendant(named name: String, in entity: Entity) -> Entity? {
        for child in entity.children {
            if child.name == name { return child }
            if let found = findDescendant(named: name, in: child) { return found }
        }
        return nil
    }
}
