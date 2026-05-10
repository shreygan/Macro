//
//  RowGroup.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

enum SeparatorStyle {
    case divider
    case spacing(CGFloat)
    case none
}

struct RowGroup<Content: View>: View {
    var separator: SeparatorStyle = .divider
    @ViewBuilder var content: Content

    var body: some View {
        _VariadicView.Tree(RowGroupLayout(separator: separator)) {
            content
        }
    }
}

struct RowGroupLayout: _VariadicView_UnaryViewRoot {
    var separator: SeparatorStyle

    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        VStack(spacing: 0) {
            ForEach(children) { child in
                child

                if child.id != children.last?.id {
                    switch separator {
                    case .divider:
                        Divider()
                            .padding(.leading, 16)
                    case .spacing(let space):
                        Spacer()
                            .frame(height: space)
                    case .none:
                        EmptyView()
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()

        VStack {

            Card {

                RowGroup(separator: .divider) {

                    MealRow(
                        title: "Breakfast",
                        subtitle: "Oatmeal & Eggs",
                        calorie: "320",
                        protein: "20g",
                        carbs: "45g",
                        fat: "8g",
                        fiber: "5g"
                    )

                    ToggleRow(
                        icon: .system("flame.fill", tint: .orange),
                        title: "Include Active Calories",
                        isOn: .constant(true)
                    )

                    NavigationRow(
                        icon: .system("chart.pie.fill", tint: .blue),
                        title: "Macro Breakdown"
                    ) {
                        print("Navigating...")
                    }
                }
            }

            Spacer()

            Card {
                RowGroup(separator: .spacing(8)) {

                    MealRow(
                        title: "Breakfast",
                        subtitle: "Oatmeal & Eggs",
                        calorie: "320",
                        protein: "20g",
                        carbs: "45g",
                        fat: "8g",
                        fiber: "5g"
                    )

                    ToggleRow(
                        icon: .system("flame.fill", tint: .orange),
                        title: "Include Active Calories",
                        isOn: .constant(true)
                    )

                    NavigationRow(
                        icon: .system("chart.pie.fill", tint: .blue),
                        title: "Macro Breakdown"
                    ) {
                        print("Navigating...")
                    }
                }
            }

            Spacer()

            Card(title: "Hello") {
                ButtonRow(
                    title: "Log New Meal",
                    tint: .accentColor,
                    textColor: .white,
                    bottomPadding: 8
                ) {
                    print("Logging meal")
                }

                ButtonRow(
                    title: "Log New Meal",
                    tint: .accentColor,
                    textColor: .white
                ) {
                    print("Logging meal")
                }
            }
        }
    }
}
