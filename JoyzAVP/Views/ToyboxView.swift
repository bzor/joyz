//
//  ToyboxView.swift
//  JoyzAVP
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ToyboxView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack {
            RealityView { content in
                // Placeholder: load the default scene for now
                // Will be replaced with toybox model + toy preview in Phase 6
                if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
                    content.add(scene)
                }
            }

            VStack(spacing: 16) {
                // Toy name
                Text(appModel.selectedToy.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                // Navigation arrows
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

                // Open / Close button
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
        .task {
            // Request ARKit permissions at app launch
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
    }
}

#Preview(windowStyle: .volumetric) {
    ToyboxView()
        .environment(AppModel())
}
