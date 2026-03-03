//
//  ActivityCategory.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import Foundation
import SwiftUI

// Category values must match web app exactly for cross-platform sync. Coordinate any changes with web team.
enum ActivityCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case instrument = "Instrument"
    case piece = "Piece"
    case technique = "Technique"
    case theory = "Theory"
    case warmup = "Warm-up"
    case other = "Other"

    // For Identifiable conformance (SwiftUI Picker compatibility)
    var id: String {
        rawValue
    }

    // SF Symbol name for visual representation
    var icon: String {
        switch self {
        case .instrument:
            return "guitars"
        case .piece:
            return "music.note.list"
        case .technique:
            return "hand.raised.fill"
        case .theory:
            return "book.closed.fill"
        case .warmup:
            return "flame.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
}
