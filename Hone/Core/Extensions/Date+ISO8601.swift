//
//  Date+ISO8601.swift
//  Hone
//
//  Created by Claude on 3/2/26.
//

import Foundation

extension Date {
    func toISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }

    init?(iso8601String: String) {
        let formatter = ISO8601DateFormatter()
        // Support both with and without fractional seconds
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: iso8601String) {
            self = date
            return
        }

        // Fallback: try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso8601String) else {
            return nil
        }
        self = date
    }
}
