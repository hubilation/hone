//
//  String+ISO8601.swift
//  Hone
//
//  Created by Claude on 3/5/26.
//

import Foundation

extension String {
    /// Converts ISO 8601 string to Date
    /// Supports both with and without fractional seconds
    func toDate() -> Date? {
        return Date(iso8601String: self)
    }
}
