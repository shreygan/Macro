//
//  Card.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct Card<Content: View, MenuContent: View>: View {
    var title: String?
    var cornerRadius: CGFloat
    var tintColor: Color

    var content: Content
    var menuItems: MenuContent

    var body: some View {
        let cardVisuals = VStack(spacing: 0) {
            if let title = title {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            content
        }
        .frame(maxWidth: .infinity)
        .glassEffect(
            .regular.tint(tintColor.opacity(0.7)),
            in: .rect(cornerRadius: cornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 10,
                    x: 0,
                    y: 4
                )
        )

        Group {
            if MenuContent.self != EmptyView.self {
                cardVisuals
                    .contentShape(
                        .contextMenuPreview,
                        RoundedRectangle(
                            cornerRadius: cornerRadius,
                            style: .continuous
                        )
                    )
                    .contextMenu {
                        menuItems
                    }
            } else {
                cardVisuals
            }
        }
    }
}

extension Card where MenuContent == EmptyView {
    init(
        title: String? = nil,
        cornerRadius: CGFloat = 24.0,
        tintColor: Color = Color(white: 0.96),
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.content = content()
        self.menuItems = EmptyView()
    }
}

extension Card {
    init(
        title: String? = nil,
        cornerRadius: CGFloat = 24.0,
        tintColor: Color = Color(white: 0.96),
        @ViewBuilder content: () -> Content,
        @ViewBuilder menuItems: () -> MenuContent
    ) {
        self.title = title
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.content = content()
        self.menuItems = menuItems()
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()

        VStack {
            Card(title: "MEAL PLAN") {

                Text(
                    "Press and hold anywhere on this card to open the options menu!"
                )
                .padding()

            } menuItems: {

                Button {
                    print("Edit tapped")
                } label: {
                    Label("Edit Meal", systemImage: "pencil")
                }

                Button {
                    print("Duplicate tapped")
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }

                Divider()

                Button(role: .destructive) {
                    print("Delete tapped")
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            Card {
                ToggleRow(
                    title: "Track Macros",
                    isOn: .constant(false)
                )

                Divider().padding(.leading, 16)

                TextInputRow(
                    title: "Protein",
                    titleExtension: "(g)",
                    placeholder: "0",
                    text: .constant("180"),
                    keyboardType: .numberPad
                )

                Divider().padding(.leading, 16)

                TextInputRow(
                    icon: .custom(Image("Fiber")),
                    title: "Fiber",
                    titleExtension: "(g)",
                    placeholder: "-",
                    text: .constant(""),
                    keyboardType: .numberPad
                )

                Divider().padding(.leading, 16)

                NavigationRow(
                    icon: .system("chart.bar"),
                    title: "Macro History",
                ) {
                    print("History row tapped!")
                }
            }
        }
    }
}
