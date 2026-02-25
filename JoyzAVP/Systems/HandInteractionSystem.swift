//
//  HandInteractionSystem.swift
//  JoyzAVP
//
//  Detects hand proximity to the fairy using closest distance
//  to any palm/finger joint. No palm direction check needed.
//  Exaggerates spinning when hands are close.
//

import RealityKit
import ARKit
import simd

struct HandInteractionSystem: System {
    static let fairyQuery = EntityQuery(where: .has(FairyBehaviorComponent.self))

    // Distance thresholds
    private static let heldThreshold: Float = 0.15    // closer than this = held
    private static let influenceRange: Float = 0.5    // proximity influence starts here

    // Spin boost when held
    private static let heldSpinMultiplier: Float = 4.0

    init(scene: RealityKit.Scene) {}

    @MainActor
    func update(context: SceneUpdateContext) {
        guard let handManager = HandTrackingManagerProvider.shared else { return }

        // Update debug markers every frame
        handManager.updateDebugMarkers()

        // Gather all joint positions from both hands
        var allPositions: [SIMD3<Float>] = []
        allPositions.append(contentsOf: handManager.allJointPositions(.left))
        allPositions.append(contentsOf: handManager.allJointPositions(.right))

        for entity in context.entities(matching: Self.fairyQuery, updatingSystemWhen: .rendering) {
            guard var fairy = entity.components[FairyBehaviorComponent.self] else { continue }

            let fairyPos = entity.position(relativeTo: nil)

            // Find closest joint distance
            var closestDist: Float = 10.0
            for jointPos in allPositions {
                let dist = simd_length(jointPos - fairyPos)
                if dist < closestDist {
                    closestDist = dist
                }
            }

            fairy.handDistance = closestDist

            let wasHeld = fairy.isBeingHeld
            fairy.isBeingHeld = closestDist < Self.heldThreshold

            if wasHeld != fairy.isBeingHeld {
                print("Fairy held state changed: \(fairy.isBeingHeld) (distance: \(closestDist))")
            }

            // Exaggerate spin based on proximity
            // At influenceRange: normal spin. At 0: heldSpinMultiplier × spin.
            if closestDist < Self.influenceRange {
                let proximity = 1.0 - (closestDist / Self.influenceRange)  // 0 at range, 1 at touch
                let spinBoost = 1.0 + (Self.heldSpinMultiplier - 1.0) * proximity
                fairy.spinRate = 1.2 * spinBoost
            } else {
                fairy.spinRate = 1.2
            }

            entity.components[FairyBehaviorComponent.self] = fairy
        }
    }
}
