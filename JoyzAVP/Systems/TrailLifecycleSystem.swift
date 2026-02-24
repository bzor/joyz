//
//  TrailLifecycleSystem.swift
//  JoyzAVP
//

import RealityKit

struct TrailLifecycleSystem: System {
    static let query = EntityQuery(where: .has(TrailDecorationComponent.self))

    init(scene: RealityKit.Scene) {}

    @MainActor
    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var deco = entity.components[TrailDecorationComponent.self] else { continue }
            deco.age += dt

            if deco.age > deco.maxAge + deco.fadeDuration {
                // Fully faded - recycle back to pool
                TrailDecorationPool.shared.recycle(entity)
            } else if deco.age > deco.maxAge {
                // Fading out
                let fadeProgress = (deco.age - deco.maxAge) / deco.fadeDuration
                entity.components[OpacityComponent.self] = OpacityComponent(opacity: 1.0 - fadeProgress)
                entity.components[TrailDecorationComponent.self] = deco
            } else {
                entity.components[TrailDecorationComponent.self] = deco
            }
        }
    }
}
