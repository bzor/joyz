//
//  HairSpringSystem.swift
//  JoyzAVP
//
//  Damped spring simulation for the fairy's hair on the X axis only.
//  Driven by Y velocity: moving up bobs hair down, moving down bobs hair up.
//

import RealityKit
import simd

struct HairSpringSystem: System {
    static let query = EntityQuery(where: .has(FairyBehaviorComponent.self) && .has(BounceComponent.self))

    // Spring parameters
    private static let stiffness: Float = 10.0
    private static let damping: Float = 0.8
    private static let velocityInfluence: Float = 120.0
    private static let restAngle: Float = -35.0 * (.pi / 180.0)  // -35° resting point

    // Asymmetric clamp: small upward bob, large downward bob
    private static let minAngle: Float = -120.0 * (.pi / 180.0)   // -120°
    private static let maxAngle: Float = -60.0 * (.pi / 180.0)   // -60°

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        guard dt > 0 && dt < 0.1 else { return }

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var fairy = entity.components[FairyBehaviorComponent.self],
                  let bounce = entity.components[BounceComponent.self],
                  let toy = entity.components[ToyComponent.self],
                  toy.isActive else { continue }

            // Y velocity drives the hair: up motion -> hair bobs down (positive X rot)
            let drive = -bounce.velocity.y * Self.velocityInfluence

            // Hooke's law on X axis only
            let force = -Self.stiffness * (fairy.hairAngleX - Self.restAngle) - Self.damping * fairy.hairVelocityX + drive

            // Semi-implicit Euler
            fairy.hairVelocityX += force * dt
            fairy.hairAngleX += fairy.hairVelocityX * dt

            // Asymmetric clamp
            fairy.hairAngleX = max(Self.minAngle, min(Self.maxAngle, fairy.hairAngleX))

            // Zero out Z — fixed
            fairy.hairAngleZ = 0
            fairy.hairVelocityZ = 0

            // Apply rotation to hair_pivot — X axis only
            guard let fairy001 = findDescendant(named: "fairy_001", in: entity),
                  let upper = findChild(named: "upper", in: fairy001),
                  let head = findChild(named: "head", in: upper),
                  let hairPivot = findChild(named: "hair_pivot", in: head) else {
                entity.components[FairyBehaviorComponent.self] = fairy
                continue
            }

            hairPivot.transform.rotation = simd_quatf(angle: fairy.hairAngleX, axis: SIMD3<Float>(1, 0, 0))

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
