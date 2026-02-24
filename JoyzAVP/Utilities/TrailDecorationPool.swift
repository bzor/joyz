//
//  TrailDecorationPool.swift
//  JoyzAVP
//

import RealityKit
import UIKit
import simd

@MainActor
class TrailDecorationPool {
    static let shared = TrailDecorationPool()

    private var pool: [Entity] = []
    private var activeCount = 0
    private let maxDecorations = 200
    private var trailRoot: Entity?

    // Bright Murakami-style colors
    private static let colors: [UIColor] = [
        UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0),  // Hot pink
        UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0), // Sunshine yellow
        UIColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0),  // Sky blue
        UIColor(red: 0.5, green: 1.0, blue: 0.3, alpha: 1.0),  // Lime green
        UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),  // Orange
        UIColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 1.0),  // Purple
    ]

    func initialize(root: Entity) {
        self.trailRoot = root

        // Pre-populate the pool with decoration entities
        for _ in 0..<150 {
            let entity = createDecorationEntity()
            pool.append(entity)
        }
    }

    func spawnDecoration(at position: SIMD3<Float>, normal: SIMD3<Float>) {
        guard activeCount < maxDecorations, let trailRoot else { return }

        let entity: Entity
        if let recycled = pool.popLast() {
            entity = recycled
        } else {
            entity = createDecorationEntity()
        }

        // Orient to surface normal with random rotation on the surface plane
        let up = normal
        // Find a tangent vector (avoid degenerate cross product)
        let reference: SIMD3<Float> = abs(up.y) < 0.99 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
        let right = simd_normalize(simd_cross(up, reference))
        let forward = simd_cross(right, up)
        let rotation = simd_quatf(simd_float3x3(columns: (right, up, forward)))
        let randomSpin = simd_quatf(angle: Float.random(in: 0...Float.pi * 2), axis: up)

        // Random size variety
        let scale = Float.random(in: 0.03...0.06)

        entity.transform = Transform(
            scale: SIMD3<Float>(repeating: scale),
            rotation: randomSpin * rotation,
            translation: position + normal * 0.002  // Slight offset to prevent z-fighting
        )

        // Randomize the color tint
        let color = Self.colors.randomElement()!
        if let model = entity.children.first as? ModelEntity {
            var material = UnlitMaterial()
            material.color = .init(tint: color)
            model.model?.materials = [material]
        }

        entity.components.set(TrailDecorationComponent())
        entity.components.set(OpacityComponent(opacity: 1.0))

        trailRoot.addChild(entity)
        activeCount += 1
    }

    func recycle(_ entity: Entity) {
        entity.removeFromParent()
        entity.components.remove(TrailDecorationComponent.self)
        pool.append(entity)
        activeCount -= 1
    }

    private func createDecorationEntity() -> Entity {
        // Create a small flat plane as the decoration shape.
        // These will be replaced with proper Murakami ShaderGraph assets
        // once created in Reality Composer Pro.
        let mesh = MeshResource.generatePlane(width: 1.0, height: 1.0)
        var material = UnlitMaterial()
        material.color = .init(tint: Self.colors.randomElement()!)

        let model = ModelEntity(mesh: mesh, materials: [material])
        let container = Entity()
        container.addChild(model)
        return container
    }
}
