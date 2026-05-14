//
//  EntryHelper.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/12/26.
//

import Foundation

enum EntryHelper {

    /// Formats a Double into a clean string, dropping trailing zeros
    static func format(_ number: Double?) -> String {
        guard let number = number else { return "" }
        return String(format: "%g", number)
    }

    /// Calculates the multiplier based on target and base portions
    static func calculateMultiplier(targetPortion: Double, basePortion: Double)
        -> Double
    {
        guard basePortion > 0 else { return 0.0 }
        return targetPortion / basePortion
    }

    /// Scales a macro string by a given multiplier
    static func scale(_ valueString: String, by multiplier: Double) -> String {
        guard !valueString.isEmpty, let value = Double(valueString) else {
            return valueString
        }
        return format(value * multiplier)
    }
}
