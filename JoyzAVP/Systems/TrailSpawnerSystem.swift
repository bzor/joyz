//
//  TrailSpawnerSystem.swift
//  JoyzAVP
//

import RealityKit
import simd

struct TrailSpawnerSystem: System {
    static let query = EntityQuery(where: .has(TrailEmitterComponent.self))

    init(scene: RealityKit.Scene) {}

    @MainActor
    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var emitter = entity.components[TrailEmitterComponent.self] else { continue }

            emitter.timeSinceLastEmission += dt
            let interval = 1.0 / emitter.emissionRate

            guard emitter.timeSinceLastEmission >= interval else {
                entity.components[TrailEmitterComponent.self] = emitter
                continue
            }

            emitter.timeSinceLastEmission = 0
            entity.components[TrailEmitterComponent.self] = emitter

            // Raycast in 6 directions to find nearby surfaces
            guard let scene = entity.scene else { continue }
            let origin = entity.position(relativeTo: nil)

            let directions: [SIMD3<Float>] = [
                SIMD3<Float>(0, -1, 0), SIMD3<Float>(0, 1, 0),
                SIMD3<Float>(1, 0, 0), SIMD3<Float>(-1, 0, 0),
                SIMD3<Float>(0, 0, 1), SIMD3<Float>(0, 0, -1)
            ]

            for dir in directions {
                let results = scene.raycast(
                    origin: origin,
                    direction: dir,
                    length: emitter.surfaceProximityThreshold,
                    query: .nearest,
                    mask: .sceneUnderstanding
                )

                if let hit = results.first {
                    TrailDecorationPool.shared.spawnDecoration(
                        at: hit.position,
                        normal: hit.normal
                    )
                    break  // One decoration per emission tick
                }
            }
        }
    }
}
