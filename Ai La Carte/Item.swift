//
//  Item.swift
//  Ai La Carte
//
//  Created by CHENG-TAO CHU on 1/2/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
