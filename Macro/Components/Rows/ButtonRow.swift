//
//  ButtonRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct ButtonRow: View {
    var icon: RowIcon? = nil
    var title: String
    var tint: Color = .controlFill
    var textColor: Color = .primary

    var topPadding: CGFloat = 8
    var bottomPadding: CGFloat = 16

    var iconSize: CGFloat = 18

    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.rowButton)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    if let icon = icon {
                        switch icon {
                        case .appSymbol(let symbol, let iconTint):
                            Image(systemName: symbol.rawValue)
                                .font(.buttonIcon)
                                .foregroundColor(
                                    iconTint == .primary ? textColor : iconTint
                                )
                                .frame(width: 15)

                        case .customSymbol(let systemName, let iconTint):
                            Image(systemName: systemName)
                                .font(.buttonIcon)
                                .foregroundColor(
                                    iconTint == .primary ? textColor : iconTint
                                )
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
                    Spacer()
                }
                .padding(.leading, 12)
            }
            .frame(height: 20)
            .padding(.vertical, 8)
            .background(tint)
            .foregroundStyle(textColor)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .buttonStyle(.plain)
    }
}

#Preview {
    ButtonRow(
        icon: .custom(Image("Calorie")),
        title: "Scan Barcode"
    ) {
        print("Scanner opened!")
    }
}

extension ButtonRow {
    static func restoreInProgress(topPadding: CGFloat = 8) -> some View {
        ButtonRow(
            icon: .customSymbol("icloud.and.arrow.down", tint: .secondary),
            title: String(localized: "Restore in Progress"),
            tint: .controlFill,
            textColor: .secondary,
            topPadding: topPadding
        ) {}
        .allowsHitTesting(false)
    }
}
