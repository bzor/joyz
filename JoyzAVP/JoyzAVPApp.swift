//
//  JoyzAVPApp.swift
//  JoyzAVP
//
//  Created by k.c. Austin on 2/23/26.
//

import SwiftUI

@main
struct JoyzAVPApp: App {
    @State private var appModel = AppModel()

    init() {
        SystemRegistration.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            ToyboxView()
                .environment(appModel)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.4, height: 0.6, depth: 0.6, in: .meters)

        ImmersiveSpace(id: "PlaySpace") {
            PlaySpaceView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
