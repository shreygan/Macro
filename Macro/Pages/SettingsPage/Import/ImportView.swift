//
//  ImportView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/28/26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum DataTransferKind {
    case library
    case logs
    case backup
}

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingFilePicker = false
    @State private var pickerKind: DataTransferKind = .library
    @State private var loadingKind: DataTransferKind?

    @State private var parsedItems: [DraftFoodItem] = []
    @State private var libraryIssues: [ImportIssue] = []
    @State private var showLibraryReview = false

    @State private var parsedLogs: [DraftLogEntry] = []
    @State private var logIssues: [ImportIssue] = []
    @State private var showLogReview = false

    @State private var loadedBackup: MacroBackup?
    @State private var showBackupRestore = false

    @State private var importAlert: DataTransferAlert?

    private var isLoadingBinding: Binding<Bool> {
        Binding(
            get: { loadingKind != nil },
            set: { if !$0 { loadingKind = nil } }
        )
    }

    private var isShowingDestination: Bool {
        showLibraryReview || showLogReview || showBackupRestore
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Card("Library Entries") {
                        InformationRow(
                            blocks: [
                                .text(
                                    "Re-import a library CSV exported from Macro to restore every detail, including recipes and their ingredients."
                                ),
                                .text(
                                    "You can also import your own CSV. Its first row should name the columns, in any order. Rows missing a name or with invalid numbers are skipped."
                                ),
                                .title("Required Columns"),
                                .code(
                                    LibraryCSV.requiredColumns.map(\.rawValue)
                                        .joined(separator: "\n")
                                ),
                                .title("Optional Columns"),
                                .text(
                                    "Include any of these to add more detail. Other columns are ignored."
                                ),
                                .code(
                                    LibraryCSV.optionalColumns.map(\.rawValue)
                                        .joined(separator: "\n")
                                ),
                            ]
                        )

                        importButton(
                            kind: .library,
                            title: "Select CSV File",
                            loadingTitle: "Reading CSV..."
                        )
                    }
                    .padding(.horizontal)

                    Card("Log History") {
                        InformationRow(
                            blocks: [
                                .text(
                                    "Re-import a log history CSV exported from Macro to restore every detail, including logged recipes and their ingredients."
                                ),
                                .text(
                                    "You can also import your own CSV. Its first row should name the columns, in any order. Logs are linked to matching foods in your library when possible."
                                ),
                                .title("Required Columns"),
                                .code(
                                    LogCSV.requiredColumns.map(\.rawValue)
                                        .joined(separator: "\n")
                                ),
                                .text(
                                    "Dates can be written like \"2026-09-30 13:45\" and are read in your time zone. The time can also go in its own Time column."
                                ),
                                .title("Optional Columns"),
                                .text(
                                    "Include any of these to add more detail. Other columns are ignored."
                                ),
                                .code(
                                    LogCSV.optionalColumns.map(\.rawValue)
                                        .joined(separator: "\n")
                                ),
                            ]
                        )

                        importButton(
                            kind: .logs,
                            title: "Select CSV File",
                            loadingTitle: "Reading CSV..."
                        )
                    }
                    .padding([.top, .horizontal])

                    Card("Full Backup") {
                        InformationRow(
                            description:
                                "Restores a backup created with Export › Full Backup, including logs with their photos, goals, settings, favorites and custom lists. You can merge it with your current data or replace everything."
                        )

                        importButton(
                            kind: .backup,
                            title: "Select Backup File",
                            loadingTitle: "Reading Backup..."
                        )
                    }
                    .padding([.top, .horizontal])
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: pickerKind == .backup
                ? [.json] : [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let fileURL = urls.first else { return }
                processFile(at: fileURL, kind: pickerKind)
            case .failure(let error):
                importAlert = .selectionFailed(error)
            }
        }
        .dataTransferAlert($importAlert, isEnabled: !isShowingDestination)
        .navigationDestination(isPresented: $showLibraryReview) {
            ImportReviewView(
                items: $parsedItems,
                issues: $libraryIssues,
                isLoading: isLoadingBinding,
                importAlert: $importAlert,
                onProcessNewCSV: { url in
                    withAnimation(.snappy) { parsedItems = [] }
                    processFile(at: url, kind: .library)
                },
                onSaveComplete: { dismiss() }
            )
        }
        .navigationDestination(isPresented: $showLogReview) {
            LogImportReviewView(
                entries: $parsedLogs,
                issues: $logIssues,
                isLoading: isLoadingBinding,
                importAlert: $importAlert,
                onProcessNewCSV: { url in
                    withAnimation(.snappy) { parsedLogs = [] }
                    processFile(at: url, kind: .logs)
                },
                onSaveComplete: { dismiss() }
            )
        }
        .navigationDestination(isPresented: $showBackupRestore) {
            if let loadedBackup {
                BackupRestoreView(backup: loadedBackup)
            }
        }
    }

    @ViewBuilder
    private func importButton(
        kind: DataTransferKind,
        title: String,
        loadingTitle: String
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
                        "tray.and.arrow.down.fill",
                        tint: .white
                    ),
                    title: title,
                    tint: .blue,
                    textColor: .white,
                    topPadding: 8
                ) {
                    pickerKind = kind
                    isShowingFilePicker = true
                }
                .disabled(loadingKind != nil)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.snappy, value: loadingKind)
    }

    private func processFile(at url: URL, kind: DataTransferKind) {
        let didAccess = url.startAccessingSecurityScopedResource()
        loadingKind = kind

        Task(priority: .userInitiated) {
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            try? await Task.sleep(for: .seconds(1))

            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                finish(with: didAccess ? .unreadable(error) : .accessDenied)
                return
            }

            guard !data.isEmpty else {
                finish(with: .emptyFile)
                return
            }

            if kind == .backup {
                await processBackup(data)
            } else {
                processCSV(data, pickedFrom: kind)
            }
        }
    }

    private func processBackup(_ data: Data) async {
        let backup: MacroBackup
        do {
            backup = try await Task.detached(priority: .userInitiated) {
                try MacroBackup.decode(data)
            }.value
        } catch {
            finish(with: .invalidBackup)
            return
        }

        guard backup.format == MacroBackup.formatIdentifier else {
            finish(with: .invalidBackup)
            return
        }
        guard backup.version <= MacroBackup.currentVersion else {
            finish(with: .newerBackup)
            return
        }

        withAnimation(.snappy) { loadingKind = nil }
        loadedBackup = backup
        showLibraryReview = false
        showLogReview = false
        showBackupRestore = true
    }

    private func processCSV(_ data: Data, pickedFrom kind: DataTransferKind) {
        guard let text = CSVCoder.decode(data) else {
            finish(with: .unsupportedEncoding)
            return
        }

        let rows = CSVCoder.parse(text)
        guard let header = rows.first else {
            finish(with: .emptyFile)
            return
        }

        let body = Array(rows.dropFirst())
        let logColumns = LogCSV.columns(forHeader: header.fields, rows: body)

        if kind == .logs {
            if let logColumns {
                processLogs(body, columns: logColumns)
            } else if LibraryCSV.looksLikeLibrary(header: header.fields) {
                processLibrary(rows)
            } else {
                finish(with: .missingDateColumn)
            }
        } else if let logColumns,
            LogCSV.containsLogRecords(body, columns: logColumns)
        {
            processLogs(body, columns: logColumns)
        } else {
            processLibrary(rows)
        }
    }

    private func processLogs(_ rows: [CSVRow], columns: [LogCSV.Column: Int]) {
        let existing =
            ((try? modelContext.fetch(
                FetchDescriptor<LoggedEntry>(
                    predicate: #Predicate { $0.parentEntry == nil }
                )
            )) ?? [])
            .map {
                LogCSV.ExistingLog(id: $0.id, name: $0.name, timestamp: $0.timestamp)
            }

        let result = LogCSV.parse(rows: rows, columns: columns, existing: existing)

        guard !result.entries.isEmpty || !result.issues.isEmpty else {
            finish(with: .noEntries)
            return
        }

        withAnimation(.snappy) {
            loadingKind = nil
            logIssues = result.issues
            parsedLogs = result.entries
        }
        showLibraryReview = false
        showLogReview = true
    }

    private func processLibrary(_ rows: [CSVRow]) {
        let existingItems =
            (try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? []
        let existingIDs = Set(existingItems.map(\.id))
        var existingKeys: [String: UUID] = [:]
        for item in existingItems {
            let key = LibraryCSV.lookupKey(
                source: item.source?.source ?? "",
                name: item.name
            )
            if existingKeys[key] == nil { existingKeys[key] = item.id }
        }

        let result: LibraryCSV.ParseResult
        if let header = rows.first,
            let columns = LibraryCSV.columns(
                forHeader: header.fields,
                rows: Array(rows.dropFirst())
            )
        {
            result = LibraryCSV.parse(
                rows: Array(rows.dropFirst()),
                columns: columns,
                existingIDs: existingIDs,
                existingKeys: existingKeys
            )
        } else {
            result = LibraryCSV.parseSimplified(
                rows: rows,
                existingKeys: existingKeys
            )

            if result.items.isEmpty && result.duplicateCount == 0
                && result.invalidCount == rows.count
            {
                finish(with: .unrecognizedFormat)
                return
            }
        }

        guard !result.items.isEmpty || !result.issues.isEmpty else {
            finish(with: .noEntries)
            return
        }

        withAnimation(.snappy) {
            loadingKind = nil
            libraryIssues = result.issues
            parsedItems = result.items
        }
        showLogReview = false
        showLibraryReview = true
    }

    private func finish(with alert: DataTransferAlert) {
        withAnimation(.snappy) {
            loadingKind = nil
            if showLibraryReview { libraryIssues = [] }
            if showLogReview { logIssues = [] }
        }
        importAlert = alert
    }
}

#Preview {
    NavigationStack {
        ImportView()
    }
}
