//
//  LegSwaySystem.swift
//  JoyzAVP
//
//  Spring-driven sway for the fairy's lower body (legs).
//  Tilts opposite to world velocity in the fairy's local space,
//  so the legs trail behind as she flies and spins.
//

import RealityKit
import simd

struct LegSwaySystem: System {
    static let query = EntityQuery(where: .has(FairyBehaviorComponent.self) && .has(BounceComponent.self))

    // Original rotation captured on first frame
    private static var originalRotation: [Entity.ID: simd_quatf] = [:]

    // Spring parameters
    private static let stiffness: Float = 12.0
    private static let damping: Float = 1.5
    private static let velocityInfluence: Float = 1.5
    private static let maxTilt: Float = 12.0 * (.pi / 180.0)  // 12° max target tilt

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        guard dt > 0 && dt < 0.1 else { return }

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var fairy = entity.components[FairyBehaviorComponent.self],
                  let bounce = entity.components[BounceComponent.self],
                  let toy = entity.components[ToyComponent.self],
                  toy.isActive else { continue }

            guard let fairy001 = findDescendant(named: "fairy_001", in: entity),
                  let lower = findChild(named: "lower", in: fairy001) else {
                continue
            }

            // Capture original rotation on first encounter
            if Self.originalRotation[lower.id] == nil {
                Self.originalRotation[lower.id] = lower.transform.rotation
            }

            // Transform world velocity into the fairy's local space
            let invRotation = entity.transform.rotation.inverse
            let localVel = invRotation.act(bounce.velocity)

            // Legs tilt opposite to velocity:
            //   local X velocity -> tilt on Z axis (lean sideways)
            //   local Z velocity -> tilt on X axis (lean forward/back)
            let targetX = max(-Self.maxTilt, min(Self.maxTilt,  localVel.z * Self.velocityInfluence))
            let targetZ = max(-Self.maxTilt, min(Self.maxTilt, -localVel.x * Self.velocityInfluence))

            // Spring toward clamped target — free to overshoot
            let forceX = -Self.stiffness * (fairy.legsAngleX - targetX) - Self.damping * fairy.legsVelocityX
            let forceZ = -Self.stiffness * (fairy.legsAngleZ - targetZ) - Self.damping * fairy.legsVelocityZ

            // Semi-implicit Euler
            fairy.legsVelocityX += forceX * dt
            fairy.legsVelocityZ += forceZ * dt
            fairy.legsAngleX += fairy.legsVelocityX * dt
            fairy.legsAngleZ += fairy.legsVelocityZ * dt

            // Apply rotation on top of original
            let original = Self.originalRotation[lower.id]!
            let swayX = simd_quatf(angle: fairy.legsAngleX, axis: SIMD3<Float>(1, 0, 0))
            let swayZ = simd_quatf(angle: fairy.legsAngleZ, axis: SIMD3<Float>(0, 0, 1))
            lower.transform.rotation = original * swayX * swayZ

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
