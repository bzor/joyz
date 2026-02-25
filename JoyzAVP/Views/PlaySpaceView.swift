//
//  PlaySpaceView.swift
//  JoyzAVP
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import QuartzCore

struct PlaySpaceView: View {
    @Environment(AppModel.self) private var appModel
    @State private var arSession = ARSessionManager()
    @State private var handTracking = HandTrackingManager()
    @State private var playSpaceRoot: Entity?
    @State private var fairySpawned = false

    var body: some View {
        RealityView { content in
            // Root entity for the play space
            let root = Entity()
            root.name = "PlaySpaceRoot"
            content.add(root)
            playSpaceRoot = root

            // Make tracking data available to ECS systems
            HandTrackingManagerProvider.shared = handTracking
            WorldTrackingManagerProvider.shared = arSession.worldTracking

            // Create debug hand markers
            handTracking.createDebugMarkers(parent: root)

            // Start ARKit session, then kick off async processing tasks
            Task {
                await arSession.start()

                Task {
                    await arSession.processSceneUpdates(root: root)
                }

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

            // Pre-load the fairy model (but don't position it yet — wait for transform)
            await preloadFairy(into: root)
        } update: { content in
            // Step 1: Convert coordinate spaces (one-time, independent of fairy loading)
            if appModel.needsToyboxConversion,
               let immersiveFromToybox = appModel.immersiveSpaceFromToybox {
                let sceneFromImmersive = content.transform(from: .immersiveSpace, to: .scene)
                let composed = sceneFromImmersive * AffineTransform3D(truncating: immersiveFromToybox)
                let matrix = simd_float4x4(composed)
                let toyboxCenter = SIMD3<Float>(
                    matrix.columns.3.x,
                    matrix.columns.3.y,
                    matrix.columns.3.z
                )

                appModel.toyboxWorldCenter = toyboxCenter
                appModel.needsToyboxConversion = false
                appModel.toyboxConvertedToScene = true
                print("[PlaySpace] Toybox world center: \(toyboxCenter)")
            }

            // Step 2: Position fairy once we have BOTH the converted coordinates AND the loaded entity
            if !appModel.fairyHasLaunched,
               appModel.toyboxConvertedToScene,
               let toyboxCenter = appModel.toyboxWorldCenter,
               let fairy = appModel.activeToyEntity {
                let spawnPos = toyboxCenter + SIMD3<Float>(0, 0.3, 0)
                fairy.position = spawnPos

                // Activate the toy so ECS systems start running
                if var toy = fairy.components[ToyComponent.self] {
                    toy.isActive = true
                    fairy.components[ToyComponent.self] = toy
                }
                if var fairyBehavior = fairy.components[FairyBehaviorComponent.self] {
                    fairyBehavior.flightTarget = spawnPos + SIMD3(0, 0.8, 0)
                    fairyBehavior.timeUntilNewTarget = 2.5
                    fairyBehavior.launchTimer = 1.5  // skip avoidance for 1.5s
                    fairy.components[FairyBehaviorComponent.self] = fairyBehavior
                }
                if var bounce = fairy.components[BounceComponent.self] {
                    bounce.velocity = SIMD3(0, 0.3, 0)
                    fairy.components[BounceComponent.self] = bounce
                }

                appModel.fairyHasLaunched = true
                fairySpawned = true
                print("[PlaySpace] Fairy spawned at \(spawnPos)")
            }
        }
        .onDisappear {
            arSession.stop()
            HandTrackingManagerProvider.shared = nil
            WorldTrackingManagerProvider.shared = nil
        }
    }

    /// Pre-load the fairy model and attach components, but don't set final position yet.
    private func preloadFairy(into root: Entity) async {
        let fairyRoot: Entity

        do {
            let loaded = try await Entity(named: "Fairy", in: realityKitContentBundle)
            fairyRoot = loaded
            print("Fairy model loaded successfully! Children: \(loaded.children.map { $0.name })")
        } catch {
            print("Failed to load Fairy scene: \(error)")
            let mesh = MeshResource.generateSphere(radius: 0.05)
            var material = UnlitMaterial()
            material.color = .init(tint: .init(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0))
            let model = ModelEntity(mesh: mesh, materials: [material])
            fairyRoot = Entity()
            fairyRoot.addChild(model)
        }

        fairyRoot.name = "FairyRoot"
        // Temporary position — will be updated once we get the toybox transform
        fairyRoot.position = SIMD3<Float>(0, 1.2, -0.6)

        // Start inactive — systems won't run until we reposition from the coordinate conversion
        fairyRoot.components.set(ToyComponent(toyType: .fairy, isActive: false))
        var fairyBehavior = FairyBehaviorComponent()
        fairyBehavior.debugLissajous = false
        fairyRoot.components.set(fairyBehavior)
        var bounce = BounceComponent()
        bounce.velocity = .zero
        fairyRoot.components.set(bounce)
        fairyRoot.components.set(TrailEmitterComponent())

        // Invisible shadow proxy
        let shadowProxy = ModelEntity(
            mesh: .generateSphere(radius: 0.07),
            materials: [SimpleMaterial(color: .white, isMetallic: false)]
        )
        shadowProxy.name = "ShadowProxy"
        shadowProxy.components.set(OpacityComponent(opacity: 0))
        shadowProxy.components.set(GroundingShadowComponent(castsShadow: true))
        fairyRoot.addChild(shadowProxy)

        root.addChild(fairyRoot)
        appModel.activeToyEntity = fairyRoot
    }
}
