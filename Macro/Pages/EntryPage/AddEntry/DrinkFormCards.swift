//
//  DrinkFormCards.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import SwiftData
import SwiftUI

struct DrinkIconButton: View {
    let form: DrinkFormState
    @Binding var isPicking: Bool

    var body: some View {
        Button {
            isPicking = true
        } label: {
            Image(symbol: form.symbol)
                .font(.rowIcon)
                .foregroundStyle(.white)
                .frame(width: RowMetrics.controlHeight, height: RowMetrics.controlHeight)
                .background(Circle().fill(form.tint.color))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil")
                        .font(.tag)
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.controlFill))
                        .background(Circle().fill(.white).padding(-1.5))
                        .offset(x: 4, y: 4)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 4)
        .accessibilityLabel("Icon & Color")
        .accessibilityValue(DrinkSymbol.label(for: form.symbol) ?? "")
        .accessibilityHint("Changes the drink's icon and color")
    }
}

extension View {
    func drinkIconSheet(isPresented: Binding<Bool>, form: Binding<DrinkFormState>) -> some View {
        sheet(isPresented: isPresented) {
            DrinkIconSheet(symbol: form.symbol, tint: form.tint)
        }
    }
}

struct DrinkPinRow: View {
    @Binding var form: DrinkFormState

    var body: some View {
        ToggleRow(
            title: String(localized: "Pin to Hydration Card"),
            info: String(localized: "Pinned drinks appear on the Hydration card and in Log Drink."),
            isOn: $form.isPinned
        )
    }
}

struct DrinkWaterGoalRow: View {
    @Binding var form: DrinkFormState

    var body: some View {
        ToggleRow(
            title: String(localized: "Counts Toward Water Goal"),
            info: String(localized: "Turn off for drinks you don't want in your water total."),
            isOn: $form.countsTowardWaterGoal
        )
    }
}

struct DrinkFormCards: View {
    @Binding var form: DrinkFormState
    @State private var showsSizesInfo = false
    @State private var newSizeID: UUID?
    @Binding var calories: String
    @Binding var protein: String
    @Binding var carbs: String
    @Binding var fat: String
    @Binding var fiber: String
    @Binding var isAIEstimated: Bool

    var body: some View {
        Card(String(localized: "Serving & Sizes"), titleBottomPadding: 4) {
            if showsSizesInfo {
                Text("Nutrition and caffeine are per serving. Name it, like Glass, and add other sizes you drink to log them in one tap.")
                    .font(.subtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .transition(.opacity)
            }

            DrinkSizeRow(
                name: $form.servingName,
                volume: $form.volume,
                unit: form.unit,
                role: String(localized: "Serving"),
                standardDrinks: form.servingVolumeML.flatMap(form.standardDrinks(forML:))
            )

            if !form.sizes.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
            }

            ReorderableRows(items: $form.sizes) { $size in
                CustomSwipeRow {
                    DrinkSizeRow(
                        name: $size.name,
                        volume: $size.volume,
                        unit: form.unit,
                        standardDrinks: form.milliliters(size).flatMap(form.standardDrinks(forML:)),
                        duplicateName: form.duplicateName(of: size),
                        requestsFocus: Binding(
                            get: { newSizeID == size.id },
                            set: { if !$0 { newSizeID = nil } }
                        )
                    )
                } onDelete: {
                    withAnimation(.snappy) {
                        form.sizes.removeAll { $0.id == size.id }
                    }
                }
            }

            ButtonRow(
                icon: .customSymbol("plus.circle.fill"),
                title: String(localized: "Add Size")
            ) {
                withAnimation(.snappy) {
                    newSizeID = form.addSize()
                }
            }
        } headerAccessory: {
            Button {
                withAnimation(.snappy(duration: 0.3)) {
                    showsSizesInfo.toggle()
                }
            } label: {
                Image(systemName: "info")
                    .font(.menuIcon)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.controlFill))
            }
            .buttonStyle(.plain)
            .padding(.vertical, -2)
            .padding(.trailing, -6)
            .accessibilityLabel("About Serving & Sizes")
            .accessibilityValue(showsSizesInfo ? "Shown" : "Hidden")
        }
        .padding([.top, .leading, .trailing])

        ForEach(DrinkDetail.allCases) { detail in
            Card {
                RowGroup(.divider) {
                    ToggleRow(
                        title: detail.title,
                        subtitle: toggleSubtitle(detail),
                        isOn: detailBinding(detail)
                    )

                    if form.isOn(detail) {
                        detailFields(detail)
                    } else if detail == .nutrition, let kcal = form.suggestedAlcoholCalories {
                        BaseRowLayout(
                            icon: .calorie,
                            title: String(localized: "\(EntryHelper.format(kcal)) kcal from alcohol"),
                            subtitle: String(localized: "Estimated from size and strength")
                        ) {
                            Button {
                                withAnimation(.snappy) {
                                    form.add(.nutrition)
                                    calories = EntryHelper.format(kcal)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.smallIcon)
                                        .foregroundStyle(Color.accentColor)
                                    Text("Add")
                                        .foregroundStyle(Color.primary)
                                }
                                .pillBackground()
                                .contentShape(.capsule)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "Add \(EntryHelper.format(kcal)) kcal from alcohol"))
                        }
                    }
                }
            }
            .padding([.top, .leading, .trailing])
        }
    }

    private var servingName: String? {
        let trimmed = form.servingName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var servingAmount: String? {
        form.servingVolumeML.map(form.unit.formattedAmount)
    }

    private var perServingSuffix: String {
        switch (servingName, servingAmount) {
        case let (name?, amount?): String(localized: "per \(name) (\(amount))")
        case let (nil, amount?): String(localized: "per serving (\(amount))")
        case let (name?, nil): String(localized: "per \(name)")
        case (nil, nil): String(localized: "per serving")
        }
    }

    private func toggleSubtitle(_ detail: DrinkDetail) -> String {
        switch detail {
        case .caffeine: String(localized: "Track caffeine \(perServingSuffix)")
        case .nutrition: String(localized: "Calories and macros \(perServingSuffix)")
        case .alcohol: String(localized: "Track standard drinks \(perServingSuffix)")
        }
    }

    private var strengthOptionSubtitles: [String: String] {
        Dictionary(
            uniqueKeysWithValues: AlcoholStrength.presets.compactMap { strength in
                strength.examples.map { (strength.label, $0) }
            }
        )
    }

    private var strengthSelection: Binding<String> {
        Binding(
            get: {
                form.strength == .custom ? "\(form.abv.isEmpty ? "-" : form.abv)%" : form.strength.label
            },
            set: { value in
                if let preset = AlcoholStrength.presets.first(where: { $0.label == value }) {
                    form.strength = preset
                    return
                }
                let number = value.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                guard let abv = DrinkFormState.parse(number) else { return }
                let clamped = min(max(abv, 0), 100)
                if let preset = AlcoholStrength.matching(clamped) {
                    form.strength = preset
                } else {
                    form.isCustomABV = true
                    form.abv = EntryHelper.format(clamped)
                }
            }
        )
    }

    private func detailBinding(_ detail: DrinkDetail) -> Binding<Bool> {
        Binding(
            get: { form.isOn(detail) },
            set: { isOn in
                withAnimation(.snappy) {
                    if isOn {
                        form.add(detail)
                    } else {
                        form.remove(detail)
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func detailFields(_ detail: DrinkDetail) -> some View {
        switch detail {
        case .nutrition:
            TextInputRow(
                icon: .calorie,
                title: "Calories",
                titleExtension: "(kcal)",
                placeholder: "-",
                text: $calories,
                keyboardType: .decimalPad
            )
            TextInputRow(
                icon: .protein,
                title: "Protein",
                titleExtension: "(g)",
                placeholder: "-",
                text: $protein,
                keyboardType: .decimalPad
            )
            TextInputRow(
                icon: .carbs,
                title: "Carbohydrates",
                titleExtension: "(g)",
                placeholder: "-",
                text: $carbs,
                keyboardType: .decimalPad
            )
            TextInputRow(
                icon: .fat,
                title: "Fat",
                titleExtension: "(g)",
                placeholder: "-",
                text: $fat,
                keyboardType: .decimalPad
            )
            TextInputRow(
                icon: .fiber,
                title: "Fiber",
                titleExtension: "(g)",
                placeholder: "-",
                text: $fiber,
                keyboardType: .decimalPad
            )
            ToggleRow(
                title: "AI Estimated Macros",
                isOn: $isAIEstimated
            )

        case .caffeine:
            TextInputRow(
                icon: .caffeine,
                title: String(localized: "Amount"),
                titleExtension: "(mg)",
                placeholder: "-",
                text: $form.caffeine,
                keyboardType: .decimalPad
            )

        case .alcohol:
            BaseRowLayout(
                icon: .alcohol,
                title: String(localized: "Strength"),
                subtitle: form.servingVolumeML
                    .flatMap(form.standardDrinks(forML:))
                    .map(DrinkAmounts.standardDrinksText)
            ) {
                DropdownPill(
                    options: AlcoholStrength.presets.map(\.label),
                    commitsCustomOnEnd: true,
                    customKeyboardType: .decimalPad,
                    customSuffix: "%",
                    optionSubtitles: strengthOptionSubtitles,
                    selection: strengthSelection
                )
            }
        }
    }
}

struct DrinkSizeRow: View {
    @Binding var name: String
    @Binding var volume: String
    let unit: VolumeUnit
    var role: String? = nil
    let standardDrinks: Double?
    var duplicateName: String? = nil
    var requestsFocus: Binding<Bool> = .constant(false)

    private var subtitle: String? {
        if let duplicateName {
            return String(localized: "Same as \(duplicateName)")
        }
        let parts = [role.map { _ in String(localized: "Default size") }, standardDrinks.map(DrinkAmounts.standardDrinksText)].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @FocusState private var isFocused: Bool
    @State private var draft = ""
    @State private var selection: TextSelection?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                TextField(role ?? String(localized: "Size Name"), text: $draft, selection: $selection)
                    .focused($isFocused)
                    .autoFloatingToolbar(
                        for: .default,
                        text: $name,
                        draft: $draft,
                        selection: $selection
                    )
                    .accessibilityLabel(role.map { String(localized: "\($0) Name") } ?? String(localized: "Size Name"))

                if let subtitle {
                    Text(subtitle)
                        .font(.subtitle)
                        .foregroundStyle(Color.tertiaryText)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            InputPill(
                text: $volume,
                unit: unit.rawValue,
                keyboardType: .decimalPad
            )
        }
        .frame(minHeight: RowMetrics.controlHeight)
        .padding(.horizontal, 16)
        .padding(.vertical, RowMetrics.verticalPadding)
        .onChange(of: requestsFocus.wrappedValue, initial: true) { _, requested in
            guard requested else { return }
            isFocused = true
            requestsFocus.wrappedValue = false
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: User.self, FoodItem.self, LoggedEntry.self, ServingSizeUnit.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    container.mainContext.insert(User(onboardingComplete: true))
    AppSeeder.resetListSeeding()
    try? AppSeeder.seedDefaults(into: container.mainContext)
    let drinks = (try? container.mainContext.fetch(FetchDescriptor<FoodItem>())) ?? []
    let coffee = drinks.first { $0.seedKey == "coffee" }!
    coffee.abv = 5

    return EditEntryView(foodItem: coffee)
        .modelContainer(container)
}

#Preview("Details") {
    @Previewable @State var form: DrinkFormState = {
        var form = DrinkFormState(unit: .milliliters)
        form.volume = "355"
        form.details = [.caffeine, .alcohol]
        form.caffeine = "34"
        form.abv = "6.5"
        form.isCustomABV = true
        return form
    }()
    @Previewable @State var macro = ""
    @Previewable @State var isAI = false
    @Previewable @State var focusManager = SwipeFocusManager()

    ZStack {
        Color.background.ignoresSafeArea()
        ScrollView {
            VStack {
                DrinkFormCards(
                    form: $form,
                    calories: $macro,
                    protein: $macro,
                    carbs: $macro,
                    fat: $macro,
                    fiber: $macro,
                    isAIEstimated: $isAI
                )
            }
        }
    }
    .environment(focusManager)
}
