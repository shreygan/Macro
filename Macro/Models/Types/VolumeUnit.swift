//
//  VolumeUnit.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import Foundation

enum VolumeUnit: String, Codable, CaseIterable {
    case milliliters = "ml"
    case fluidOunces = "fl oz"

    static let millilitersPerFluidOunce = 29.5735

    static var localeDefault: VolumeUnit {
        Locale.current.measurementSystem == .us ? .fluidOunces : .milliliters
    }

    func value(fromML milliliters: Double) -> Double {
        switch self {
        case .milliliters: milliliters
        case .fluidOunces: milliliters / Self.millilitersPerFluidOunce
        }
    }

    func milliliters(from value: Double) -> Double {
        switch self {
        case .milliliters: value
        case .fluidOunces: value * Self.millilitersPerFluidOunce
        }
    }
}
