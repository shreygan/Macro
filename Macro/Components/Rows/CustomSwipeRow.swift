//
//  CustomSwipeRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/15/26.
//

import SwiftUI

struct CustomSwipeRow<Content: View>: View {
    let id = UUID().uuidString
    @ViewBuilder var content: Content
    var onDelete: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var editTitle: LocalizedStringKey = "Edit"

    var onFavorite: (() -> Void)? = nil
    var isFavorited: Bool = false
    var favoriteTitle: LocalizedStringKey = "Favorite"
    var unfavoriteTitle: LocalizedStringKey = "Unfavorite"

    var onPin: (() -> Void)? = nil
    var isPinned: Bool = false

    var onHide: (() -> Void)? = nil
    var isHidden: Bool = false

    @Environment(SwipeFocusManager.self) private var focusManager

    @State private var horizontalOffset: CGFloat = 0
    @State private var lastOffset: CGFloat = 0

    @State private var isDragging: Bool = false
    @State private var isVerticalDrag: Bool = false
    @State private var contentHeight: CGFloat?

    private let fullButtonSize: CGFloat = 44
    private let compactButtonSize: CGFloat = 36
    private let fullButtonHeight: CGFloat = 60
    private let fullButtonMargin: CGFloat = 8
    private let buttonSpacing: CGFloat = 12
    private let leadingPadding: CGFloat = 8
    private let trailingPadding: CGFloat = 16

    private var isCompact: Bool {
        guard let contentHeight else { return false }
        return contentHeight < fullButtonHeight + fullButtonMargin * 2
    }

    private var buttonSize: CGFloat {
        isCompact ? compactButtonSize : fullButtonSize
    }

    private var totalRevealWidth: CGFloat {
        let buttonCount =
            (onDelete != nil ? 1 : 0) + (onEdit != nil ? 1 : 0)
            + (onFavorite != nil ? 1 : 0) + (onPin != nil ? 1 : 0)
            + (onHide != nil ? 1 : 0)

        if buttonCount == 0 { return 0 }

        let spacesCount = max(0, buttonCount - 1)

        return
            (buttonSize
            * CGFloat(buttonCount))
            + (buttonSpacing * CGFloat(spacesCount)) + trailingPadding
            + leadingPadding
    }

    private func actionButton(
        symbol: String,
        color: Color,
        title: LocalizedStringKey,
        positionFromRight: Int,
        action: @escaping () -> Void
    ) -> some View {
        let scale = computeButtonScale(positionFromRight: positionFromRight)
        return Button {
            closeRow()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(color)
                    .clipShape(Circle())

                if !isCompact {
                    Text(title)
                        .font(.swipeLabel)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityLabel(Text(title))
        .scaleEffect(scale)
        .opacity(scale > 0.01 ? 1 : 0)
    }

    var body: some View {
        ZStack(alignment: .trailing) {

            HStack(spacing: buttonSpacing) {
                if let onFavorite {
                    actionButton(
                        symbol: isFavorited ? "star.slash.fill" : "star.fill",
                        color: .yellow,
                        title: isFavorited ? unfavoriteTitle : favoriteTitle,
                        positionFromRight: (onDelete != nil ? 1 : 0) + (onEdit != nil ? 1 : 0)
                            + (onPin != nil ? 1 : 0) + (onHide != nil ? 1 : 0),
                        action: onFavorite
                    )
                }

                if let onPin {
                    actionButton(
                        symbol: isPinned ? "pin.slash.fill" : "pin.fill",
                        color: .orange,
                        title: isPinned ? "Unpin" : "Pin",
                        positionFromRight: (onDelete != nil ? 1 : 0) + (onEdit != nil ? 1 : 0)
                            + (onHide != nil ? 1 : 0),
                        action: onPin
                    )
                }

                if let onEdit {
                    actionButton(
                        symbol: "pencil",
                        color: .gray,
                        title: editTitle,
                        positionFromRight: (onDelete != nil ? 1 : 0) + (onHide != nil ? 1 : 0),
                        action: onEdit
                    )
                }

                if let onHide {
                    actionButton(
                        symbol: isHidden ? "eye.fill" : "eye.slash.fill",
                        color: .indigo,
                        title: isHidden ? "Unhide" : "Hide",
                        positionFromRight: onDelete != nil ? 1 : 0,
                        action: onHide
                    )
                }

                if let onDelete {
                    actionButton(
                        symbol: "trash",
                        color: .red,
                        title: "Delete",
                        positionFromRight: 0,
                        action: onDelete
                    )
                }
            }
            .padding(.trailing, trailingPadding)
            .frame(width: totalRevealWidth, alignment: .trailing)

            content
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height                }
                .frame(minHeight: buttonSize + 16)
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

    private func computeButtonScale(positionFromRight: Int) -> CGFloat {
        let currentPull = -horizontalOffset

        let startOffset =
            trailingPadding + CGFloat(positionFromRight)
            * (buttonSize + buttonSpacing)
        let buttonStart = startOffset + (buttonSize / 2)
        let buttonFull = startOffset + buttonSize

        if currentPull < buttonStart { return 0 }
        let progress = (currentPull - buttonStart) / (buttonFull - buttonStart)
        return min(max(progress, 0), 1)
    }
}

#Preview {
    @Previewable @State var focusManager = SwipeFocusManager()
    //    @Previewable @State var text: String = ""

    let mockUnits = [
        ServingSizeUnit(unit: "bowl", displayOrder: 1),
        ServingSizeUnit(unit: "chip", pluralVariant: "chips", displayOrder: 2),
        ServingSizeUnit(unit: "scoop", displayOrder: 3),
        ServingSizeUnit(unit: "piece", displayOrder: 4),
    ]

    ZStack {
        Color.background.ignoresSafeArea()

        VStack(spacing: 24) {

            VStack(alignment: .leading, spacing: 8) {
                Text("SHRINK-WRAPPED (ScrollView + Card + CustomSwipeRow)")
                    .font(.caption).bold().foregroundColor(.secondary)
                    .padding(.horizontal)

                ScrollView {
                    Card {
                        RowGroup(.divider) {

                            CustomSwipeRow {
                                WrappedInputRow(
                                    placeholder: "Add a note...",
                                    text: .constant("test"),
                                    //                                    text: $text,
                                )
                            } onDelete: {
                                print("Custom delete chips")
                            } onEdit: {
                                print("Custom edit chips")
                            } onPin: {
                                print("Custom favorite chips")
                            }

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
                            } onPin: {
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
