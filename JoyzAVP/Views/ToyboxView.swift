//
//  ToyboxView.swift
//  JoyzAVP
//

import SwiftUI
import RealityKit
import UIKit
import ARKit

struct ToyboxView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var sceneReady = false
    @State private var lidHinge: Entity?
    @State private var toyboxRoot: Entity?
    @State private var lastBoxState: AppModel.BoxState = .closed
    @State private var didSendTransform = false

    var body: some View {
        ZStack {
            // Pure SwiftUI splash — renders on the very first frame
            if !sceneReady {
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Joyz")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Loading toybox…")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(30)
                .glassBackgroundEffect()
            }

            // RealityView — hidden until make closure finishes
            RealityView { content, attachments in
                let boxSize: Float = 0.28
                let bodyInset: Float = 0.015
                let lidW = boxSize - bodyInset

                var material = SimpleMaterial()
                material.color = .init(
                    tint: UIColor(red: 0.85, green: 0.12, blue: 0.1, alpha: 1.0),
                    texture: nil
                )
                material.roughness = .float(0.35)
                material.metallic = .float(0.0)

                // Root entity — shift toybox down so base aligns to bottom of volume
                let root = Entity()
                root.name = "ToyboxRoot"
                root.position = SIMD3(0, -0.12, 0)
                content.add(root)
                toyboxRoot = root

                // Box body
                let bodyMesh = MeshResource.generateBox(
                    width: lidW, height: boxSize, depth: lidW,
                    cornerRadius: 0.012
                )
                let body = ModelEntity(mesh: bodyMesh, materials: [material])
                body.components.set(GroundingShadowComponent(castsShadow: true))
                root.addChild(body)

                // Thick bottom slab
                let bottomH: Float = 0.02
                let bottomMesh = MeshResource.generateBox(
                    width: boxSize, height: bottomH, depth: boxSize,
                    cornerRadius: 0.008
                )
                let bottom = ModelEntity(mesh: bottomMesh, materials: [material])
                bottom.position = SIMD3(0, -boxSize / 2 + bottomH / 2, 0)
                root.addChild(bottom)

                // Lid — hinged at back edge
                let lidH: Float = 0.036
                let lidMesh = MeshResource.generateBox(
                    width: lidW, height: lidH, depth: lidW,
                    cornerRadius: 0.008
                )
                let lid = ModelEntity(mesh: lidMesh, materials: [material])
                lid.position = SIMD3(0, lidH / 2, lidW / 2)

                // Hinge pivot at the top-back edge of the box
                let hinge = Entity()
                hinge.name = "LidHinge"
                hinge.position = SIMD3(0, boxSize / 2, -lidW / 2)
                hinge.addChild(lid)
                root.addChild(hinge)
                lidHinge = hinge

                // UI on front face
                if let panel = attachments.entity(for: "frontUI") {
                    panel.position = SIMD3(0, 0, boxSize / 2 + 0.001)
                    root.addChild(panel)
                }

                sceneReady = true
            } update: { content, _ in
                // Convert toybox transform to immersive space when opening
                if let root = toyboxRoot,
                   appModel.boxState == .open,
                   !didSendTransform,
                   !appModel.fairyHasLaunched {
                    let affine = content.transform(from: root, to: .immersiveSpace)
                    appModel.immersiveSpaceFromToybox = simd_float4x4(affine)
                    appModel.needsToyboxConversion = true
                    didSendTransform = true
                    print("[ToyboxView] Sent toybox transform to immersive space")
                }
                if appModel.boxState == .closed {
                    didSendTransform = false
                }

                guard let hinge = lidHinge else { return }
                let state = appModel.boxState

                // Only animate on state change
                guard state != lastBoxState else { return }
                lastBoxState = state

                if state == .opening || state == .open {
                    // Spring open: overshoot then settle
                    var overshoot = hinge.transform
                    overshoot.rotation = simd_quatf(angle: -.pi * 0.68, axis: SIMD3(1, 0, 0))
                    hinge.move(to: overshoot, relativeTo: hinge.parent, duration: 0.35, timingFunction: .easeIn)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        var settle = hinge.transform
                        settle.rotation = simd_quatf(angle: -.pi * 0.58, axis: SIMD3(1, 0, 0))
                        hinge.move(to: settle, relativeTo: hinge.parent, duration: 0.3, timingFunction: .easeOut)
                    }
                } else if state == .closing || state == .closed {
                    // Spring closed: overshoot past closed then settle
                    var overshoot = hinge.transform
                    overshoot.rotation = simd_quatf(angle: .pi * 0.03, axis: SIMD3(1, 0, 0))
                    hinge.move(to: overshoot, relativeTo: hinge.parent, duration: 0.3, timingFunction: .easeIn)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        var settle = hinge.transform
                        settle.rotation = simd_quatf.init(ix: 0, iy: 0, iz: 0, r: 1)
                        hinge.move(to: settle, relativeTo: hinge.parent, duration: 0.2, timingFunction: .easeOut)
                    }
                }
            } attachments: {
                Attachment(id: "frontUI") {
                    VStack(spacing: 12) {
                        Text(appModel.selectedToy.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        HStack(spacing: 40) {
                            Button {
                                withAnimation {
                                    appModel.selectedToyIndex = max(0, appModel.selectedToyIndex - 1)
                                }
                            } label: {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title)
                            }
                            .disabled(appModel.selectedToyIndex == 0)

                            Button {
                                withAnimation {
                                    appModel.selectedToyIndex = min(appModel.toys.count - 1, appModel.selectedToyIndex + 1)
                                }
                            } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title)
                            }
                            .disabled(appModel.selectedToyIndex == appModel.toys.count - 1)
                        }

                        Button {
                            Task {
                                if appModel.boxState == .open {
                                    await closeBox()
                                } else {
                                    await openBox()
                                }
                            }
                        } label: {
                            Text(appModel.boxState == .open ? "Close" : "Open")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(width: 120)
                        }
                        .disabled(appModel.boxState == .opening || appModel.boxState == .closing)
                    }
                    .padding()
                    .glassBackgroundEffect()
                }
            }
            .opacity(sceneReady ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.3), value: sceneReady)
        .task {
            let session = ARKitSession()
            let handAuth = await session.requestAuthorization(for: [.handTracking])
            let worldAuth = await session.requestAuthorization(for: [.worldSensing])
            print("[Auth] Hand tracking: \(handAuth)")
            print("[Auth] World sensing: \(worldAuth)")
        }
    }

    private func openBox() async {
        appModel.boxState = .opening
        let result = await openImmersiveSpace(id: "PlaySpace")
        switch result {
        case .opened:
            appModel.immersiveSpaceIsShown = true
            appModel.boxState = .open
        case .error, .userCancelled:
            appModel.boxState = .closed
        @unknown default:
            appModel.boxState = .closed
        }
    }

    private func closeBox() async {
        appModel.boxState = .closing
        await dismissImmersiveSpace()
        appModel.immersiveSpaceIsShown = false
        appModel.boxState = .closed
        // Reset for next open
        appModel.fairyHasLaunched = false
        appModel.needsToyboxConversion = false
        appModel.immersiveSpaceFromToybox = nil
        appModel.toyboxConvertedToScene = false
        didSendTransform = false
    }
}

#Preview(windowStyle: .volumetric) {
    ToyboxView()
        .environment(AppModel())
}
