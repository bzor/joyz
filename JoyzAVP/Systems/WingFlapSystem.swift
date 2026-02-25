//
//  WingFlapSystem.swift
//  JoyzAVP
//
//  Drives wing pivot entities with a fan-style flap on the Y axis.
//  Wings are treated as a fan: one base angle moves the group,
//  and each successive wing gets a spread offset so they never overlap.
//  Flap speed scales with upward velocity.
//

import RealityKit
import simd

struct WingFlapSystem: System {
    static let query = EntityQuery(where: .has(FairyBehaviorComponent.self) && .has(BounceComponent.self))

    // Flap parameters
    private static let baseFlapSpeed: Float = 6.0     // radians/sec at rest
    private static let maxFlapSpeed: Float = 55.0     // radians/sec at full speed
    private static let velocityForMaxFlap: Float = 0.4 // m/s Y velocity to hit max flap speed
    private static let flapAmplitudeUp: Float = .pi / 18   // 10° sweep upward (avoid dress clipping)
    private static let flapAmplitudeDown: Float = .pi / 6   // 30° sweep downward

    // Fan spread: angular gap between wing 1 and wing 7
    private static let minSpread: Float = .pi / 30     // 6° when wings compress together (bottom of flap)
    private static let maxSpread: Float = .pi / 8      // 22.5° when wings fan out (top of flap)

    private static let wingCount: Int = 7

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var fairy = entity.components[FairyBehaviorComponent.self],
                  let bounce = entity.components[BounceComponent.self],
                  let toy = entity.components[ToyComponent.self],
                  toy.isActive else { continue }

            // Scale flap speed with upward velocity only
            let speed = max(bounce.velocity.y, 0)
            let t01 = min(speed / Self.velocityForMaxFlap, 1.0)
            let flapSpeed = Self.baseFlapSpeed + (Self.maxFlapSpeed - Self.baseFlapSpeed) * t01

            // Accumulate phase incrementally so speed changes are smooth
            fairy.wingFlapPhase += flapSpeed * dt
            let phase = fairy.wingFlapPhase

            // Base flap angle — asymmetric: full sweep up, shallow sweep down
            let flapSin = sin(phase)
            let baseAngle = flapSin >= 0
                ? flapSin * Self.flapAmplitudeUp
                : flapSin * Self.flapAmplitudeDown

            // Spread breathes: wider at top of flap, tighter at bottom
            // flapSin ranges -1..1, remap to 0..1 for spread interpolation
            let breathe = (flapSin + 1.0) * 0.5
            let totalSpread = Self.minSpread + (Self.maxSpread - Self.minSpread) * breathe

            // Per-wing spread increment
            let spreadStep = totalSpread / Float(Self.wingCount - 1)

            guard let fairy001 = findDescendant(named: "fairy_001", in: entity) else { continue }
            guard let wingsPivot = findDescendant(named: "wings_pivot", in: fairy001) else { continue }

            if let wingsRight = findChild(named: "wings_right", in: wingsPivot) {
                for i in 1...Self.wingCount {
                    guard let pivot = findChild(named: "wing_right_\(i)_pivot", in: wingsRight) else { continue }
                    let fanOffset = spreadStep * Float(i - 1)
                    let angle = baseAngle + fanOffset
                    pivot.transform.rotation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
                }
            }

            if let wingsLeft = findChild(named: "wings_left", in: wingsPivot) {
                for i in 1...Self.wingCount {
                    guard let pivot = findChild(named: "wing_left_\(i)_pivot", in: wingsLeft) else { continue }
                    let fanOffset = spreadStep * Float(i - 1)
                    let angle = baseAngle + fanOffset
                    pivot.transform.rotation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
                }
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
