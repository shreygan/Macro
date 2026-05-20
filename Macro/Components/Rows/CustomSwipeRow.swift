//
//  CustomSwipeRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/15/26.
//

import SwiftUI

@Observable
class SwipeFocusManager {
    var activeRowID: String? = nil
}

struct CustomSwipeRow<Content: View>: View {
    let id = UUID().uuidString
    @ViewBuilder var content: Content
    var onDelete: () -> Void
    var onEdit: (() -> Void)? = nil
    var onFavorite: (() -> Void)? = nil

    @Environment(SwipeFocusManager.self) private var focusManager

    @State private var horizontalOffset: CGFloat = 0
    @State private var lastOffset: CGFloat = 0

    @State private var isDragging: Bool = false
    @State private var isVerticalDrag: Bool = false

    private let buttonSize: CGFloat = 50
    private let buttonSpacing: CGFloat = 12
    private let leadingPadding: CGFloat = 8
    private let trailingPadding: CGFloat = 16

    private var totalRevealWidth: CGFloat {
        let buttonCount =
            1 + (onEdit != nil ? 1 : 0) + (onFavorite != nil ? 1 : 0)

        let spacesCount = max(0, buttonCount - 1)

        return (buttonSize * CGFloat(buttonCount))
            + (buttonSpacing * CGFloat(spacesCount)) + trailingPadding
            + leadingPadding
    }

    var body: some View {
        ZStack(alignment: .trailing) {

            HStack(spacing: buttonSpacing) {

                if let onFavAction = onFavorite {
                    let favScale = computeButtonScale(forIndex: 2)
                    Button(action: {
                        closeRow()
                        onFavAction()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color.yellow)
                                .clipShape(Circle())

                            Text("Favorite")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .scaleEffect(favScale)
                    .opacity(favScale > 0.01 ? 1 : 0)
                }

                if let onEditAction = onEdit {
                    let editScale = computeButtonScale(forIndex: 1)
                    Button(action: {
                        closeRow()
                        onEditAction()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color.gray)
                                .clipShape(Circle())

                            Text("Edit")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .scaleEffect(editScale)
                    .opacity(editScale > 0.01 ? 1 : 0)
                }

                let deleteScale = computeButtonScale(forIndex: 0)
                Button(action: {
                    closeRow()
                    onDelete()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(Color.red)
                            .clipShape(Circle())

                        Text("Delete")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .scaleEffect(deleteScale)
                .opacity(deleteScale > 0.01 ? 1 : 0)
            }
            .padding(.trailing, trailingPadding)
            .frame(width: totalRevealWidth, alignment: .trailing)

            content
                .contentShape(Rectangle())
                .clipped()
                .offset(x: horizontalOffset)
                .highPriorityGesture(
                    TapGesture().onEnded {
                        if focusManager.activeRowID != nil {
                            withAnimation(
                                .spring(response: 0.25, dampingFraction: 0.85)
                            ) {
                                focusManager.activeRowID = nil
                            }
                        }
                    },
                    including: focusManager.activeRowID != nil
                        ? .gesture : .subviews
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 25)
                        .onChanged { value in

                            if !isDragging {
                                isDragging = true
                                isVerticalDrag =
                                    abs(value.translation.height)
                                    > (abs(value.translation.width) * 1.5)
                            }

                            if isVerticalDrag { return }

                            if focusManager.activeRowID != id {
                                focusManager.activeRowID = id
                            }

                            let adjustedTranslation =
                                value.translation.width < 0
                                ? value.translation.width + 25
                                : value.translation.width - 25

                            let currentDrag = lastOffset + adjustedTranslation

                            if currentDrag < 0 {
                                if currentDrag < -totalRevealWidth {
                                    let excess = currentDrag + totalRevealWidth
                                    horizontalOffset =
                                        -totalRevealWidth + (excess * 0.25)
                                } else {
                                    horizontalOffset = currentDrag
                                }
                            } else {
                                horizontalOffset = currentDrag * 0.15
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            if isVerticalDrag {
                                isVerticalDrag = false
                                return
                            }

                            let predictedOffset =
                                lastOffset + value.predictedEndTranslation.width

                            withAnimation(
                                .spring(
                                    response: 0.35,
                                    dampingFraction: 0.75,
                                    blendDuration: 0
                                )
                            ) {
                                if predictedOffset < -(totalRevealWidth / 2) {
                                    horizontalOffset = -totalRevealWidth
                                    lastOffset = -totalRevealWidth
                                    focusManager.activeRowID = id
                                } else {
                                    horizontalOffset = 0
                                    lastOffset = 0
                                    if focusManager.activeRowID == id {
                                        focusManager.activeRowID = nil
                                    }
                                }
                            }
                        }
                )
        }
        .clipped()
        .onChange(of: focusManager.activeRowID) { _, newValue in
            if newValue != id && horizontalOffset != 0 {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    horizontalOffset = 0
                    lastOffset = 0
                }
            }
        }
    }

    private func closeRow() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            horizontalOffset = 0
            lastOffset = 0
            if focusManager.activeRowID == id {
                focusManager.activeRowID = nil
            }
        }
    }

    private func computeButtonScale(forIndex index: Int) -> CGFloat {
        let currentPull = -horizontalOffset

        let deleteStart = trailingPadding + (buttonSize / 2)
        let deleteFull = trailingPadding + buttonSize

        let editStart = deleteFull + buttonSpacing + (buttonSize / 2)
        let editFull = deleteFull + buttonSpacing + buttonSize

        let favStart = editFull + buttonSpacing + (buttonSize / 2)
        let favFull = editFull + buttonSpacing + buttonSize

        if index == 0 {
            if currentPull < deleteStart { return 0 }
            let progress =
                (currentPull - deleteStart) / (deleteFull - deleteStart)
            return min(max(progress, 0), 1)
        } else if index == 1 {
            if currentPull < editStart { return 0 }
            let progress = (currentPull - editStart) / (editFull - editStart)
            return min(max(progress, 0), 1)
        } else {
            if currentPull < favStart { return 0 }
            let progress = (currentPull - favStart) / (favFull - favStart)
            return min(max(progress, 0), 1)
        }
    }
}

#Preview {
    @Previewable @State var focusManager = SwipeFocusManager()
    let mockUnits = [
        ServingSizeUnit(unit: "bowl", displayOrder: 1),
        ServingSizeUnit(unit: "chip", pluralVariant: "chips", displayOrder: 2),
        ServingSizeUnit(unit: "scoop", displayOrder: 3),
        ServingSizeUnit(unit: "piece", displayOrder: 4),
    ]

    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()

        VStack(spacing: 24) {

            VStack(alignment: .leading, spacing: 8) {
                Text("SHRINK-WRAPPED (ScrollView + Card + CustomSwipeRow)")
                    .font(.caption).bold().foregroundColor(.secondary)
                    .padding(.horizontal)

                ScrollView {
                    Card {
                        RowGroup(.divider) {
                            CustomSwipeRow {
                                MealRow(
                                    name: "Grilled Chicken Salad",
                                    source: "Sweetgreen",
                                    isCustomDefaultServing: false,
                                    customServingSize: "",
                                    servingSize: "1",
                                    servingSizeUnit: "bowl",
                                    servingWeight: "",
                                    servingWeightUnit: "",
                                    servingUnits: mockUnits,
                                    calorie: "450",
                                    protein: "42",
                                    carbs: "12",
                                    fat: "18",
                                    fiber: "6"
                                ) {}
                            } onDelete: {
                                print("Custom delete salad")
                            } onEdit: {
                                print("Custom edit salad")
                            } onFavorite: {
                                print("Custom favorite salad")
                            }

                            CustomSwipeRow {
                                MealRow(
                                    name: "Protein Shake",
                                    source: "Home Cooked",
                                    isCustomDefaultServing: true,
                                    customServingSize: "1.5",
                                    servingSize: "1",
                                    servingSizeUnit: "scoop",
                                    servingWeight: "45",
                                    servingWeightUnit: "g",
                                    servingUnits: mockUnits,
                                    calorie: "210",
                                    protein: "37",
                                    carbs: "4",
                                    fat: "3",
                                    fiber: "1"
                                ) {}
                            } onDelete: {
                                print("Custom delete shake")
                            } onEdit: {
                                print("Custom edit shake")
                            } onFavorite: {
                                print("Custom favorite shake")
                            }

                            CustomSwipeRow {
                                MealRow(
                                    name: "Lentils & Rice (Khichri)",
                                    source: "Mom's Food",
                                    isCustomDefaultServing: false,
                                    customServingSize: "",
                                    servingSize: "1",
                                    servingSizeUnit: "bowl",
                                    servingWeight: "350",
                                    servingWeightUnit: "g",
                                    servingUnits: mockUnits,
                                    calorie: "520",
                                    protein: "22",
                                    carbs: "85",
                                    fat: "6",
                                    fiber: "12"
                                ) {}
                            } onDelete: {
                                print("Custom delete khichri")
                            } onEdit: {
                                print("Custom edit khichri")
                            } onFavorite: {
                                print("Custom favorite khichri")
                            }

                            CustomSwipeRow {
                                MealRow(
                                    name: "Chips",
                                    source: "Lays",
                                    isCustomDefaultServing: false,
                                    customServingSize: "",
                                    servingSize: "11",
                                    servingSizeUnit: "chip",
                                    servingWeight: "50",
                                    servingWeightUnit: "g",
                                    servingUnits: mockUnits,
                                    calorie: "240",
                                    protein: "2",
                                    carbs: "26",
                                    fat: "14",
                                    fiber: "1"
                                ) {}
                            } onDelete: {
                                print("Custom delete chips")
                            } onEdit: {
                                print("Custom edit chips")
                            } onFavorite: {
                                print("Custom favorite chips")
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(.vertical)
    }
    .environment(focusManager)
}
