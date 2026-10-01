//
//  ExportView.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum LibraryExportFormat: String, CaseIterable {
    case detailed = "Detailed"
    case simplified = "Simplified"
}

enum LibraryExportFilter: String, CaseIterable {
    case favorites = "Favorites"
    case foods = "Foods"
    case recipes = "Recipes"
    case ingredients = "Ingredients"
    case drinks = "Drinks"

    func includes(_ item: FoodItem) -> Bool {
        switch self {
        case .favorites: return item.favoriteEntry != nil
        case .foods: return item.type == .food
        case .recipes: return item.type == .recipe
        case .ingredients: return item.type == .ingredient
        case .drinks: return item.type == .drink
        }
    }
}

enum LogExportRange: String, CaseIterable {
    case allTime = "All Time"
    case week = "Last 7 Days"
    case month = "Last 30 Days"
    case quarter = "Last 90 Days"
    case year = "This Year"
    case custom = "Custom"
}

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var foodItems: [FoodItem]
    @Query(filter: #Predicate<LoggedEntry> { $0.parentEntry == nil })
    private var loggedEntries: [LoggedEntry]
    @Query private var users: [User]
    @Query private var sources: [EntrySource]
    @Query private var drafts: [EntryDraft]

    @State private var libraryFormat: LibraryExportFormat = .simplified
    @State private var libraryFilters: Set<String> = []
    @State private var librarySources: Set<String> = []

    @State private var logRange: LogExportRange = .allTime
    @State private var customStart =
        Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEnd = Date()

    @State private var includePhotos = true

    @State private var exportDocument: ExportDocument?
    @State private var exportContentType: UTType = .commaSeparatedText
    @State private var exportFilename = ""
    @State private var isShowingExporter = false
    @State private var loadingKind: DataTransferKind?
    @State private var exportAlert: DataTransferAlert?

    private typealias PreparedExport = (
        document: ExportDocument,
        type: UTType,
        filename: String
    )

    private var dateStamp: String {
        Date().formatted(.iso8601.year().month().day())
    }

    private var dayStartMinutes: Int {
        users.first?.dayStartMinutes ?? 0
    }

    private var filteredFoods: [FoodItem] {
        let filters = LibraryExportFilter.allCases.filter {
            libraryFilters.contains($0.rawValue)
        }
        return foodItems.filter { item in
            (filters.isEmpty || filters.contains { $0.includes(item) })
                && (librarySources.isEmpty
                    || librarySources.contains(item.source?.source ?? ""))
        }
    }

    private var logDateRange: Range<Date>? {
        let calendar = Calendar.current
        let today = calendar.logicalDay(
            for: Date(),
            dayStartMinutes: dayStartMinutes
        )
        let endOfToday = calendar.logicalDayRange(
            for: today,
            dayStartMinutes: dayStartMinutes
        ).upperBound

        func start(of day: Date) -> Date {
            calendar.logicalDayRange(for: day, dayStartMinutes: dayStartMinutes)
                .lowerBound
        }

        func start(daysBack: Int) -> Date {
            start(
                of: calendar.date(
                    byAdding: .day,
                    value: -(daysBack - 1),
                    to: today
                ) ?? today
            )
        }

        switch logRange {
        case .allTime:
            return nil
        case .week:
            return start(daysBack: 7)..<endOfToday
        case .month:
            return start(daysBack: 30)..<endOfToday
        case .quarter:
            return start(daysBack: 90)..<endOfToday
        case .year:
            let yearStart =
                calendar.date(from: calendar.dateComponents([.year], from: today))
                ?? today
            return start(of: yearStart)..<endOfToday
        case .custom:
            let lower = start(of: min(customStart, customEnd))
            let upper = calendar.logicalDayRange(
                for: max(customStart, customEnd),
                dayStartMinutes: dayStartMinutes
            ).upperBound
            return lower..<upper
        }
    }

    private var filteredLogs: [LoggedEntry] {
        guard let range = logDateRange else { return loggedEntries }
        return loggedEntries.filter { range.contains($0.timestamp) }
    }

    private var photoCount: Int {
        func count(_ logs: [LoggedEntry]) -> Int {
            logs.reduce(0) {
                $0 + ($1.photos?.count ?? 0) + count($1.childEntries ?? [])
            }
        }
        return count(loggedEntries)
            + drafts.reduce(0) { $0 + ($1.photos?.count ?? 0) }
    }

    private var goalCount: Int {
        users.first?.goalsHistory?.count ?? 0
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    libraryCard
                        .padding(.horizontal)

                    logCard
                        .padding([.top, .horizontal])

                    backupCard
                        .padding([.top, .horizontal])
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isShowingExporter,
            item: exportDocument,
            contentTypes: [exportContentType],
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .failure(let error):
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                exportAlert = .exportFailed(error)
            }
            exportDocument = nil
        } onCancellation: {
            exportDocument = nil
        }
        .dataTransferAlert($exportAlert)
    }

    private var libraryCard: some View {
        Card("Library Entries") {
            RowGroup(.divider) {
                pickerRow(
                    "doc.text",
                    "Format",
                    LibraryExportFormat.allCases.map(\.rawValue),
                    Binding(
                        get: { libraryFormat.rawValue },
                        set: {
                            libraryFormat =
                                LibraryExportFormat(rawValue: $0) ?? .simplified
                        }
                    )
                )
                multiPickerRow(
                    "line.3.horizontal.decrease",
                    "Include",
                    LibraryExportFilter.allCases.map(\.rawValue),
                    "All Entries",
                    $libraryFilters
                )
                multiPickerRow(
                    "storefront",
                    "Source",
                    sources.sorted { $0.displayOrder < $1.displayOrder }
                        .map(\.source),
                    "All Sources",
                    $librarySources
                )
            }

            Divider()
                .padding(.leading, 16)

            InformationRow(
                blocks: [
                    .text(
                        libraryFormat == .detailed
                            ? "Exports each entry with its source, category, food group, serving details, notes and favorite status, along with each recipe's ingredients. Import the file to restore it."
                            : "Exports each entry's source, name, macros per serving, type, category, food group and note, one row per entry. Recipes are included with their totals but without ingredients."
                    ),
                    .bullets([
                        countLabel(filteredFoods.count, "entry", "entries"),
                        countLabel(
                            filteredFoods.filter { $0.type == .recipe }.count,
                            "recipe",
                            "recipes"
                        ),
                    ]),
                    .title("Columns"),
                    .code(
                        (libraryFormat == .detailed
                            ? LibraryCSV.Column.allCases.map(\.rawValue)
                            : LibraryCSV.simplifiedHeader)
                            .joined(separator: "\n")
                    ),
                ]
            )

            exportButton(
                kind: .library,
                title: "Export CSV File",
                emptyTitle: foodItems.isEmpty
                    ? "Library Is Empty" : "No Matching Entries",
                isEmpty: filteredFoods.isEmpty,
                loadingTitle: "Creating CSV..."
            ) {
                let foods = filteredFoods
                let csv =
                    libraryFormat == .detailed
                    ? LibraryCSV.export(foods)
                    : LibraryCSV.exportSimplified(foods)
                let suffix =
                    libraryFormat == .simplified ? " (Simplified)" : ""
                return (
                    ExportDocument(data: Data(csv.utf8)),
                    .commaSeparatedText,
                    "Macro Library \(dateStamp)\(suffix)"
                )
            }
        }
        .animation(.snappy, value: libraryFormat)
    }

    private var logCard: some View {
        Card("Log History") {
            RowGroup(.divider) {
                pickerRow(
                    "calendar",
                    "Range",
                    LogExportRange.allCases.map(\.rawValue),
                    Binding(
                        get: { logRange.rawValue },
                        set: {
                            logRange = LogExportRange(rawValue: $0) ?? .allTime
                        }
                    )
                )

                if logRange == .custom {
                    BaseRowLayout(
                        icon: .customSymbol("calendar.badge.clock"),
                        title: "From"
                    ) {
                        DateTimePill(selection: $customStart, components: .date)
                            .padding(.trailing, -5)
                            .padding(.vertical, -2)
                    }
                    BaseRowLayout(
                        icon: .customSymbol("calendar.badge.checkmark"),
                        title: "To"
                    ) {
                        DateTimePill(selection: $customEnd, components: .date)
                            .padding(.trailing, -5)
                            .padding(.vertical, -2)
                    }
                }
            }

            Divider()
                .padding(.leading, 16)

            InformationRow(
                blocks: [
                    .text(
                        "Exports each logged meal with its date, portion, macros, source, category, location and note, along with the ingredients of logged recipes. Photos are only included in a full backup."
                    ),
                    .bullets([countLabel(filteredLogs.count, "log", "logs")]),
                    .title("Columns"),
                    .code(
                        LogCSV.exportedColumns.map(\.rawValue)
                            .joined(separator: "\n")
                    ),
                ]
            )

            exportButton(
                kind: .logs,
                title: "Export CSV File",
                emptyTitle: loggedEntries.isEmpty
                    ? "No Logs Yet" : "No Logs in Range",
                isEmpty: filteredLogs.isEmpty,
                loadingTitle: "Creating CSV..."
            ) {
                let logs = filteredLogs
                let suffix =
                    logRange == .allTime ? "" : " (\(logRange.rawValue))"
                return (
                    ExportDocument(data: Data(LogCSV.export(logs).utf8)),
                    .commaSeparatedText,
                    "Macro Logs \(dateStamp)\(suffix)"
                )
            }
        }
        .animation(.snappy, value: logRange)
    }

    private var backupCard: some View {
        Card("Full Backup") {
            ToggleRow(
                icon: .customSymbol("photo.on.rectangle"),
                title: "Include Photos",
                isOn: $includePhotos
            )

            Divider()
                .padding(.leading, 16)

            InformationRow(
                blocks: [
                    .text(
                        includePhotos
                            ? "Saves everything in Macro to a single file: your library, logs with their photos and framing, goals, settings, favorites, drafts and custom lists. Restore it from Import on this or another device."
                            : "Saves everything in Macro to a single file except photos: your library, logs, goals, settings, favorites, drafts and custom lists. Restore it from Import on this or another device."
                    ),
                    .bullets([
                        countLabel(
                            foodItems.count,
                            "library entry",
                            "library entries"
                        ),
                        countLabel(loggedEntries.count, "log", "logs"),
                        includePhotos
                            ? countLabel(photoCount, "photo", "photos")
                            : "Photos excluded",
                        countLabel(goalCount, "goal", "goals"),
                    ]),
                ]
            )

            exportButton(
                kind: .backup,
                title: "Export Backup",
                emptyTitle: "",
                isEmpty: false,
                loadingTitle: "Creating Backup..."
            ) {
                var backup = try MacroBackup.make(from: modelContext)
                if !includePhotos {
                    backup.logs = backup.logs.map(Self.strippingPhotos)
                    backup.drafts = backup.drafts.map {
                        var draft = $0
                        draft.photos = []
                        return draft
                    }
                }

                let data = try await Task.detached(priority: .userInitiated) {
                    try MacroBackup.encode(backup)
                }.value

                return (
                    ExportDocument(data: data),
                    .json,
                    "Macro Backup \(dateStamp)"
                )
            }
        }
    }

    nonisolated private static func strippingPhotos(_ log: MacroBackup.LogRecord)
        -> MacroBackup.LogRecord
    {
        var log = log
        log.photos = []
        log.children = log.children.map(strippingPhotos)
        return log
    }

    private func pickerRow(
        _ symbol: String,
        _ title: String,
        _ options: [String],
        _ selection: Binding<String>
    ) -> some View {
        BaseRowLayout(icon: .customSymbol(symbol), title: title) {
            DropdownPill(
                options: options,
                displayCustomOption: false,
                selection: selection
            )
        }
    }

    private func multiPickerRow(
        _ symbol: String,
        _ title: String,
        _ options: [String],
        _ allLabel: String,
        _ selection: Binding<Set<String>>
    ) -> some View {
        BaseRowLayout(icon: .customSymbol(symbol), title: title) {
            MultiDropdownPill(
                options: options,
                allLabel: allLabel,
                selection: selection
            )
        }
    }

    @ViewBuilder
    private func exportButton(
        kind: DataTransferKind,
        title: String,
        emptyTitle: String,
        isEmpty: Bool,
        loadingTitle: String,
        prepare: @escaping () async throws -> PreparedExport
    ) -> some View {
        ZStack {
            if loadingKind == kind {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.blue)
                    Text(loadingTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 9)
                .frame(height: 60)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                ButtonRow(
                    icon: .customSymbol(
                        isEmpty ? "tray" : "square.and.arrow.up.fill",
                        tint: isEmpty ? .secondary : .white
                    ),
                    title: isEmpty ? emptyTitle : title,
                    tint: isEmpty ? Color.gray.opacity(0.1) : .blue,
                    textColor: isEmpty ? .secondary : .white,
                    topPadding: 8
                ) {
                    startExport(kind: kind, prepare: prepare)
                }
                .disabled(isEmpty || loadingKind != nil)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.snappy, value: loadingKind)
    }

    private func startExport(
        kind: DataTransferKind,
        prepare: @escaping () async throws -> PreparedExport
    ) {
        loadingKind = kind

        Task(priority: .userInitiated) {
            try? await Task.sleep(for: .seconds(1))

            do {
                let prepared = try await prepare()
                withAnimation(.snappy) { loadingKind = nil }
                exportDocument = prepared.document
                exportContentType = prepared.type
                exportFilename = prepared.filename
                isShowingExporter = true
            } catch {
                withAnimation(.snappy) { loadingKind = nil }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                exportAlert = DataTransferAlert(
                    title: "Export Failed",
                    message:
                        "Your data couldn't be prepared for export. \(error.localizedDescription)"
                )
            }
        }
    }

    private func countLabel(_ count: Int, _ singular: String, _ plural: String)
        -> String
    {
        "\(count) \(count == 1 ? singular : plural)"
    }
}

#Preview {
    NavigationStack {
        ExportView()
    }
}
