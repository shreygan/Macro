//
//  DrinkSymbol.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import SwiftUI

enum DrinkSymbol {
    struct Option: Hashable {
        let symbol: String
        let label: String
    }

    struct Group: Identifiable {
        let title: String
        let options: [Option]

        var id: String { title }
    }

    static let custom: Set<String> = [
        "sodacan.fill",
        "waterglass.fill",
        "tumbler.handle.fill",
        "bottle.fliplid.fill",
        "bottle.loopcap.fill",
        "bottle.insulated.fill",
        "bottle.squeeze.fill",
        "shakerbottle.fill",
        "carton.fill",
        "juicebox.fill",
        "bottle.soda.fill",
        "bottle.beer.fill",
        "cup.hot.lid.fill",
        "cup.dome.straw.fill",
        "cup.boba.fill",
        "cocktailglass.fill",
        "beerstein.fill",
        "rocksglass.ice.fill",
        "champagneflute.fill",
        "tropicaldrink.fill",
        "stickpack.fill",
        "pitcher.fill",
        "coconut.straw.fill",
        "citrusslice.fill",
        "sodacan.slim.fill",
        "shotglass.fill",
        "coffeebean.fill",
        "teapot.fill",
        "jug.gallon.fill",
        "blender.fill",
        "highballglass.fill",
    ]

    static let groups: [Group] = [
        Group(title: String(localized: "Water"), options: [
            option("drop.fill", "Water Drop"),
            option("drop.halffull", "Half Drop"),
            option("waterbottle.fill", "Water Bottle"),
            option("waterglass.fill", "Glass of Water"),
            option("pitcher.fill", "Pitcher"),
            option("jug.gallon.fill", "Gallon Jug"),
            option("stickpack.fill", "Electrolyte Packet"),
            option("cube.fill", "Ice Cube"),
            option("snowflake", "Snowflake"),
        ]),
        Group(title: String(localized: "Bottles"), options: [
            option("tumbler.handle.fill", "Tumbler with Handle"),
            option("bottle.fliplid.fill", "Bottle with Flip Lid"),
            option("bottle.loopcap.fill", "Bottle with Loop Cap"),
            option("bottle.insulated.fill", "Insulated Bottle"),
            option("bottle.squeeze.fill", "Squeeze Bottle"),
            option("shakerbottle.fill", "Shaker Bottle"),
        ]),
        Group(title: String(localized: "Coffee & Tea"), options: [
            option("mug.fill", "Mug"),
            option("cup.and.saucer.fill", "Cup and Saucer"),
            option("cup.and.heat.waves.fill", "Hot Cup"),
            option("cup.hot.lid.fill", "Coffee Cup with Lid"),
            option("coffeebean.fill", "Coffee Bean"),
            option("cup.dome.straw.fill", "Iced Drink with Dome Lid"),
            option("cup.boba.fill", "Bubble Tea"),
            option("teapot.fill", "Teapot"),
            option("leaf.fill", "Tea Leaf"),
        ]),
        Group(title: String(localized: "Soda & Juice"), options: [
            option("bubbles.and.sparkles.fill", "Sparkling"),
            option("sodacan.fill", "Soda Can"),
            option("sodacan.slim.fill", "Slim Can"),
            option("bottle.soda.fill", "Soda Bottle"),
            option("takeoutbag.and.cup.and.straw.fill", "Takeout Drink"),
            option("carton.fill", "Carton"),
            option("juicebox.fill", "Juice Box"),
            option("blender.fill", "Blender"),
            option("coconut.straw.fill", "Coconut"),
            option("citrusslice.fill", "Citrus Slice"),
        ]),
        Group(title: String(localized: "Alcohol"), options: [
            option("wineglass.fill", "Wine Glass"),
            option("champagneflute.fill", "Champagne Flute"),
            option("cocktailglass.fill", "Cocktail Glass"),
            option("tropicaldrink.fill", "Tropical Drink"),
            option("rocksglass.ice.fill", "Rocks Glass"),
            option("highballglass.fill", "Highball Glass"),
            option("shotglass.fill", "Shot Glass"),
            option("bottle.beer.fill", "Beer Bottle"),
            option("beerstein.fill", "Beer Mug"),
        ]),
        Group(title: String(localized: "Other"), options: [
            option("flask.fill", "Flask"),
            option("bolt.fill", "Lightning Bolt"),
            option("birthday.cake.fill", "Birthday Cake"),
            option("party.popper.fill", "Party Popper"),
            option("dumbbell.fill", "Dumbbell"),
            option("figure.run", "Runner"),
            option("pills.fill", "Pills"),
            option("brain.fill", "Brain"),
            option("heart.fill", "Heart"),
            option("sparkles", "Sparkles"),
            option("star.fill", "Star"),
            option("sun.max.fill", "Sun"),
            option("moon.fill", "Moon"),
            option("moon.zzz.fill", "Sleep"),
        ]),
    ]

    private static let labels = Dictionary(
        groups.flatMap(\.options).map { ($0.symbol, $0.label) },
        uniquingKeysWith: { first, _ in first }
    )

    static func label(for symbol: String) -> String? {
        labels[symbol]
    }

    static func contains(_ symbol: String) -> Bool {
        labels[symbol] != nil
    }

    static func group(containing symbol: String) -> Group? {
        groups.first { $0.options.contains { $0.symbol == symbol } }
    }

    private static func option(_ symbol: String, _ label: String.LocalizationValue) -> Option {
        Option(symbol: symbol, label: String(localized: label))
    }
}

extension Image {
    init(symbol name: String) {
        if DrinkSymbol.custom.contains(name) || AppSymbols.assetSymbols.contains(name) {
            self.init(name)
        } else {
            self.init(systemName: name)
        }
    }
}

extension FoodItem {
    var rowSymbolName: String {
        type == .drink ? drinkSymbol : type.appSymbol.rawValue
    }
}
