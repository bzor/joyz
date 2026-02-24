//
//  ToyDefinition.swift
//  JoyzAVP
//

import Foundation

struct ToyDefinition: Identifiable {
    let id: String
    let displayName: String
    let previewAssetName: String
    let playAssetName: String
    let toyType: ToyType

    enum ToyType {
        case fairy
        case paperAirplane
        case yoyo
    }

    static let allToys: [ToyDefinition] = [
        ToyDefinition(
            id: "fairy",
            displayName: "Fairy",
            previewAssetName: "FairyPreview",
            playAssetName: "Fairy",
            toyType: .fairy
        ),
        ToyDefinition(
            id: "paperAirplane",
            displayName: "Paper Airplane",
            previewAssetName: "PaperAirplanePreview",
            playAssetName: "PaperAirplane",
            toyType: .paperAirplane
        ),
        ToyDefinition(
            id: "yoyo",
            displayName: "Yoyo",
            previewAssetName: "YoyoPreview",
            playAssetName: "Yoyo",
            toyType: .yoyo
        ),
    ]
}
