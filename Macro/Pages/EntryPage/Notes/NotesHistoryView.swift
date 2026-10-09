//
//  NotesHistoryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/9/26.
//

import SwiftData
import SwiftUI

struct NotesHistoryView: View {
    let food: FoodItem
    var currentEntryID: UUID? = nil

    var body: some View {
        NavigationStack {
            NotesHistoryContent(food: food, currentEntryID: currentEntryID)
        }
        .environment(\.tabBarHeight, 0)
    }
}

private struct NotesHistoryContent: View {
    @Environment(\.dismiss) private var dismiss

    let food: FoodItem
    let currentEntryID: UUID?

    @Query private var logs: [LoggedEntry]

    @State private var selectedEntry: LoggedEntry? = nil

    init(food: FoodItem, currentEntryID: UUID?) {
        self.food = food
        self.currentEntryID = currentEntryID
        _logs = Query(FoodItemStore.topLevelLogsDescriptor(for: food))
    }

    private struct NoteMonth: Identifiable {
        let id: Date
        var entries: [LoggedEntry]
    }

    private var pinnedNote: Note? {
        guard let note = food.stickyNote, !note.text.isEmpty else { return nil }
        return note
    }

    private var notedEntries: [LoggedEntry] {
        logs.filter { !($0.logNote ?? "").isEmpty }
    }

    private var months: [NoteMonth] {
        let calendar = Calendar.current
        var result: [NoteMonth] = []
        for entry in notedEntries {
            let month =
                calendar.dateInterval(of: .month, for: entry.timestamp)?.start
                ?? entry.timestamp
            if result.last?.id == month {
                result[result.count - 1].entries.append(entry)
            } else {
                result.append(NoteMonth(id: month, entries: [entry]))
            }
        }
        return result
    }

    var body: some View {
        let months = months

        ZStack {
            Color.background.ignoresSafeArea()

            if pinnedNote == nil && months.isEmpty {
                ContentUnavailableView {
                    Label("No Notes", systemImage: "note.text")
                } description: {
                    Text("Notes you add when logging this \(food.type.rawValue) will appear here.")
                        .font(.subheadline)
                }
            } else {
                ScrollView {
                    VStack {
                        if let pinnedNote {
                            Card("Pinned", titleBottomPadding: -4) {
                                NoteHistoryRow(
                                    text: pinnedNote.text,
                                    detail: String(
                                        localized:
                                            "Updated \(pinnedNote.lastUpdated.formatted(.relative(presentation: .named)))"
                                    ),
                                    symbol: "pin.fill",
                                    symbolTint: .orange
                                )
                            }
                            .padding(.horizontal)
                        }

                        ForEach(months) { month in
                            Card(
                                month.id.formatted(.dateTime.month(.wide).year()),
                                titleBottomPadding: -4
                            ) {
                                RowGroup(.divider) {
                                    ForEach(month.entries) { entry in
                                        entryRow(entry)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(
                                .top,
                                pinnedNote == nil && month.id == months.first?.id
                                    ? 0 : nil
                            )
                        }
                    }
                    .padding(.bottom)
                }
            }
        }
        .navigationDestination(item: $selectedEntry) { entry in
            LoggedEntryDetailView(entry: entry, isReadOnly: true)
        }
        .navigationTitle("Notes")
        .navigationSubtitle(food.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: LoggedEntry) -> some View {
        let canOpen = entry.id != currentEntryID
        let row = NoteHistoryRow(
            text: entry.logNote ?? "",
            detail: detail(for: entry),
            showsChevron: canOpen
        )

        if canOpen {
            Button {
                selectedEntry = entry
            } label: {
                row.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }

    private func detail(for entry: LoggedEntry) -> String {
        var parts = [EntryHelper.logDateText(entry.timestamp)]

        if let category = entry.category?.category, !category.isEmpty {
            parts.append(category)
        }

        if entry.id == currentEntryID {
            parts.append(String(localized: "This Log"))
        }

        return parts.joined(separator: " · ")
    }
}

private struct NoteHistoryRow: View {
    let text: String
    let detail: String
    var symbol: String? = nil
    var symbolTint: Color = .secondary
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            textContent

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(symbolTint)
                }

                Text(detail)
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodItem.self,
        LoggedEntry.self,
        CategorySource.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let lunch = CategorySource(category: "Lunch", displayOrder: 1)
    context.insert(lunch)

    let food = FoodItem(
        name: "Chicken Shawarma Bowl",
        servingSize: 1,
        servingWeightUnit: "g",
        isAIEstimated: false,
        calories: 650,
        protein: 45,
        carbs: 60,
        fat: 22,
        fiber: 8,
        isCustomDefaultServing: false,
        stickyNote: Note(
            text: "Ask them to hold the oil next time",
            lastUpdated: Date().addingTimeInterval(-86400 * 21)
        )
    )
    context.insert(food)

    let notes = [
        (0, "Much better this time, asked for less oil and it was way lighter"),
        (4, "Felt sluggish after, too heavy for lunch"),
        (40, "Extra garlic sauce, great"),
    ]
    for (dayOffset, note) in notes {
        context.insert(
            LoggedEntry(
                name: food.name,
                typeRawValue: "food",
                originalFoodItem: food,
                category: lunch,
                timestamp: Date().addingTimeInterval(Double(-dayOffset) * 86400),
                loggedQuantity: 1,
                loggedUnit: "serving",
                calories: 650,
                protein: 45,
                carbs: 60,
                fat: 22,
                fiber: 8,
                logNote: note
            )
        )
    }

    return NotesHistoryView(food: food)
        .modelContainer(container)
}
