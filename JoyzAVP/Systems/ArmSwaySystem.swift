//
//  ArmSwaySystem.swift
//  JoyzAVP
//
//  Spring-driven Z-axis sway for the fairy's arm joints.
//  Driven by Y velocity so arms bob up and down with flight.
//  Preserves original rotations from the USD.
//

import RealityKit
import simd

struct ArmSwaySystem: System {
    static let query = EntityQuery(where: .has(FairyBehaviorComponent.self) && .has(BounceComponent.self))

    // Original rotations captured on first frame
    private static var originalRotations: [Entity.ID: simd_quatf] = [:]

    // Spring parameters
    private static let stiffness: Float = 12.0
    private static let damping: Float = 1.5
    private static let velocityInfluence: Float = 60.0
    private static let swayDown: Float = 5.0 * (.pi / 180.0)   // 5° downward
    private static let swayUp: Float = 25.0 * (.pi / 180.0)   // 25° upward

    // Pivot names to animate
    private static let rightPivots = ["shoulder_right", "elbow_right_pivot", "wrist_right_pivot"]
    private static let leftPivots = ["shoulder_left_pivot", "elbow_left_pivot", "wrist_left_pivot"]

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        guard dt > 0 && dt < 0.1 else { return }

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var fairy = entity.components[FairyBehaviorComponent.self],
                  let bounce = entity.components[BounceComponent.self],
                  let toy = entity.components[ToyComponent.self],
                  toy.isActive else { continue }

            // Clamped target from Y velocity
            let rawTarget = -bounce.velocity.y * Self.velocityInfluence
            let target = max(-Self.swayDown, min(Self.swayUp, rawTarget))

            // Spring toward clamped target
            let force = -Self.stiffness * (fairy.armsAngleZ - target) - Self.damping * fairy.armsVelocityZ

            // Semi-implicit Euler
            fairy.armsVelocityZ += force * dt
            fairy.armsAngleZ += fairy.armsVelocityZ * dt

            guard let fairy001 = findDescendant(named: "fairy_001", in: entity),
                  let upper = findChild(named: "upper", in: fairy001),
                  let arms = findChild(named: "arms", in: upper) else {
                entity.components[FairyBehaviorComponent.self] = fairy
                continue
            }

            let swayQuat = simd_quatf(angle: fairy.armsAngleZ, axis: SIMD3<Float>(0, 0, 1))

            // Apply to all arm pivots
            applySwayToPivots(Self.rightPivots, root: arms, sway: swayQuat)
            applySwayToPivots(Self.leftPivots, root: arms, sway: swayQuat)

            entity.components[FairyBehaviorComponent.self] = fairy
        }
    }

    private func applySwayToPivots(_ names: [String], root: Entity, sway: simd_quatf) {
        for name in names {
            guard let pivot = findDescendant(named: name, in: root) else { continue }

            if Self.originalRotations[pivot.id] == nil {
                Self.originalRotations[pivot.id] = pivot.transform.rotation
            }

            let original = Self.originalRotations[pivot.id]!
            pivot.transform.rotation = original * sway
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
