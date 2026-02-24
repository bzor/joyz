//
//  ARSessionManager.swift
//  JoyzAVP
//

import ARKit
import RealityKit

@Observable
@MainActor
class ARSessionManager {
    let session = ARKitSession()
    let worldTracking = WorldTrackingProvider()

    // These providers are only available on real hardware, not Simulator
    private(set) var handTracking: HandTrackingProvider?
    private var sceneReconstruction: SceneReconstructionProvider?
    private var meshEntities: [UUID: Entity] = [:]

    func start() async {
        var providers: [any DataProvider] = [worldTracking]

        if HandTrackingProvider.isSupported {
            let provider = HandTrackingProvider()
            handTracking = provider
            providers.append(provider)
            print("[ARKit] Hand tracking provider created")
        } else {
            print("[ARKit] Hand tracking NOT supported on this device. Skipping.")
        }

        if SceneReconstructionProvider.isSupported {
            let provider = SceneReconstructionProvider(modes: [.classification])
            sceneReconstruction = provider
            providers.append(provider)
            print("[ARKit] Scene reconstruction provider created")
        } else {
            print("[ARKit] Scene reconstruction NOT supported on this device. Skipping.")
        }

        print("[ARKit] Starting session with \(providers.count) providers...")
        do {
            try await session.run(providers)
            print("[ARKit] Session started successfully!")
        } catch {
            print("[ARKit] Failed to start ARKit session: \(error)")
        }
    }

    func stop() {
        session.stop()
        meshEntities.removeAll()
    }

    /// Process scene mesh updates and create invisible collision entities.
    func processSceneUpdates(root: Entity) async {
        guard let sceneReconstruction else {
            print("Scene reconstruction not available - no mesh updates to process.")
            return
        }
        for await update in sceneReconstruction.anchorUpdates {
            await handleMeshAnchorUpdate(update, root: root)
        }
    }

    private func handleMeshAnchorUpdate(_ update: AnchorUpdate<MeshAnchor>, root: Entity) async {
        let anchor = update.anchor

        switch update.event {
        case .added:
            let entity = await createMeshEntity(for: anchor)
            root.addChild(entity)
            meshEntities[anchor.id] = entity

        case .updated:
            if let entity = meshEntities[anchor.id] {
                await updateMeshEntity(entity, with: anchor)
            }

        case .removed:
            meshEntities[anchor.id]?.removeFromParent()
            meshEntities.removeValue(forKey: anchor.id)
        }
    }

    private func createMeshEntity(for anchor: MeshAnchor) async -> Entity {
        let entity = Entity()
        entity.name = "SceneMesh-\(anchor.id)"
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)

        if let shape = try? await ShapeResource.generateStaticMesh(from: anchor) {
            entity.components.set(CollisionComponent(
                shapes: [shape],
                filter: CollisionFilter(group: .sceneUnderstanding, mask: .all)
            ))
        }

        if let classification = dominantClassification(for: anchor) {
            entity.components.set(MeshClassificationComponent(classification: classification))
        }

        return entity
    }

    private func updateMeshEntity(_ entity: Entity, with anchor: MeshAnchor) async {
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)

        if let shape = try? await ShapeResource.generateStaticMesh(from: anchor) {
            entity.components.set(CollisionComponent(
                shapes: [shape],
                filter: CollisionFilter(group: .sceneUnderstanding, mask: .all)
            ))
        }

        if let classification = dominantClassification(for: anchor) {
            entity.components.set(MeshClassificationComponent(classification: classification))
        }
    }

    private func dominantClassification(for anchor: MeshAnchor) -> MeshAnchor.MeshClassification? {
        guard let classifications = anchor.geometry.classifications else { return nil }

        var counts: [UInt8: Int] = [:]
        let buffer = classifications.buffer
        let stride = classifications.stride
        for i in 0..<classifications.count {
            let offset = classifications.offset + i * stride
            let value = buffer.contents().advanced(by: offset).assumingMemoryBound(to: UInt8.self).pointee
            counts[value, default: 0] += 1
        }

        guard let (dominantValue, _) = counts.filter({ $0.key != 0 }).max(by: { $0.value < $1.value }) else {
            return nil
        }

        return MeshAnchor.MeshClassification(rawValue: Int(dominantValue))
    }
}
