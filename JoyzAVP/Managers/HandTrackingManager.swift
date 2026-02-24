//
//  HandTrackingManager.swift
//  JoyzAVP
//

import ARKit
import RealityKit
import UIKit
import simd

@Observable
@MainActor
class HandTrackingManager {
    var leftHandAnchor: HandAnchor?
    var rightHandAnchor: HandAnchor?

    // Debug visualization entities
    var leftPalmMarker: Entity?
    var rightPalmMarker: Entity?
    var leftNormalMarker: Entity?
    var rightNormalMarker: Entity?

    private var handUpdateCount = 0

    func processHandUpdates(provider: HandTrackingProvider) async {
        print("[Hands] Starting to process hand updates...")
        for await update in provider.anchorUpdates {
            handUpdateCount += 1
            if handUpdateCount <= 5 || handUpdateCount % 100 == 0 {
                print("[Hands] Update #\(handUpdateCount): \(update.anchor.chirality) \(update.event) tracked=\(update.anchor.isTracked)")
            }
            switch update.anchor.chirality {
            case .left:
                leftHandAnchor = update.event == .removed ? nil : update.anchor
            case .right:
                rightHandAnchor = update.event == .removed ? nil : update.anchor
            }
        }
        print("[Hands] Hand update stream ended!")
    }

    /// Create debug marker spheres for palm positions and normal direction arrows.
    func createDebugMarkers(parent: Entity) {
        let palmMesh = MeshResource.generateSphere(radius: 0.02)
        var palmMat = UnlitMaterial()
        palmMat.color = .init(tint: .green)

        let normalMesh = MeshResource.generateSphere(radius: 0.01)
        var normalMat = UnlitMaterial()
        normalMat.color = .init(tint: .cyan)

        let lp = ModelEntity(mesh: palmMesh, materials: [palmMat])
        lp.name = "LeftPalmDebug"
        parent.addChild(lp)
        leftPalmMarker = lp

        let rp = ModelEntity(mesh: palmMesh, materials: [palmMat])
        rp.name = "RightPalmDebug"
        parent.addChild(rp)
        rightPalmMarker = rp

        let ln = ModelEntity(mesh: normalMesh, materials: [normalMat])
        ln.name = "LeftNormalDebug"
        parent.addChild(ln)
        leftNormalMarker = ln

        let rn = ModelEntity(mesh: normalMesh, materials: [normalMat])
        rn.name = "RightNormalDebug"
        parent.addChild(rn)
        rightNormalMarker = rn
    }

    /// Update debug marker positions each frame. Call from the hand interaction system.
    func updateDebugMarkers() {
        if let pos = palmPosition(.left) {
            leftPalmMarker?.isEnabled = true
            leftPalmMarker?.setPosition(pos, relativeTo: nil)
            if let norm = palmNormal(.left) {
                leftNormalMarker?.isEnabled = true
                leftNormalMarker?.setPosition(pos + norm * 0.08, relativeTo: nil)
            }
        } else {
            leftPalmMarker?.isEnabled = false
            leftNormalMarker?.isEnabled = false
        }

        if let pos = palmPosition(.right) {
            rightPalmMarker?.isEnabled = true
            rightPalmMarker?.setPosition(pos, relativeTo: nil)
            if let norm = palmNormal(.right) {
                rightNormalMarker?.isEnabled = true
                rightNormalMarker?.setPosition(pos + norm * 0.08, relativeTo: nil)
            }
        } else {
            rightPalmMarker?.isEnabled = false
            rightNormalMarker?.isEnabled = false
        }
    }

    /// Get the palm center position in world space for a given hand.
    /// Midpoint between middleFingerMetacarpal (wrist end) and middleFingerKnuckle (MCP joint)
    /// to approximate the true center of the palm.
    func palmPosition(_ chirality: HandAnchor.Chirality) -> SIMD3<Float>? {
        let anchor = chirality == .left ? leftHandAnchor : rightHandAnchor
        guard let anchor, anchor.isTracked,
              let metacarpal = anchor.handSkeleton?.joint(.middleFingerMetacarpal),
              let knuckle = anchor.handSkeleton?.joint(.middleFingerKnuckle),
              metacarpal.isTracked, knuckle.isTracked else { return nil }

        let metacarpalPos = anchor.originFromAnchorTransform * metacarpal.anchorFromJointTransform
        let knucklePos = anchor.originFromAnchorTransform * knuckle.anchorFromJointTransform

        let a = SIMD3<Float>(metacarpalPos.columns.3.x, metacarpalPos.columns.3.y, metacarpalPos.columns.3.z)
        let b = SIMD3<Float>(knucklePos.columns.3.x, knucklePos.columns.3.y, knucklePos.columns.3.z)
        return (a + b) * 0.5
    }

    /// Get the palm normal (direction the palm faces) in world space.
    /// ARKit mirrors joint coordinate frames between hands — -Y points out
    /// from the palm on the right hand, +Y on the left.
    func palmNormal(_ chirality: HandAnchor.Chirality) -> SIMD3<Float>? {
        let anchor = chirality == .left ? leftHandAnchor : rightHandAnchor
        guard let anchor, anchor.isTracked,
              let palm = anchor.handSkeleton?.joint(.middleFingerMetacarpal),
              palm.isTracked else { return nil }

        let palmTransform = anchor.originFromAnchorTransform * palm.anchorFromJointTransform
        let yAxis = SIMD3<Float>(palmTransform.columns.1.x, palmTransform.columns.1.y, palmTransform.columns.1.z)
        return chirality == .left ? yAxis : -yAxis
    }
}

// MARK: - Singleton access for use in ECS Systems

/// Provides global access to the hand tracking manager from ECS Systems,
/// which cannot receive injected dependencies.
enum HandTrackingManagerProvider {
    @MainActor static var shared: HandTrackingManager?
}

/// Provides global access to the world tracking provider for head position queries.
enum WorldTrackingManagerProvider {
    @MainActor static var shared: WorldTrackingProvider?
}
