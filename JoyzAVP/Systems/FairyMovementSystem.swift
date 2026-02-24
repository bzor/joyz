//
//  FairyMovementSystem.swift
//  JoyzAVP
//

import ARKit
import QuartzCore
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
                // Get head position and forward direction for body avoidance + target bias
                var headPos: SIMD3<Float>?
                var headForward: SIMD3<Float>?
                if let worldTracking = WorldTrackingManagerProvider.shared,
                   let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
                    let m = anchor.originFromAnchorTransform
                    headPos = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
                    // Device -Z is forward; project onto horizontal plane
                    let fwd = -SIMD3<Float>(m.columns.2.x, 0, m.columns.2.z)
                    let fwdLen = simd_length(fwd)
                    headForward = fwdLen > 0.001 ? fwd / fwdLen : nil
                }

                // Autonomous flight: steer toward target with smooth damping
                fairy.timeUntilNewTarget -= dt
                if fairy.timeUntilNewTarget <= 0 {
                    fairy.flightTarget = Self.randomRoomPoint(headPos: headPos, headForward: headForward)
                    fairy.timeUntilNewTarget = fairy.targetChangePeriod
                }

                // If current target ended up inside the body cylinder, pick a new one
                if let head = headPos {
                    let targetToHead = fairy.flightTarget - head
                    let targetHorizDist = simd_length(SIMD3<Float>(targetToHead.x, 0, targetToHead.z))
                    if targetHorizDist < 0.7 && fairy.flightTarget.y < head.y + 0.1 {
                        fairy.flightTarget = Self.randomRoomPoint(headPos: headPos, headForward: headForward)
                        fairy.timeUntilNewTarget = fairy.targetChangePeriod
                    }
                }

                let currentPos = entity.position(relativeTo: nil)
                let toTarget = fairy.flightTarget - currentPos
                let distance = simd_length(toTarget)

                if distance > 0.05 {
                    let targetDirection = toTarget / distance

                    // Reduce steering when close to the body to avoid fighting avoidance
                    var steerScale: Float = 1.0
                    if let head = headPos {
                        let toHead = currentPos - head
                        let horizDist = simd_length(SIMD3<Float>(toHead.x, 0, toHead.z))
                        let isBelowHead = currentPos.y < head.y + 0.1
                        if isBelowHead && horizDist < 0.8 {
                            // Suppress steering proportionally — zero at body, full at 0.8m out
                            steerScale = horizDist / 0.8
                        }
                    }

                    let steerStrength: Float = 0.8 * dt * steerScale
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

    private static func randomRoomPoint(headPos: SIMD3<Float>? = nil, headForward: SIMD3<Float>? = nil) -> SIMD3<Float> {
        // If we have head data, generate points biased in front of the user
        if let head = headPos, let fwd = headForward {
            // Right vector (perpendicular to forward on horizontal plane)
            let right = SIMD3<Float>(fwd.z, 0, -fwd.x)

            for _ in 0..<10 {
                // Generate in front: 0.5–2.0m forward, ±1.5m sideways
                let forwardDist = Float.random(in: 0.5...2.0)
                let sideDist = Float.random(in: -1.5...1.5)
                let y = Float.random(in: 0.8...2.0)

                let point = head + fwd * forwardDist + right * sideDist
                let result = SIMD3<Float>(point.x, y, point.z)

                // Still reject points inside the body cylinder
                let offset = result - head
                let horizDist = simd_length(SIMD3<Float>(offset.x, 0, offset.z))
                if horizDist < 0.7 && result.y < head.y + 0.1 {
                    continue
                }
                return result
            }
        }

        // Fallback when no head data
        return SIMD3<Float>(
            Float.random(in: -1.5...1.5),
            Float.random(in: 0.8...2.0),
            Float.random(in: -1.5...1.5)
        )
    }
}
