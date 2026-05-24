//
//  BaseRowLayout.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct BaseRowLayout<RightContent: View>: View {
    var icon: RowIcon? = nil
    var title: String
    var titleExtension: String? = nil
    var subtitle: String? = nil

    var titleFontSize: CGFloat = 16

    @ViewBuilder var rightContent: RightContent

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                switch icon {
                case .appSymbol(let symbol, let tint):
                    Image(systemName: symbol.rawValue)
                        .font(.system(size: 14))
                        .foregroundStyle(tint)
                        .frame(width: 15)

                case .customSymbol(let systemName, let tint):
                    Image(systemName: systemName)
                        .font(.system(size: 14))
                        .foregroundStyle(tint)
                        .frame(width: 15)

                case .custom(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(height: titleFontSize * 1.4)
                        .scaleEffect(1.4)
                        .alignmentGuide(.lastTextBaseline) { dimensions in
                            dimensions.height * 0.75
                        }
                        .padding(.leading, 4)
                        .frame(width: 15)
                }
            }

            VStack(alignment: .leading, spacing: 2) {

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(title)
                        .font(.system(size: titleFontSize, weight: .medium))
                        .foregroundStyle(.primary)

                    if let titleExtension = titleExtension {
                        Text(titleExtension)
                            .font(
                                .system(size: titleFontSize, weight: .regular)
                            )
                            .foregroundStyle(.tertiary)

                    }
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            rightContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    VStack(spacing: 0) {

        BaseRowLayout(
            icon: .custom(Image("Calorie")),
            title: "Calories",
            titleExtension: "(kcal)"
        ) {
            Text("2,450")
                .font(.system(size: 16, weight: .semibold))
        }

        Divider().padding(.horizontal, 14)

        BaseRowLayout(
            icon: .customSymbol("scanner"),
            title: "Calories",
            titleExtension: "(kcal)"
        ) {
            Text("2,450")
        }

        Divider().padding(.horizontal, 14)

        BaseRowLayout(
            title: "Weight",
            titleExtension: "(lbs)",
            subtitle: "Last updated today"
        ) {
            Text("175.2")
                .font(.system(size: 16, weight: .semibold))
        }

        Divider().padding(.horizontal, 14)

        BaseRowLayout(
            icon: .customSymbol("switch.2", tint: .green),
            title: "Simple Row"
        ) {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }

        Divider().padding(.horizontal, 14)

        BaseRowLayout(title: "Simple Row") {
            Text("-")
                .foregroundStyle(.tertiary)
        }

    }
    .background(Color(white: 0.96))
    .cornerRadius(24)
    .padding()
}
