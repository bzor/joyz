//
//  FootFlutterSystem.swift
//  JoyzAVP
//
//  Flutters the foot pivots on the X axis, offset from each other.
//  Speed increases with positive Y velocity, similar to wing flap.
//  Preserves original rotations from the USD.
//

import RealityKit
import simd

struct FootFlutterSystem: System {
    static let query = EntityQuery(where: .has(FairyBehaviorComponent.self) && .has(BounceComponent.self))

    // Original rotations captured on first frame
    private static var originalRotations: [Entity.ID: simd_quatf] = [:]

    // Flutter parameters
    private static let baseSpeed: Float = 4.0       // radians/sec at rest
    private static let maxSpeed: Float = 30.0       // radians/sec at full speed
    private static let velocityForMax: Float = 0.4  // m/s Y velocity to hit max
    private static let amplitude: Float = .pi / 5   // 36° sweep

    // Phase offset between left and right feet
    private static let phaseOffset: Float = .pi      // 180° — alternating

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var fairy = entity.components[FairyBehaviorComponent.self],
                  let bounce = entity.components[BounceComponent.self],
                  let toy = entity.components[ToyComponent.self],
                  toy.isActive else { continue }

            // Speed scales with positive Y velocity
            let speed = max(bounce.velocity.y, 0)
            let t01 = min(speed / Self.velocityForMax, 1.0)
            let flutterSpeed = Self.baseSpeed + (Self.maxSpeed - Self.baseSpeed) * t01

            // Accumulate phase
            fairy.footFlutterPhase += flutterSpeed * dt
            let phase = fairy.footFlutterPhase

            guard let fairy001 = findDescendant(named: "fairy_001", in: entity),
                  let lower = findChild(named: "lower", in: fairy001),
                  let legsPivot = findChild(named: "legs_pivot", in: lower) else {
                entity.components[FairyBehaviorComponent.self] = fairy
                continue
            }

            // Right foot
            if let legRight = findChild(named: "leg_right", in: legsPivot),
               let footRightPivot = findChild(named: "foot_right_pivot", in: legRight) {
                if Self.originalRotations[footRightPivot.id] == nil {
                    Self.originalRotations[footRightPivot.id] = footRightPivot.transform.rotation
                }
                let original = Self.originalRotations[footRightPivot.id]!
                let angle = sin(phase) * Self.amplitude
                let flutter = simd_quatf(angle: angle, axis: SIMD3<Float>(1, 0, 0))
                footRightPivot.transform.rotation = original * flutter
            }

            // Left foot — offset phase
            if let legLeft = findChild(named: "leg_left", in: legsPivot),
               let footLeftPivot = findChild(named: "foot_left_pivot", in: legLeft) {
                if Self.originalRotations[footLeftPivot.id] == nil {
                    Self.originalRotations[footLeftPivot.id] = footLeftPivot.transform.rotation
                }
                let original = Self.originalRotations[footLeftPivot.id]!
                let angle = sin(phase + Self.phaseOffset) * Self.amplitude
                let flutter = simd_quatf(angle: angle, axis: SIMD3<Float>(1, 0, 0))
                footLeftPivot.transform.rotation = original * flutter
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
