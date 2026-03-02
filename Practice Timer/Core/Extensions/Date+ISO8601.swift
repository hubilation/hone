//
//  Date+ISO8601.swift
//  Practice Timer
//
//  Created by Claude on 3/2/26.
//

import Foundation

extension Date {
    func toISO8601String() -> String {
        return ISO8601DateFormatter().string(from: self)
    }

    init?(iso8601String: String) {
        guard let date = ISO8601DateFormatter().date(from: iso8601String) else {
            return nil
        }
        self = date
    }
}
