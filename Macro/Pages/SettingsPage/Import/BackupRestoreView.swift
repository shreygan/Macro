//
//  BackupRestoreView.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import SwiftData
import SwiftUI

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.dismissSettings) private var dismissSettings
    @Environment(\.replaceAllData) private var replaceAllData
    @Environment(CloudSyncMonitor.self) private var syncMonitor
    @Environment(CloudBackupStore.self) private var backupStore

    let file: MacroBackupFile

    @State private var mode: BackupRestoreMode

    private var backup: MacroBackup { file.backup }

    init(file: MacroBackupFile, defaultMode: BackupRestoreMode = .merge) {
        self.file = file
        _mode = State(initialValue: defaultMode)
    }
    @State private var isRestoring = false
    @State private var showReplaceConfirmation = false
    @State private var restoreAlert: DataTransferAlert?
    @State private var pendingRestore: PendingBackupFollowUp?

    private var modeSelection: Binding<String> {
        Binding(
            get: { mode.rawValue },
            set: { mode = BackupRestoreMode(rawValue: $0) ?? .merge }
        )
    }

    private var modeInfo: String {
        switch (mode, syncMonitor.hasAccess) {
        case (.merge, true):
            return "Adds everything from the backup that isn't already in Macro. Your existing entries, logs, goals and settings are kept as they are, and the changes sync to your other devices."
        case (.merge, false):
            return "Adds everything from the backup that isn't already in Macro. Your existing entries, logs, goals and settings are kept as they are."
        case (.replace, true):
            return "Erases all data on all your devices and iCloud, then restores the backup exactly, including settings and list order."
        case (.replace, false):
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
                            contentRow(AppSymbols.recipe.rawValue, "Recipes", "\(backup.recipeCount)")
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
                            if isRestoring || backupStore.isBackingUp {
                                TransferStatus(
                                    title: backupStore.isBackingUp
                                        ? backupStore.progressTitle
                                        : String(localized: "Restoring Backup..."),
                                    onCancel: backupStore.canCancelBackup ? { backupStore.cancelBackup() } : nil
                                )
                                .frame(height: 36)
                                .padding(.bottom, 16)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else if syncMonitor.isInitialRestoreInProgress {
                                ButtonRow.restoreInProgress(topPadding: 0)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                ButtonRow(
                                    icon: .customSymbol(
                                        "arrow.counterclockwise.circle.fill",
                                        tint: mode == .replace ? .red : .white
                                    ),
                                    title: mode == .replace ? "Erase and Restore" : "Restore Backup",
                                    tint: mode == .replace ? .destructiveFill : .accentColor,
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
                        .animation(.snappy, value: backupStore.isBackingUp)
                        .animation(.snappy, value: syncMonitor.isInitialRestoreInProgress)
                        .animation(.snappy, value: backupStore.progressTitle)
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
            if syncMonitor.canReachICloud && !backupStore.knownFull {
                Button("Back Up & Restore") {
                    backUpAndReplace()
                }
            }
            Button("Erase and Restore", role: .destructive) {
                guard !backupStore.isBackingUp else {
                    restoreAlert = .backupInProgress
                    return
                }
                dismissSettings()
                replaceAllData(file)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                syncMonitor.hasAccess
                    ? "Everything currently in Macro, on all your devices and in iCloud, will be replaced with the contents of this backup. This can't be undone."
                    : "Everything currently in Macro on this device will be replaced with the contents of this backup. This can't be undone."
            )
        }
        .dataTransferAlert($restoreAlert)
        .onLeave { cancelPendingRestore() }
    }

    private func contentRow(_ symbol: String, _ title: String, _ value: String)
        -> some View
    {
        BaseRowLayout(icon: .customSymbol(symbol), title: title, fitsRightContent: true) {
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func backUpAndReplace() {
        guard !isRestoring, !backupStore.isBackingUp else { return }
        let followUp = PendingBackupFollowUp()
        pendingRestore = followUp

        Task {
            defer { if pendingRestore === followUp { pendingRestore = nil } }
            do {
                try await backupStore.backUpIfRoom(from: modelContext)
                guard !followUp.isCancelled else {
                    toastCenter?.show(.backupComplete)
                    return
                }
                dismissSettings()
                replaceAllData(file)
            } catch is CancellationError {
                return
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                guard !followUp.isCancelled else {
                    toastCenter?.show(.failure(String(localized: "Backup Failed"), message: syncMonitor.message(for: error)))
                    return
                }
                restoreAlert = DataTransferAlert(
                    title: "Backup Failed",
                    message: "Nothing was erased. \(syncMonitor.message(for: error))"
                )
            }
        }
    }

    private func cancelPendingRestore() {
        guard let pendingRestore, !pendingRestore.isCancelled else { return }
        pendingRestore.isCancelled = true
        self.pendingRestore = nil
        toastCenter?.show(.backupContinues(String(localized: "Nothing will be erased or restored")))
    }

    private func restore() {
        guard !isRestoring, !backupStore.isBackingUp else { return }
        isRestoring = true
        AutomaticBackup.isDataChangeInProgress = true

        Task(priority: .userInitiated) {
            defer { AutomaticBackup.isDataChangeInProgress = false }
            try? await Task.sleep(for: .seconds(1))

            do {
                let result = try await BackupRestorer(context: modelContext)
                    .restore(file, mode: .merge)
                file.remove()
                Task { await PendingLocationNamer.run(in: modelContext) }
                isRestoring = false
                toastCenter?.show(.backupRestored(result))
                dismissSettings()
            } catch {
                withAnimation(.snappy) { isRestoring = false }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                restoreAlert = DataTransferAlert(
                    title: "Restore Failed",
                    message: error is BackupRestoreError
                        ? error.localizedDescription
                        : "The backup couldn't be restored and your existing data was left in place. \(error.localizedDescription)"
                )
            }
        }
    }
}

extension Toast {
    static func backupRestored(_ summary: BackupRestoreSummary) -> Toast {
        if summary.photosIncomplete {
            return Toast(
                group: Toast.dataTransferGroup,
                kind: .warning,
                symbol: "exclamationmark.triangle",
                title: String(localized: "Restored Without Some Photos"),
                message: String(localized: "Some photos couldn't be added")
            )
        }
        return Toast(
            group: Toast.dataTransferGroup,
            kind: .success,
            symbol: "checkmark",
            title: summary.message == nil
                ? String(localized: "Already Up to Date")
                : String(localized: "Backup Restored"),
            message: summary.message
                ?? String(localized: "Nothing new in this backup")
        )
    }
}
