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
    var leftTint: Color = Color.gray.opacity(0.1)
    var leftTextColor: Color = .primary
    var leftAction: () -> Void

    var rightIcon: RowIcon? = nil
    var rightTitle: String
    var rightTint: Color = Color.gray.opacity(0.1)
    var rightTextColor: Color = .primary
    var rightAction: () -> Void

    var body: some View {
        HStack(spacing: spacing) {
            Button(action: leftAction) {
                ZStack {
                    Text(leftTitle)
                        .font(.system(size: 14, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        if let icon = leftIcon {
                            iconView(for: icon, textColor: leftTextColor)
                        }
                        Spacer()
                    }
                    .padding(.leading, 12)
                }
                .frame(height: 20)
                .padding(.vertical, 8)
                .background(leftTint)
                .foregroundStyle(leftTextColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button(action: rightAction) {
                ZStack {
                    Text(rightTitle)
                        .font(.system(size: 14, design: .rounded))
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
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconTint == .primary ? textColor : iconTint)
                .frame(width: 15)

        case .customSymbol(let systemName, let iconTint):
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
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
            rightTint: .blue,
            rightTextColor: .white,
            rightAction: { print("Save tapped") }
        )

        DoubleButtonRow(
            leftIcon: .customSymbol("trash", tint: .red),
            leftTitle: "Delete",
            leftTint: Color.red.opacity(0.1),
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
