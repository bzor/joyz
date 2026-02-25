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
        DebugLissajousSystem.registerSystem()
        WallBounceSystem.registerSystem()
        WingFlapSystem.registerSystem()
        HairSpringSystem.registerSystem()
        DressSwaySystem.registerSystem()
        ArmSwaySystem.registerSystem()
        LegSwaySystem.registerSystem()
        FootFlutterSystem.registerSystem()
        HandInteractionSystem.registerSystem()
        TrailSpawnerSystem.registerSystem()
        TrailLifecycleSystem.registerSystem()
    }
}
