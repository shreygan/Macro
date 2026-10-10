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
    var info: String? = nil

    private let titleFontSize = FontSize.row

    @ViewBuilder var rightContent: RightContent

    @State private var isShowingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if info != nil {
                    leadingContent
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.3)) {
                                isShowingInfo.toggle()
                            }
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Shows more information")
                } else {
                    leadingContent
                }

                Spacer()

                rightContent
            }

            if let info, isShowingInfo {
                Text(info)
                    .font(.subtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, icon != nil ? 23 : 0)
                    .padding(.top, 6)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var leadingContent: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                switch icon {
                case .appSymbol(let symbol, let tint):
                    Image(systemName: symbol.rawValue)
                        .font(.rowIcon)
                        .foregroundStyle(tint)
                        .frame(width: 15)

                case .customSymbol(let systemName, let tint):
                    Image(systemName: systemName)
                        .font(.rowIcon)
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
                        .font(.rowTitle)
                        .foregroundStyle(.primary)

                    if let titleExtension = titleExtension {
                        Text(titleExtension)
                            .font(.rowValue)
                            .foregroundStyle(Color.tertiaryText)

                    }
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subtitle)
                        .foregroundStyle(Color.tertiaryText)
                }
            }
        }
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
                .foregroundStyle(Color.tertiaryText)
        }

    }
    .background(Color(white: 0.96))
    .cornerRadius(24)
    .padding()
}
