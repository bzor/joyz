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
    func palmPosition(_ chirality: HandAnchor.Chirality) -> SIMD3<Float>? {
        let anchor = chirality == .left ? leftHandAnchor : rightHandAnchor
        guard let anchor, anchor.isTracked,
              let palm = anchor.handSkeleton?.joint(.middleFingerMetacarpal),
              palm.isTracked else { return nil }

        let palmTransform = anchor.originFromAnchorTransform * palm.anchorFromJointTransform
        return SIMD3<Float>(palmTransform.columns.3.x, palmTransform.columns.3.y, palmTransform.columns.3.z)
    }

    /// Get the palm normal (direction the palm faces) in world space.
    /// ARKit hand skeleton: for the metacarpal joint, the -Z axis typically
    /// points outward from the palm when the hand is open and facing up.
    /// We try -Z first, and fall back to Y if that doesn't work well.
    func palmNormal(_ chirality: HandAnchor.Chirality) -> SIMD3<Float>? {
        let anchor = chirality == .left ? leftHandAnchor : rightHandAnchor
        guard let anchor, anchor.isTracked,
              let palm = anchor.handSkeleton?.joint(.middleFingerMetacarpal),
              palm.isTracked else { return nil }

        let palmTransform = anchor.originFromAnchorTransform * palm.anchorFromJointTransform
        // Try -Z axis (common palm-facing direction in ARKit hand skeleton)
        let negZ = -SIMD3<Float>(palmTransform.columns.2.x, palmTransform.columns.2.y, palmTransform.columns.2.z)
        return negZ
    }
}

// MARK: - Singleton access for use in ECS Systems

/// Provides global access to the hand tracking manager from ECS Systems,
/// which cannot receive injected dependencies.
enum HandTrackingManagerProvider {
    @MainActor static var shared: HandTrackingManager?
}
