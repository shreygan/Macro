//
//  BackupRestoreView.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.dismissSettings) private var dismissSettings

    let backup: MacroBackup

    @State private var mode: BackupRestoreMode = .merge
    @State private var isRestoring = false
    @State private var showReplaceConfirmation = false
    @State private var restoreAlert: DataTransferAlert?
    @State private var unrecoveredError: BackupRestoreError?
    @State private var snapshotDocument: ExportDocument?
    @State private var isShowingSnapshotExporter = false

    private var modeSelection: Binding<String> {
        Binding(
            get: { mode.rawValue },
            set: { mode = BackupRestoreMode(rawValue: $0) ?? .merge }
        )
    }

    private var modeInfo: String {
        switch mode {
        case .merge:
            return "Adds everything from the backup that isn't already on this device. Your existing entries, logs, goals and settings are kept as they are."
        case .replace:
            return "Erases all data on this device, then restores the backup exactly, including settings and list order."
        }
    }

    private var logCount: Int {
        backup.logs.count
    }

    private func countLabel(_ count: Int, _ singular: String, _ plural: String)
        -> String
    {
        "\(count) \(count == 1 ? singular : plural)"
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Card("Backup Contents") {
                        RowGroup(.divider) {
                            contentRow("calendar", "Created", backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                            contentRow("books.vertical", "Library Entries", "\(backup.foods.count)")
                            contentRow("fork.knife", "Recipes", "\(backup.recipeCount)")
                            contentRow("list.bullet.rectangle", "Logs", "\(logCount)")
                            contentRow("photo.on.rectangle", "Photos", "\(backup.photoCount)")
                            contentRow("target", "Goals", "\(backup.goals.count)")
                            contentRow("star", "Favorites", "\(backup.favorites.count)")
                            contentRow("tag", "Custom List Items", "\(backup.customListCount)")
                            if !backup.drafts.isEmpty {
                                contentRow("square.and.pencil", "Drafts", "\(backup.drafts.count)")
                            }
                        }
                    }
                    .padding(.horizontal)

                    Card("Restore") {
                        BaseRowLayout(
                            icon: .customSymbol("arrow.triangle.2.circlepath"),
                            title: "Mode"
                        ) {
                            DropdownPill(
                                options: BackupRestoreMode.allCases.map(\.rawValue),
                                displayCustomOption: false,
                                selection: modeSelection
                            )
                        }

                        Divider()
                            .padding(.leading, 16)

                        InformationRow(description: modeInfo)

                        ZStack {
                            if isRestoring {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .tint(.blue)
                                    Text("Restoring Backup...")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.bottom, 9)
                                .frame(height: 60)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                ButtonRow(
                                    icon: .customSymbol(
                                        "arrow.counterclockwise.circle.fill",
                                        tint: mode == .replace ? .red : .white
                                    ),
                                    title: mode == .replace ? "Erase and Restore" : "Restore Backup",
                                    tint: mode == .replace ? .red.opacity(0.1) : .blue,
                                    textColor: mode == .replace ? .red : .white,
                                    topPadding: 0
                                ) {
                                    if mode == .replace {
                                        showReplaceConfirmation = true
                                    } else {
                                        restore()
                                    }
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                        .animation(.snappy, value: isRestoring)
                    }
                    .padding([.top, .horizontal])
                }
                .padding(.bottom)
            }
            .withCustomKeyboardToolbar()
        }
        .navigationTitle("Restore Backup")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Erase All Data?", isPresented: $showReplaceConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Erase and Restore", role: .destructive) {
                restore()
            }
        } message: {
            Text(
                "Everything currently on this device will be replaced with the contents of this backup. This can't be undone."
            )
        }
        .dataTransferAlert($restoreAlert)
        .alert(
            "Restore Failed",
            isPresented: Binding(
                get: { unrecoveredError != nil },
                set: { if !$0 { unrecoveredError = nil } }
            ),
            presenting: unrecoveredError
        ) { error in
            Button("Save Previous Data") {
                saveSnapshot(from: error)
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .fileExporter(
            isPresented: $isShowingSnapshotExporter,
            item: snapshotDocument,
            contentTypes: [.json],
            defaultFilename: "Macro Previous Data \(Date().formatted(.iso8601.year().month().day()))"
        ) { result in
            snapshotDocument = nil
            if case .failure(let error) = result {
                restoreAlert = .exportFailed(error)
            }
        } onCancellation: {
            snapshotDocument = nil
        }
    }

    private func contentRow(_ symbol: String, _ title: String, _ value: String)
        -> some View
    {
        BaseRowLayout(icon: .customSymbol(symbol), title: title) {
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func saveSnapshot(from error: BackupRestoreError) {
        guard let url = error.snapshotURL,
            let data = try? Data(contentsOf: url)
        else {
            restoreAlert = DataTransferAlert(
                title: "Couldn't Save Copy",
                message: "The copy of your previous data is no longer available."
            )
            return
        }
        snapshotDocument = ExportDocument(data: data)
        isShowingSnapshotExporter = true
    }

    private func restore() {
        guard !isRestoring else { return }
        isRestoring = true
        let mode = mode

        Task(priority: .userInitiated) {
            try? await Task.sleep(for: .seconds(1))

            do {
                let result = try await BackupRestorer(context: modelContext)
                    .restore(backup, mode: mode)
                isRestoring = false
                toastCenter?.show(
                    Toast(
                        group: Toast.dataTransferGroup,
                        kind: .success,
                        symbol: "checkmark",
                        title: result.message == nil
                            ? String(localized: "Already Up to Date")
                            : String(localized: "Backup Restored"),
                        message: result.message
                            ?? String(localized: "Nothing new in this backup")
                    )
                )
                dismissSettings()
            } catch let error as BackupRestoreError {
                withAnimation(.snappy) { isRestoring = false }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                if error.snapshotURL != nil {
                    unrecoveredError = error
                } else {
                    restoreAlert = DataTransferAlert(
                        title: "Restore Failed",
                        message: error.localizedDescription
                    )
                }
            } catch {
                withAnimation(.snappy) { isRestoring = false }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                restoreAlert = DataTransferAlert(
                    title: "Restore Failed",
                    message:
                        "The backup couldn't be restored and your existing data was left in place. \(error.localizedDescription)"
                )
            }
        }
    }
}
