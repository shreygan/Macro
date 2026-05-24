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

struct RowGroup<Content: View, BottomContent: View>: View {
    var separator: SeparatorStyle = .divider
    @ViewBuilder var content: Content
    @ViewBuilder var bottomContent: BottomContent

    init(
        _ separator: SeparatorStyle = .divider,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottomContent: () -> BottomContent
    ) {
        self.separator = separator
        self.content = content()
        self.bottomContent = bottomContent()
    }

    var body: some View {
        _VariadicView.Tree(RowGroupLayout(separator: separator)) {
            content
        }

        bottomContent
    }
}

extension RowGroup where BottomContent == EmptyView {
    init(
        _ separator: SeparatorStyle = .divider,
        @ViewBuilder content: () -> Content
    ) {
        self.separator = separator
        self.content = content()
        self.bottomContent = EmptyView()
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
                            .padding(.horizontal, 16)
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

                RowGroup(.divider) {
                    ToggleRow(
                        icon: .customSymbol("flame.fill", tint: .orange),
                        title: "Include Active Calories",
                        isOn: .constant(true)
                    )

                    NavigationRow(
                        icon: .customSymbol("chart.pie.fill", tint: .blue),
                        title: "Macro Breakdown"
                    )
                }
            }

            Spacer()

            Card {
                RowGroup(.spacing(8)) {
                    ToggleRow(
                        icon: .customSymbol("flame.fill", tint: .orange),
                        title: "Include Active Calories",
                        isOn: .constant(true)
                    )

                    NavigationRow(
                        icon: .customSymbol("chart.pie.fill", tint: .blue),
                        title: "Macro Breakdown"
                    )
                }
            }

            Spacer()

            Card("Hello") {
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
