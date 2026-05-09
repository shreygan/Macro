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
    var tint: Color = Color.gray.opacity(0.2)
    var textColor: Color = .primary

    var topPadding: CGFloat = 8
    var bottomPadding: CGFloat = 16

    var iconSize: CGFloat = 18

    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 14, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    if let icon = icon {
                        switch icon {
                        case .system(let systemName, let iconTint):
                            Image(systemName: systemName)
                                .font(.system(size: 14, weight: .medium))
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
    //    ZStack {
    //        Color.gray.opacity(0.15).ignoresSafeArea()
    //
    //        Card(title: "New Entry") {
    //
    //            ButtonRow(title: "Save Changes", bottomPadding: 8) {
    //                print("Saved!")
    //            }
    //
    //            ButtonRow(
    //                icon: .system("trash"),
    //                title: "Delete Meal",
    //                tint: .red,
    //                textColor: .white,
    //                bottomPadding: 8
    //            ) {
    //                print("Deleted!")
    //            }
    //
    //            ButtonRow(
    //                icon: .custom(Image("Calorie")),
    //                title: "Scan Barcode"
    //            ) {
    //                print("Scanner opened!")
    //            }
    //        }
    //    }
}
