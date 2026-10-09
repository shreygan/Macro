//
//  Card.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct Card<Content: View, MenuContent: View, HeaderAccessory: View>: View {
    var title: String?
    var cornerRadius: CGFloat
    var tintColor: Color
    var titleBottomPadding: CGFloat

    var content: Content
    var menuItems: MenuContent
    var headerAccessory: HeaderAccessory

    private var hasHeaderAccessory: Bool {
        HeaderAccessory.self != EmptyView.self
    }

    var body: some View {
        let cardVisuals = VStack(spacing: 0) {
            if title != nil || hasHeaderAccessory {
                HStack(spacing: 8) {
                    if let title = title {
                        Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                    }

                    Spacer(minLength: 0)

                    headerAccessory
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal, 16)
                .padding(.bottom, titleBottomPadding)
            }

            content
        }
        .frame(maxWidth: .infinity)
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .glassEffect(
            .regular.tint(tintColor.opacity(0.7)),
            in: .rect(cornerRadius: cornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5)
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
        .padding(.bottom, -10)
    }
}

extension Card where MenuContent == EmptyView, HeaderAccessory == EmptyView {
    init(
        _ title: String? = nil,
        cornerRadius: CGFloat = 24.0,
        tintColor: Color = Color(white: 0.96),
        titleBottomPadding: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.titleBottomPadding = titleBottomPadding
        self.content = content()
        self.menuItems = EmptyView()
        self.headerAccessory = EmptyView()
    }
}

extension Card where MenuContent == EmptyView {
    init(
        _ title: String? = nil,
        cornerRadius: CGFloat = 24.0,
        tintColor: Color = Color(white: 0.96),
        titleBottomPadding: CGFloat = 0,
        @ViewBuilder content: () -> Content,
        @ViewBuilder headerAccessory: () -> HeaderAccessory
    ) {
        self.title = title
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.titleBottomPadding = titleBottomPadding
        self.content = content()
        self.menuItems = EmptyView()
        self.headerAccessory = headerAccessory()
    }
}

extension Card where HeaderAccessory == EmptyView {
    init(
        _ title: String? = nil,
        cornerRadius: CGFloat = 24.0,
        tintColor: Color = Color(white: 0.96),
        titleBottomPadding: CGFloat = 0,
        @ViewBuilder content: () -> Content,
        @ViewBuilder menuItems: () -> MenuContent
    ) {
        self.title = title
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.titleBottomPadding = titleBottomPadding
        self.content = content()
        self.menuItems = menuItems()
        self.headerAccessory = EmptyView()
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()

        VStack {
            Card("MEAL PLAN") {

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
            .padding()

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
                    icon: .customSymbol("chart.bar"),
                    title: "Macro History",
                )
                //                {
                //                    print("History row tapped!")
                //                }
            }
            .padding()
        }
    }
}
