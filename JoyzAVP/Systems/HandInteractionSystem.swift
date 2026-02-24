//
//  HandInteractionSystem.swift
//  JoyzAVP
//

import RealityKit
import ARKit
import simd

struct HandInteractionSystem: System {
    static let fairyQuery = EntityQuery(where: .has(FairyBehaviorComponent.self))

    init(scene: RealityKit.Scene) {}

    @MainActor
    func update(context: SceneUpdateContext) {
        guard let handManager = HandTrackingManagerProvider.shared else { return }

        // Update debug markers every frame
        handManager.updateDebugMarkers()

        for entity in context.entities(matching: Self.fairyQuery, updatingSystemWhen: .rendering) {
            guard var fairy = entity.components[FairyBehaviorComponent.self] else { continue }

            let fairyPos = entity.position(relativeTo: nil)
            var handsBelow = false

            for chirality: HandAnchor.Chirality in [.left, .right] {
                guard let palmPos = handManager.palmPosition(chirality),
                      let palmNorm = handManager.palmNormal(chirality) else { continue }

                // Palm must be facing upward (normal has positive Y component)
                let palmFacingUp = palmNorm.y > 0.3  // relaxed threshold

                // Palm must be below the fairy
                let palmBelowFairy = palmPos.y < fairyPos.y

                // Palm must be horizontally close to the fairy
                let horizontalDist = simd_length(
                    SIMD2<Float>(palmPos.x - fairyPos.x, palmPos.z - fairyPos.z)
                )
                let horizontallyClose = horizontalDist < 0.4  // more generous

                // Palm must not be too far below
                let verticalDist = fairyPos.y - palmPos.y
                let verticallyClose = verticalDist < 0.6 && verticalDist > 0

                if palmFacingUp && palmBelowFairy && horizontallyClose && verticallyClose {
                    handsBelow = true
                    break
                }
            }

            if handsBelow != fairy.isBeingHeld {
                print("Fairy held state changed: \(handsBelow)")
            }
            fairy.isBeingHeld = handsBelow
            entity.components[FairyBehaviorComponent.self] = fairy
        }
    }
}
