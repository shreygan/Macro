//
//  DoubleButtonRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 6/14/26.
//

import SwiftUI

struct DoubleButtonRow: View {
    var topPadding: CGFloat = 8
    var bottomPadding: CGFloat = 16
    var spacing: CGFloat = 16
    var iconSize: CGFloat = 18

    var leftIcon: RowIcon? = nil
    var leftTitle: String
    var leftTint: Color = .controlFill
    var leftTextColor: Color = .primary
    var leftAction: () -> Void
    var leftDisabled: Bool = false

    var rightIcon: RowIcon? = nil
    var rightTitle: String
    var rightTint: Color = .controlFill
    var rightTextColor: Color = .primary
    var rightAction: () -> Void

    private var leftForeground: Color {
        leftDisabled ? .secondary : leftTextColor
    }

    var body: some View {
        HStack(spacing: spacing) {
            Button(action: leftAction) {
                ZStack {
                    Text(leftTitle)
                        .font(.rowButton)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        if let icon = leftIcon {
                            iconView(for: icon, textColor: leftForeground)
                        }
                        Spacer()
                    }
                    .padding(.leading, 12)
                }
                .frame(height: 20)
                .padding(.vertical, 8)
                .background(leftTint)
                .foregroundStyle(leftForeground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!leftDisabled)

            Button(action: rightAction) {
                ZStack {
                    Text(rightTitle)
                        .font(.rowButton)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        if let icon = rightIcon {
                            iconView(for: icon, textColor: rightTextColor)
                        }
                        Spacer()
                    }
                    .padding(.leading, 12)
                }
                .frame(height: 20)
                .padding(.vertical, 8)
                .background(rightTint)
                .foregroundStyle(rightTextColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }

    @ViewBuilder
    private func iconView(for icon: RowIcon, textColor: Color) -> some View {
        switch icon {
        case .appSymbol(let symbol, let iconTint):
            Image(systemName: symbol.rawValue)
                .font(.buttonIcon)
                .foregroundColor(iconTint == .primary ? textColor : iconTint)
                .frame(width: 15)

        case .customSymbol(let systemName, let iconTint):
            Image(systemName: systemName)
                .font(.buttonIcon)
                .foregroundColor(iconTint == .primary ? textColor : iconTint)
                .frame(width: 15)

        case .custom(let image):
            image
                .resizable()
                .scaledToFit()
                .frame(height: iconSize * 1.4)
                .scaleEffect(1.4)
                .padding(.leading, 4)
                .frame(width: 15)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        DoubleButtonRow(
            leftTitle: "Cancel",
            leftAction: { print("Cancel tapped") },
            rightTitle: "Save",
            rightTint: .accentColor,
            rightTextColor: .white,
            rightAction: { print("Save tapped") }
        )

        DoubleButtonRow(
            leftIcon: .customSymbol("trash", tint: .red),
            leftTitle: "Delete",
            leftTint: .destructiveFill,
            leftTextColor: .red,
            leftAction: { print("Delete tapped") },

            rightIcon: .customSymbol("checkmark", tint: .white),
            rightTitle: "Confirm",
            rightTint: .green,
            rightTextColor: .white,
            rightAction: { print("Confirm tapped") }
        )

        DoubleButtonRow(
            spacing: 8,
            leftTitle: "Back",
            leftAction: { print("Back tapped") },
            rightTitle: "Next",
            rightAction: { print("Next tapped") }
        )
    }
    .padding()
}
