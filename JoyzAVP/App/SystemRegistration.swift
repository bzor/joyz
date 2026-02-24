//
//  SystemRegistration.swift
//  JoyzAVP
//

import RealityKit

enum SystemRegistration {
    static func registerAll() {
        // Components
        MeshClassificationComponent.registerComponent()
        ToyComponent.registerComponent()
        FairyBehaviorComponent.registerComponent()
        BounceComponent.registerComponent()
        TrailEmitterComponent.registerComponent()
        TrailDecorationComponent.registerComponent()

        // Systems
        FairyMovementSystem.registerSystem()
        WallBounceSystem.registerSystem()
        HandInteractionSystem.registerSystem()
        TrailSpawnerSystem.registerSystem()
        TrailLifecycleSystem.registerSystem()
    }
}
