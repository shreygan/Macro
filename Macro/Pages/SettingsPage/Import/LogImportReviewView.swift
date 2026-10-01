//
//  LogImportReviewView.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LogImportReviewView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var users: [User]

    @Binding var entries: [DraftLogEntry]
    @Binding var issues: [ImportIssue]
    @Binding var isLoading: Bool
    @Binding var importAlert: DataTransferAlert?

    @State private var duplicateStrategy: DuplicateStrategy = .skip
    @State private var issueKindToShow: ImportIssue.Kind?
    @State private var isShowingFilePicker = false
    @State private var missingFoods: [DraftLogEntry] = []
    @State private var addMissingToLibrary = false

    var onProcessNewCSV: (URL) -> Void
    var onSaveComplete: () -> Void

    private var newEntries: [DraftLogEntry] {
        entries.filter { $0.duplicateOf == nil }
    }

    private var duplicateEntries: [DraftLogEntry] {
        entries.filter { $0.duplicateOf != nil }
    }

    private var entriesToSave: [DraftLogEntry] {
        duplicateStrategy == .skip ? newEntries : entries
    }

    private var invalidCount: Int {
        issues.filter { $0.kind == .invalid }.count
    }

    private var repeatedCount: Int {
        issues.filter { $0.kind == .repeated }.count
    }

    private var firstIssueKind: ImportIssue.Kind {
        if invalidCount > 0 { return .invalid }
        if repeatedCount > 0 { return .repeated }
        return .duplicate
    }

    private var missingRecipeCount: Int {
        missingFoods.filter { !$0.components.isEmpty }.count
    }

    private var dayStartMinutes: Int {
        users.first?.dayStartMinutes ?? 0
    }

    private var groupedEntries: [(day: Date, entries: [DraftLogEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: entriesToSave) {
            calendar.logicalDay(for: $0.timestamp, dayStartMinutes: dayStartMinutes)
        }
        return groups.keys.sorted(by: >).map { day in
            (day, groups[day, default: []].sorted { $0.timestamp < $1.timestamp })
        }
    }

    private var viewState: Int {
        if isLoading { return 0 }
        if entries.isEmpty { return 1 }
        return 2
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.blue)
                    Text("Reading CSV...")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if entries.isEmpty {
                ContentUnavailableView {
                    Label("No Valid Logs", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text(
                        invalidCount + repeatedCount > 0
                            ? "We skipped \(invalidCount + repeatedCount) row\(invalidCount + repeatedCount == 1 ? "" : "s"). There are no logs to import."
                            : "We couldn't find any logs in your CSV."
                    )
                    .font(.subheadline)
                } actions: {
                    VStack(spacing: 12) {
                        Button("Select Another CSV") {
                            isShowingFilePicker = true
                        }
                        .tint(.blue)

                        if !issues.isEmpty {
                            Button("View Skipped Rows") {
                                issueKindToShow = firstIssueKind
                            }
                            .tint(.secondary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                ScrollView {
                    VStack {
                        summaryCard
                            .padding([.horizontal, .bottom])

                        if entriesToSave.isEmpty {
                            Text("All logs in this file are already in your history.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding()
                        }

                        ForEach(groupedEntries, id: \.day) { group in
                            EntryList(
                                title: group.day.formatted(
                                    .dateTime.weekday(.wide).month(.wide).day().year()
                                ),
                                items: group.entries,
                                rowContent: { entry in row(for: entry) },
                                onDelete: { entry in
                                    entries.removeAll { $0.id == entry.id }
                                }
                            )
                            .padding([.horizontal, .bottom])
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.snappy, value: viewState)
        .onChange(of: entries, initial: true) { refreshMissingFoods() }
        .onChange(of: duplicateStrategy) { refreshMissingFoods() }
        .withGlobalSwipeDismissal()
        .navigationTitle("Review Logs (\(entriesToSave.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.primary)
                }
                .tint(Color.blue)
                .buttonStyle(.glassProminent)
                .disabled(entriesToSave.isEmpty)
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                onProcessNewCSV(url)
            case .failure(let error):
                importAlert = .selectionFailed(error)
            }
        }
        .sheet(item: $issueKindToShow) { kind in
            ImportIssuesView(kind: kind, issues: issues.filter { $0.kind == kind })
        }
        .dataTransferAlert($importAlert)
    }

    private var summaryCard: some View {
        Card("Summary", cornerRadius: 20) {
            RowGroup(.divider) {
                BaseRowLayout(
                    icon: .customSymbol("checkmark.circle.fill", tint: .green),
                    title: "New Logs",
                    subtitle: "\(newEntries.reduce(0) { $0 + $1.components.count }) recipe ingredients included"
                ) {
                    Text("\(newEntries.count)")
                }

                if !duplicateEntries.isEmpty {
                    Button {
                        issueKindToShow = .duplicate
                    } label: {
                        BaseRowLayout(
                            icon: .customSymbol("square.on.square.intersection.dashed"),
                            title: "Duplicates",
                            subtitle: "Already in your log history"
                        ) {
                            ImportIssueCount(count: duplicateEntries.count)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    DuplicateStrategyRow(strategy: $duplicateStrategy)
                }

                if !missingFoods.isEmpty {
                    BaseRowLayout(
                        icon: .customSymbol("questionmark.square.dashed"),
                        title: "Not in Library",
                        subtitle: missingRecipeCount > 0
                            ? "Includes \(missingRecipeCount) recipe\(missingRecipeCount == 1 ? "" : "s")"
                            : "Foods that don't match your library",
                        info: "These logs keep their macros, but without a library entry you can't log them again or favorite them."
                    ) {
                        Text("\(missingFoods.count)")
                    }

                    ToggleRow(
                        icon: .customSymbol("plus.square.on.square"),
                        title: "Add to Library",
                        subtitle: "Uses the most recent log of each",
                        isOn: $addMissingToLibrary
                    )
                }

                if repeatedCount > 0 {
                    Button {
                        issueKindToShow = .repeated
                    } label: {
                        BaseRowLayout(
                            icon: .customSymbol("arrow.2.squarepath"),
                            title: "Repeated Rows",
                            subtitle: "Only the first copy is imported"
                        ) {
                            ImportIssueCount(count: repeatedCount)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if invalidCount > 0 {
                    Button {
                        issueKindToShow = .invalid
                    } label: {
                        BaseRowLayout(
                            icon: .customSymbol("exclamationmark.triangle.fill", tint: .red),
                            title: "Errors",
                            subtitle: "Rows that couldn't be read"
                        ) {
                            ImportIssueCount(count: invalidCount)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(for entry: DraftLogEntry) -> some View {
        let time = entry.timestamp.formatted(date: .omitted, time: .shortened)
        let source = entry.source.isEmpty ? time : "\(time) · \(entry.source)"

        return MealRow(
            name: entry.name,
            source: source,
            isCustomDefaultServing: false,
            customServingSize: "",
            servingSize: EntryHelper.format(entry.quantity),
            servingSizeUnit: entry.unit,
            servingWeight: "",
            servingWeightUnit: "",
            servingUnits: [],
            calorie: EntryHelper.format(entry.calories),
            protein: EntryHelper.format(entry.protein),
            carbs: EntryHelper.format(entry.carbs),
            fat: EntryHelper.format(entry.fat),
            fiber: EntryHelper.format(entry.fiber),
            icon: entry.entryType.flatMap { $0 == .food ? nil : $0.appSymbol }
        )
    }

    private func save() {
        let resolver = ImportResolver(context: modelContext)
        var library = (try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? []
        if addMissingToLibrary {
            addToLibrary(missingFoods, library: &library, resolver: resolver)
        }
        let existingLogs =
            (try? modelContext.fetch(FetchDescriptor<LoggedEntry>())) ?? []
        var logsByID = Dictionary(
            existingLogs.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var replacedIDs = Set<UUID>()

        for draft in entries {
            if let duplicateID = draft.duplicateOf {
                switch duplicateStrategy {
                case .skip:
                    continue
                case .replace:
                    if let existing = logsByID[duplicateID],
                        replacedIDs.insert(duplicateID).inserted
                    {
                        apply(draft, to: existing, resolver: resolver, library: library)
                        for child in existing.childEntries ?? [] {
                            modelContext.delete(child)
                        }
                        existing.childEntries = []
                        insertComponents(of: draft, into: existing, resolver: resolver, library: library)
                        continue
                    }
                case .keepBoth:
                    break
                }
            }

            let id = draft.duplicateOf == nil
                ? draft.importID.flatMap { logsByID[$0] == nil ? $0 : nil } ?? UUID()
                : UUID()
            let log = makeLog(draft, id: id, parent: nil, resolver: resolver, library: library)
            modelContext.insert(log)
            logsByID[log.id] = log
            insertComponents(of: draft, into: log, resolver: resolver, library: library)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            importAlert = .saveFailed(error)
            return
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSaveComplete()
    }

    private func refreshMissingFoods() {
        let resolver = ImportResolver(context: modelContext)
        let library = (try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? []
        let newLogs = entriesToSave.filter {
            $0.duplicateOf == nil || duplicateStrategy == .keepBoth
        }

        var templates: [String: DraftLogEntry] = [:]
        var order: [String] = []

        func consider(_ draft: DraftLogEntry, replacingOlder: Bool) {
            guard
                resolver.matchFood(
                    id: draft.foodID,
                    name: draft.name,
                    source: draft.source,
                    in: library
                ) == nil
            else { return }

            let key = LibraryCSV.lookupKey(source: draft.source, name: draft.name)
            if let existing = templates[key] {
                if replacingOlder && draft.timestamp > existing.timestamp {
                    templates[key] = draft
                }
            } else {
                templates[key] = draft
                order.append(key)
            }
        }

        for log in newLogs {
            consider(log, replacingOlder: true)
        }
        let recipes = order.compactMap { templates[$0] }.filter {
            !$0.components.isEmpty
        }
        for recipe in recipes {
            for component in recipe.components {
                consider(component, replacingOlder: false)
            }
        }

        missingFoods = order.compactMap { templates[$0] }
    }

    private func addToLibrary(
        _ templates: [DraftLogEntry],
        library: inout [FoodItem],
        resolver: ImportResolver
    ) {
        var usedIDs = Set(library.map(\.id))
        var created: [(template: DraftLogEntry, food: FoodItem)] = []

        for template in templates {
            let id = template.foodID.flatMap { usedIDs.contains($0) ? nil : $0 } ?? UUID()
            usedIDs.insert(id)

            let type: EntryType =
                switch template.entryType {
                case .recipe: template.components.isEmpty ? .food : .recipe
                case .some(let type): type
                case .none: .food
                }

            let food = FoodItem(
                id: id,
                name: template.name,
                type: type,
                source: resolver.source(template.source),
                category: resolver.category(template.category),
                foodGroup: resolver.foodGroup(template.foodGroup),
                servingSize: template.quantity > 0 ? template.quantity : 1,
                servingUnit: resolver.unit(template.unit, plural: nil),
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: template.calories,
                protein: template.protein,
                carbs: template.carbs,
                fat: template.fat,
                fiber: template.fiber,
                isCustomDefaultServing: false
            )
            modelContext.insert(food)
            library.append(food)
            created.append((template, food))
        }

        for (template, recipe) in created where recipe.type == .recipe {
            for (index, component) in template.components.enumerated() {
                let ingredient = RecipeIngredient(
                    quantity: component.quantity,
                    unit: component.unit,
                    displayOrder: index,
                    name: component.name,
                    baseServingSize: component.quantity > 0 ? component.quantity : 1,
                    baseServingUnitName: component.unit,
                    baseServingWeight: nil,
                    baseServingWeightUnit: "g",
                    baseCalories: component.calories,
                    baseProtein: component.protein,
                    baseCarbs: component.carbs,
                    baseFat: component.fat,
                    baseFiber: component.fiber
                )
                ingredient.ingredientItem = resolver.matchFood(
                    id: component.foodID,
                    name: component.name,
                    source: component.source,
                    in: library
                )
                ingredient.parentRecipe = recipe
                modelContext.insert(ingredient)
            }
        }
    }

    private func insertComponents(
        of draft: DraftLogEntry,
        into parent: LoggedEntry,
        resolver: ImportResolver,
        library: [FoodItem]
    ) {
        for (index, component) in draft.components.enumerated() {
            var component = component
            component.displayOrder = index
            let child = makeLog(component, id: UUID(), parent: parent, resolver: resolver, library: library)
            modelContext.insert(child)
        }
    }

    private func makeLog(
        _ draft: DraftLogEntry,
        id: UUID,
        parent: LoggedEntry?,
        resolver: ImportResolver,
        library: [FoodItem]
    ) -> LoggedEntry {
        let log = LoggedEntry(
            id: id,
            name: draft.name,
            typeRawValue: draft.typeRawValue,
            parentEntry: parent,
            timestamp: draft.timestamp,
            loggedQuantity: draft.quantity,
            loggedUnit: draft.unit,
            calories: draft.calories,
            protein: draft.protein,
            carbs: draft.carbs,
            fat: draft.fat,
            fiber: draft.fiber
        )
        apply(draft, to: log, resolver: resolver, library: library)
        return log
    }

    private func apply(
        _ draft: DraftLogEntry,
        to log: LoggedEntry,
        resolver: ImportResolver,
        library: [FoodItem]
    ) {
        log.name = draft.name
        log.typeRawValue = draft.typeRawValue
        log.source = resolver.source(draft.source)
        log.category = resolver.category(draft.category)
        log.foodGroup = resolver.foodGroup(draft.foodGroup)
        log.timestamp = draft.timestamp
        log.location = draft.location
        log.loggedQuantity = draft.quantity
        log.loggedUnit = draft.unit
        log.calories = draft.calories
        log.protein = draft.protein
        log.carbs = draft.carbs
        log.fat = draft.fat
        log.fiber = draft.fiber
        log.isManualOverride = draft.isManualOverride
        log.logNote = draft.note
        log.displayOrder = draft.displayOrder

        log.originalFoodItem =
            resolver.matchFood(
                id: draft.foodID,
                name: draft.name,
                source: draft.source,
                in: library
            ) ?? log.originalFoodItem
    }
}

struct DuplicateStrategyRow: View {
    @Binding var strategy: DuplicateStrategy

    private var selection: Binding<String> {
        Binding(
            get: { strategy.rawValue },
            set: { strategy = DuplicateStrategy(rawValue: $0) ?? .skip }
        )
    }

    private var info: String {
        switch strategy {
        case .skip: return "Duplicates are left out and your existing data stays as it is."
        case .replace: return "Existing entries are overwritten with the values from this file."
        case .keepBoth: return "Duplicates are imported as new copies alongside your existing entries."
        }
    }

    var body: some View {
        BaseRowLayout(
            icon: .customSymbol("arrow.triangle.branch"),
            title: "Handle Duplicates",
            info: info
        ) {
            DropdownPill(
                options: DuplicateStrategy.allCases.map(\.rawValue),
                displayCustomOption: false,
                selection: selection
            )
        }
    }
}

struct ImportIssueCount: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("\(count)")
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }
}
