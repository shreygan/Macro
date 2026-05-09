//
//  MealRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct MealRow: View {
    var title: String
    var subtitle: String

    var calorie: String
    var protein: String? = nil
    var carbs: String? = nil
    var fat: String? = nil
    var fiber: String? = nil

    // If you provide an action, it becomes clickable and shows the chevron!
    var action: (() -> Void)? = nil

    var body: some View {
        let rowContent = HStack(alignment: .center, spacing: 12) {

            VStack(alignment: .leading, spacing: 2) {

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.tertiary)
                }

                HStack(spacing: 4) {
                    macroStat(imageName: "Calorie", text: calorie)
                    if let protein {
                        macroStat(imageName: "Protein", text: protein)
                    }
                    if let carbs {
                        macroStat(imageName: "Carbs", text: carbs)
                    }
                    if let fat {
                        macroStat(imageName: "Fat", text: fat)
                    }
                    if let fiber {
                        macroStat(imageName: "Fiber", text: fiber)
                    }
                }
            }

            Spacer(minLength: 16)

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)

        if let action = action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private func macroStat(imageName: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .scaleEffect(1.5)
                .frame(width: 8, height: 14)

            Text(text)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.primary)
                .padding(.trailing, 5)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()

        Card {

            MealRow(
                title: "Grilled Chicken Salad",
                subtitle: "Sweetgreen, 1 bowl",
                calorie: "450",
                protein: "42",
                carbs: "12",
                fat: "18",
                fiber: "6"
            )

            Divider().padding(.leading, 16)

            MealRow(
                title: "Chips",
                subtitle: "Lays, 11 chips (50g)",
                calorie: "240",
                protein: "48",
                carbs: "6",
                fat: "2",
            ) {
                print("Navigating to meal details...")
            }
        }
    }
}
