//
//  NameSuggestionPanel.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/22/26.
//

import SwiftData
import SwiftUI

struct NameSuggestionPanel: View {
    let matches: [NameSuggestions.Match]
    var onSelect: (NameSuggestions.Match) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Fill From")
                .font(.detailEmphasis)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 2)

            ForEach(Array(matches.enumerated()), id: \.element.food.id) { index, match in
                Button {
                    onSelect(match)
                } label: {
                    CompactMealRow(food: match.food, note: match.aliasNote)
                }
                .buttonStyle(SuggestionRowStyle())
                .transition(.opacity)

                if index < matches.count - 1 {
                    Divider()
                        .padding(.leading, 42)
                }
            }
        }
        .padding(.bottom, 4)
        .clipShape(.rect(cornerRadius: 24))
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }
}

private struct SuggestionRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.highlightFill)
                        .padding(.horizontal, 6)
                }
            }
    }
}

struct NameSuggestionAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

extension View {
    func nameSuggestionAnchor() -> some View {
        anchorPreference(key: NameSuggestionAnchorKey.self, value: .bounds) { $0 }
    }

    func nameSuggestionPanel(
        _ matches: [NameSuggestions.Match],
        onSelect: @escaping (NameSuggestions.Match) -> Void
    ) -> some View {
        overlayPreferenceValue(NameSuggestionAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor, !matches.isEmpty {
                    let rect = proxy[anchor]
                    NameSuggestionPanel(matches: matches, onSelect: onSelect)
                        .frame(width: rect.width)
                        .offset(x: rect.minX, y: rect.maxY)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .animation(.snappy(duration: 0.25), value: matches.map(\.food.id))
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    let cola = FoodItem(name: "Cola", type: .drink, servingSize: 1, servingWeight: 355, servingWeightUnit: "ml", isAIEstimated: false, calories: 140, protein: 0, carbs: 39, fat: 0, fiber: 0, isCustomDefaultServing: false)
    let cherry = FoodItem(name: "Cherry Cola", type: .drink, servingSize: 1, servingWeight: 355, servingWeightUnit: "ml", isAIEstimated: false, calories: 150, protein: 0, carbs: 42, fat: 0, fiber: 0, isCustomDefaultServing: false)
    let zero = FoodItem(name: "Cola Zero Vanilla", type: .drink, servingSize: 1, servingWeight: 355, servingWeightUnit: "ml", isAIEstimated: false, calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, isCustomDefaultServing: false)
    [cola, cherry, zero].forEach { container.mainContext.insert($0) }

    return ZStack(alignment: .top) {
        Color.background.ignoresSafeArea()

        VStack {
            Card {
                RowGroup(.divider) {
                    FullWidthInputRow(placeholder: "Drink Name", text: .constant("Coke"))
                        .nameSuggestionAnchor()
                    ToggleRow(title: "Pin to Hydration Card", isOn: .constant(true))
                }
            }
            Card {
                ToggleRow(title: "Caffeine", isOn: .constant(false))
            }
            .padding(.top)
        }
        .padding()
        .nameSuggestionPanel(
            [
                NameSuggestions.Match(food: cola, alias: "Coke"),
                NameSuggestions.Match(food: cherry),
                NameSuggestions.Match(food: zero),
            ]
        ) { _ in }
    }
    .modelContainer(container)
}
