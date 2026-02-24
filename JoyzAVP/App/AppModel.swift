//
//  AppModel.swift
//  JoyzAVP
//

import SwiftUI
import RealityKit

@Observable
class AppModel {
    enum BoxState {
        case closed
        case opening
        case open
        case closing
    }

    var selectedToyIndex: Int = 0
    let toys: [ToyDefinition] = ToyDefinition.allToys

    var selectedToy: ToyDefinition { toys[selectedToyIndex] }

    var boxState: BoxState = .closed
    var immersiveSpaceIsShown = false
    var activeToyEntity: Entity?
}
