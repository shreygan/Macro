//
//  DrinkTint.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import SwiftUI

enum DrinkTint: String, CaseIterable, Codable {
    case red
    case orange
    case amber
    case yellow
    case lime
    case green
    case mint
    case teal
    case blue
    case navy
    case indigo
    case purple
    case lavender
    case pink
    case wine
    case latte
    case brown
    case darkRoast
    case gray
    case graphite

    var color: Color {
        switch self {
        case .red: Color(uiColor: .systemRed)
        case .orange: Color(uiColor: .systemOrange)
        case .amber: Color(red: 0.93, green: 0.62, blue: 0.04)
        case .yellow: Color(uiColor: .systemYellow)
        case .lime: Color(red: 0.55, green: 0.76, blue: 0.16)
        case .green: Color(uiColor: .systemGreen)
        case .mint: Color(red: 0.30, green: 0.82, blue: 0.62)
        case .teal: Color(uiColor: .systemTeal)
        case .blue: Color(uiColor: .systemBlue)
        case .navy: Color(red: 0.12, green: 0.24, blue: 0.50)
        case .indigo: Color(uiColor: .systemIndigo)
        case .purple: Color(uiColor: .systemPurple)
        case .lavender: Color(red: 0.64, green: 0.53, blue: 0.86)
        case .pink: Color(red: 0.95, green: 0.42, blue: 0.62)
        case .wine: Color(red: 0.55, green: 0.12, blue: 0.24)
        case .latte: Color(red: 0.83, green: 0.69, blue: 0.52)
        case .brown: Color(uiColor: .systemBrown)
        case .darkRoast: Color(red: 0.36, green: 0.23, blue: 0.16)
        case .gray: Color.solidTertiaryText
        case .graphite: Color(red: 0.23, green: 0.23, blue: 0.24)
        }
    }

    var name: String {
        switch self {
        case .red: String(localized: "Red")
        case .orange: String(localized: "Orange")
        case .amber: String(localized: "Amber")
        case .yellow: String(localized: "Yellow")
        case .lime: String(localized: "Lime")
        case .green: String(localized: "Green")
        case .mint: String(localized: "Mint")
        case .teal: String(localized: "Teal")
        case .blue: String(localized: "Blue")
        case .navy: String(localized: "Navy")
        case .indigo: String(localized: "Indigo")
        case .purple: String(localized: "Purple")
        case .lavender: String(localized: "Lavender")
        case .pink: String(localized: "Pink")
        case .wine: String(localized: "Wine")
        case .latte: String(localized: "Latte")
        case .brown: String(localized: "Brown")
        case .darkRoast: String(localized: "Dark Roast")
        case .gray: String(localized: "Gray")
        case .graphite: String(localized: "Graphite")
        }
    }
}

extension FoodItem {
    var drinkTint: DrinkTint {
        tintRawValue.flatMap(DrinkTint.init(rawValue:)) ?? DrinkFormState.defaultTint
    }

    var drinkSymbol: String {
        symbol.flatMap { DrinkSymbol.contains($0) ? $0 : nil } ?? DrinkFormState.defaultSymbol
    }

    var rowIcon: RowIcon {
        type == .drink
            ? .customSymbol(drinkSymbol, tint: drinkTint.color)
            : .customSymbol(rowSymbolName)
    }

    var sortedDrinkSizes: [DrinkSize] {
        (drinkSizes ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    var defaultDrinkSize: DrinkSize? {
        sortedDrinkSizes.first(where: \.isDefault) ?? sortedDrinkSizes.first
    }

    var isLoggableDrink: Bool {
        type == .drink && (servingVolumeML ?? 0) > 0
    }
}

#Preview("Drink Tints") {
    let symbols = ["waterbottle.fill", "mug.fill", "carton.fill"]

    ScrollView {
        Card {
            LazyVGrid(columns: [GridItem(), GridItem()], alignment: .leading, spacing: 10) {
                ForEach(DrinkTint.allCases, id: \.self) { tint in
                    HStack(spacing: 8) {
                        Image(symbol: "cup.hot.lid.fill")
                            .font(.rowIcon)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(tint.color))

                        ForEach(symbols, id: \.self) { symbol in
                            Image(symbol: symbol)
                                .font(.smallIcon)
                                .foregroundStyle(tint.color)
                                .frame(width: 14)
                        }

                        DrinkFillGlyph(symbol: "waterbottle.fill", tint: tint.color, fraction: 0.5, animatesLevel: false)
                            .scaleEffect(0.15)
                            .frame(width: 26, height: 32)

                        Text(tint.name)
                            .font(.detail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
        }
        .padding()
    }
    .background(Color.background)
}
