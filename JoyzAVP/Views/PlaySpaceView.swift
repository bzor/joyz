//
//  PlaySpaceView.swift
//  JoyzAVP
//

import SwiftUI
import RealityKit
import RealityKitContent

struct PlaySpaceView: View {
    @Environment(AppModel.self) private var appModel
    @State private var arSession = ARSessionManager()
    @State private var handTracking = HandTrackingManager()

    var body: some View {
        RealityView { content in
            // Root entity for the play space
            let root = Entity()
            root.name = "PlaySpaceRoot"
            content.add(root)

            // Make tracking data available to ECS systems
            HandTrackingManagerProvider.shared = handTracking
            WorldTrackingManagerProvider.shared = arSession.worldTracking

            // Create debug hand markers
            handTracking.createDebugMarkers(parent: root)

            // Start ARKit session, then kick off async processing tasks
            Task {
                await arSession.start()

                // Process scene mesh updates (if available)
                Task {
                    await arSession.processSceneUpdates(root: root)
                }

                // Process hand tracking updates (if available)
                if let handProvider = arSession.handTracking {
                    print("[PlaySpace] Hand tracking provider found, starting updates...")
                    Task {
                        await handTracking.processHandUpdates(provider: handProvider)
                    }
                } else {
                    print("[PlaySpace] WARNING: No hand tracking provider available!")
                }
            }

            // Initialize trail decoration system
            let trailRoot = Entity()
            trailRoot.name = "TrailRoot"
            root.addChild(trailRoot)
            TrailDecorationPool.shared.initialize(root: trailRoot)

            // Load the fairy toy
            await loadFairy(into: root)
        }
        .onDisappear {
            arSession.stop()
            HandTrackingManagerProvider.shared = nil
            WorldTrackingManagerProvider.shared = nil
        }
    }

    private func loadFairy(into root: Entity) async {
        let fairyRoot: Entity

        // Try to load the fairy model from RealityKitContent.
        // Falls back to a placeholder sphere if the model isn't imported yet.
        do {
            let loaded = try await Entity(named: "Fairy", in: realityKitContentBundle)
            fairyRoot = loaded
            print("Fairy model loaded successfully! Children: \(loaded.children.map { $0.name })")
        } catch {
            print("Failed to load Fairy scene: \(error)")
            // Placeholder: bright pink sphere
            let mesh = MeshResource.generateSphere(radius: 0.05)
            var material = UnlitMaterial()
            material.color = .init(tint: .init(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0))
            let model = ModelEntity(mesh: mesh, materials: [material])
            fairyRoot = Entity()
            fairyRoot.addChild(model)
        }

        fairyRoot.name = "FairyRoot"
        fairyRoot.position = SIMD3<Float>(0, 1.5, -1.0)

        // Attach ECS components for fairy behavior
        fairyRoot.components.set(ToyComponent(toyType: .fairy, isActive: true))
        var fairyBehavior = FairyBehaviorComponent()
        #if targetEnvironment(simulator)
        fairyBehavior.debugLissajous = true
        print("[Debug] Simulator detected — fairy using Lissajous flight path")
        #endif
        fairyRoot.components.set(fairyBehavior)
        fairyRoot.components.set(BounceComponent())
        fairyRoot.components.set(TrailEmitterComponent())

        root.addChild(fairyRoot)
        appModel.activeToyEntity = fairyRoot
    }
}
