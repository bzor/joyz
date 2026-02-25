//
//  WallBounceSystem.swift
//  JoyzAVP
//

import ARKit
import QuartzCore
import RealityKit
import simd

struct WallBounceSystem: System {
    static let query = EntityQuery(where: .has(BounceComponent.self))
    static let dependencies: [SystemDependency] = [.after(FairyMovementSystem.self)]

    // Raycast probe directions — 6 cardinal + 8 diagonal for good corner coverage
    private static let probeDirections: [SIMD3<Float>] = {
        var dirs: [SIMD3<Float>] = [
            // Cardinal
            SIMD3<Float>( 1,  0,  0),
            SIMD3<Float>(-1,  0,  0),
            SIMD3<Float>( 0,  0,  1),
            SIMD3<Float>( 0,  0, -1),
            SIMD3<Float>( 0,  1,  0),
            SIMD3<Float>( 0, -1,  0),
            // Horizontal diagonals
            SIMD3<Float>( 1,  0,  1),
            SIMD3<Float>( 1,  0, -1),
            SIMD3<Float>(-1,  0,  1),
            SIMD3<Float>(-1,  0, -1),
            // Upward diagonals
            SIMD3<Float>( 1,  1,  0),
            SIMD3<Float>(-1,  1,  0),
            // Downward diagonals
            SIMD3<Float>( 1, -1,  0),
            SIMD3<Float>(-1, -1,  0),
        ]
        return dirs.map { simd_normalize($0) }
    }()

    /// How far out to sense walls (meters)
    private static let senseRange: Float = 1.0

    /// How strongly to repel from nearby surfaces
    private static let repelStrength: Float = 0.6

    /// Minimum floor clearance (meters)
    private static let minFloorClearance: Float = 0.3

    /// Body cylinder avoidance — radius from head center
    private static let bodyCylinderRadius: Float = 0.35
    /// How far out to start sensing the body cylinder
    private static let bodySenseRange: Float = 0.6
    /// How strongly to push away from the body cylinder
    private static let bodyRepelStrength: Float = 3.0

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var bounce = entity.components[BounceComponent.self] else { continue }

            // Skip wall avoidance when debug Lissajous is driving position directly
            if let fairy = entity.components[FairyBehaviorComponent.self], fairy.debugLissajous {
                continue
            }

            guard let scene = entity.scene else {
                entity.position += bounce.velocity * dt
                entity.components[BounceComponent.self] = bounce
                continue
            }

            let origin = entity.position(relativeTo: nil)

            // Accumulate avoidance force from all nearby surfaces
            var avoidance = SIMD3<Float>.zero

            for direction in Self.probeDirections {
                let results = scene.raycast(
                    origin: origin,
                    direction: direction,
                    length: Self.senseRange,
                    query: .nearest,
                    mask: .sceneUnderstanding
                )

                if let hit = results.first {
                    let distance = hit.distance
                    // Strength falls off with distance: strongest when very close, zero at senseRange
                    // Using inverse-square-ish falloff for a natural feel
                    let proximity = 1.0 - (distance / Self.senseRange)  // 1.0 at surface, 0.0 at senseRange
                    let force = proximity * proximity  // quadratic falloff — gentle at range, strong up close
                    // Push away from the surface (opposite of probe direction)
                    avoidance -= direction * force
                }
            }

            // Apply wall avoidance as a steering force on velocity
            let avoidLen = simd_length(avoidance)
            if avoidLen > 0.001 {
                bounce.velocity += avoidance * Self.repelStrength * dt
            }

            // Body cylinder avoidance — keep fairy out of head/torso area
            if let worldTracking = WorldTrackingManagerProvider.shared,
               let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
                let headPos = SIMD3<Float>(
                    deviceAnchor.originFromAnchorTransform.columns.3.x,
                    deviceAnchor.originFromAnchorTransform.columns.3.y,
                    deviceAnchor.originFromAnchorTransform.columns.3.z
                )

                // Project fairy onto horizontal plane relative to head — only care about XZ distance
                let fairyToHead = origin - headPos
                let horizontalOffset = SIMD3<Float>(fairyToHead.x, 0, fairyToHead.z)
                let horizontalDist = simd_length(horizontalOffset)

                // Only repel if fairy is below head level (the cylinder extends downward)
                // and within the sense range horizontally
                let isBelowHead = origin.y < headPos.y + 0.1
                if isBelowHead && horizontalDist < Self.bodySenseRange {
                    let proximity = 1.0 - (horizontalDist / Self.bodySenseRange)
                    let force = proximity * proximity * Self.bodyRepelStrength

                    if horizontalDist > 0.01 {
                        let outwardDir = simd_normalize(horizontalOffset)

                        // Cancel any velocity heading inward toward the body
                        let horizontalVel = SIMD3<Float>(bounce.velocity.x, 0, bounce.velocity.z)
                        let inwardAmount = -simd_dot(horizontalVel, outwardDir)
                        if inwardAmount > 0 {
                            // Strip the inward component, scaled by proximity
                            bounce.velocity += outwardDir * inwardAmount * proximity
                        }

                        // Push outward horizontally from the cylinder axis
                        bounce.velocity += outwardDir * force * dt
                    } else {
                        // Fairy is right on the axis — push in velocity direction or arbitrary
                        let escape = simd_length(bounce.velocity) > 0.01
                            ? simd_normalize(SIMD3<Float>(bounce.velocity.x, 0, bounce.velocity.z))
                            : SIMD3<Float>(1, 0, 0)
                        bounce.velocity += escape * force * dt
                    }
                }
            }

            // Apply velocity to position
            entity.position += bounce.velocity * dt

            entity.components[BounceComponent.self] = bounce
        }
    }
}
