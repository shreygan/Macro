//
//  SettingsView.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import SwiftData
import SwiftUI

extension EnvironmentValues {
    @Entry var dismissSettings: () -> Void = {}
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.eraseAllData) private var eraseAllData
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CloudSyncMonitor.self) private var syncMonitor
    @Environment(CloudBackupStore.self) private var backupStore

    @Query private var users: [User]

    @State private var showDeleteConfirmation = false
    @State private var backupAlert: DataTransferAlert?
    @State private var pendingErase: PendingBackupFollowUp?
    @AppStorage(AutomaticBackup.enabledKey) private var isAutomaticBackupOn = false

    private let maxDayStartMinutes = 12 * 60

    private static let weeklyBackupWarningAge: TimeInterval = 14 * 24 * 60 * 60

    private var iCloudRowStatus: (symbol: String, subtitle: String?) {
        if syncMonitor.isInitialRestoreInProgress {
            return ("icloud.and.arrow.down", String(localized: "Restoring from iCloud..."))
        }
        switch syncMonitor.account {
        case .noAccount: return ("icloud.slash", String(localized: "No iCloud Access"))
        case .restricted: return ("icloud.slash", String(localized: "iCloud Restricted"))
        default: break
        }
        switch syncMonitor.issue {
        case .storageFull: return ("exclamationmark.icloud", String(localized: "iCloud Storage Full"))
        case .noAccess, .notSignedIn: return ("icloud.slash", String(localized: "No iCloud Access"))
        case .other: return ("exclamationmark.icloud", String(localized: "Couldn't Sync"))
        case .offline, nil: break
        }
        if isAutomaticBackupOn,
            let reference = AutomaticBackup.lastBackupOrEnabledDate,
            Date().timeIntervalSince(reference) > Self.weeklyBackupWarningAge
        {
            let subtitle = AutomaticBackup.lastBackup.map {
                String(localized: "Last weekly backup \($0.formatted(.relative(presentation: .named)))")
            } ?? String(localized: "No weekly backup yet")
            return ("exclamationmark.icloud", subtitle)
        }
        return ("icloud", nil)
    }

    private var isWaitingForProfile: Bool {
        syncMonitor.isInitialRestoreInProgress && users.isEmpty
    }

    private var dayStartRange: ClosedRange<Date> {
        let midnight = Calendar.current.startOfDay(for: Date())
        let latest =
            Calendar.current.date(
                byAdding: .minute,
                value: maxDayStartMinutes,
                to: midnight
            ) ?? midnight
        return midnight...latest
    }

    private var dayStartSelection: Binding<Date> {
        Binding(
            get: {
                let midnight = dayStartRange.lowerBound
                return Calendar.current.date(
                    byAdding: .minute,
                    value: users.first?.dayStartMinutes ?? 0,
                    to: midnight
                ) ?? midnight
            },
            set: { newValue in
                guard let user = users.first else { return }
                let components = Calendar.current.dateComponents(
                    [.hour, .minute],
                    from: newValue
                )
                let minutes =
                    (components.hour ?? 0) * 60 + (components.minute ?? 0)
                user.dayStartMinutes = min(minutes, maxDayStartMinutes)
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    toastCenter?.show(.failure(String(localized: "Couldn't Save Day Start")))
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Card("Goals") {
                            RowGroup(.divider) {
                                NavigationLink {
                                    GoalSetupView(
                                        isCalorieActive: .constant(false),
                                        isProteinActive: .constant(false),
                                        isCarbsActive: .constant(false),
                                        isFatActive: .constant(false),
                                        isFiberActive: .constant(false)
                                    )
                                } label: {
                                    NavigationRow(
                                        icon: .customSymbol("target"),
                                        title: "Macro Goals",
                                        subtitle: isWaitingForProfile
                                            ? String(localized: "Restore in Progress") : nil
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isWaitingForProfile)

                                if let user = users.first {
                                    NavigationLink {
                                        GoalHistoryView(user: user)
                                    } label: {
                                        NavigationRow(
                                            icon: .customSymbol(
                                                "clock.arrow.circlepath"
                                            ),
                                            title: "Goal History"
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)

                        if let user = users.first {
                            Card("Tracking") {
                                RowGroup(.divider) {
                                    BaseRowLayout(
                                        icon: .customSymbol("sunrise"),
                                        title: "Day Starts At",
                                        info:
                                            "Meals logged before this time count toward the previous day."
                                    ) {
                                        DateTimePill(
                                            selection: dayStartSelection,
                                            components: .hourAndMinute,
                                            range: dayStartRange
                                        )
                                        .padding(.trailing, -5)
                                    }

                                    NavigationLink {
                                        DayCirclesView(user: user)
                                    } label: {
                                        NavigationRow(
                                            icon: .customSymbol(
                                                "circle.bottomhalf.filled"
                                            ),
                                            title: "Day Circles"
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    NavigationLink {
                                        HydrationSettingsView(user: user)
                                    } label: {
                                        NavigationRow(
                                            icon: .customSymbol("drop"),
                                            title: "Hydration",
                                            subtitle: user.tracksHydration
                                                ? nil : String(localized: "Off")
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding([.top, .leading, .trailing])
                        }

                        Card("Data") {
                            RowGroup(.divider) {
                                NavigationLink {
                                    ICloudView()
                                } label: {
                                    NavigationRow(
                                        icon: .customSymbol(iCloudRowStatus.symbol),
                                        title: "iCloud",
                                        subtitle: iCloudRowStatus.subtitle
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    ImportView()
                                } label: {
                                    NavigationRow(
                                        icon: .customSymbol(
                                            "square.and.arrow.down"
                                        ),
                                        title: "Import"
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    ExportView()
                                } label: {
                                    NavigationRow(
                                        icon: .customSymbol(
                                            "square.and.arrow.up"
                                        ),
                                        title: "Export"
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    StorageView()
                                } label: {
                                    NavigationRow(
                                        icon: .customSymbol("internaldrive"),
                                        title: "Storage"
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Card("Reset") {
                            InformationRow(
                                description: syncMonitor.hasAccess
                                    ? "Permanently removes all logged entries, saved foods, goals, locations and personal data from all your devices and iCloud. Any iCloud backups are kept. This action cannot be undone."
                                    : "Permanently removes all logged entries, saved foods, goals, locations and personal data from this device. Any iCloud backups are kept. This action cannot be undone."
                            )

                            ZStack {
                                if backupStore.isBackingUp {
                                    TransferStatus(
                                        title: backupStore.progressTitle,
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
                                        icon: .customSymbol("trash", tint: .red),
                                        title: "Delete All Data",
                                        tint: .destructiveFill,
                                        textColor: .red,
                                        topPadding: 0
                                    ) {
                                        showDeleteConfirmation = true
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                }
                            }
                            .animation(.snappy, value: backupStore.isBackingUp)
                            .animation(.snappy, value: backupStore.progressTitle)
                            .animation(.snappy, value: syncMonitor.isInitialRestoreInProgress)
                        }
                        .padding([.top, .horizontal])
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await syncMonitor.recheckAccess()
            }
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
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                if syncMonitor.canReachICloud && !backupStore.knownFull {
                    Button("Back Up & Delete") {
                        backUpAndErase()
                    }
                }
                Button("Delete", role: .destructive) {
                    guard !backupStore.isBackingUp else {
                        backupAlert = .backupInProgress
                        return
                    }
                    dismiss()
                    eraseAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    syncMonitor.hasAccess
                        ? "This will permanently delete all your logged entries, saved foods, and personal data from all your devices and iCloud. Any iCloud backups you have are kept. This action cannot be undone."
                        : "This will permanently delete all your logged entries, saved foods, and personal data from this device. Any iCloud backups you have are kept. This action cannot be undone."
                )
            }
            .dataTransferAlert($backupAlert)
            .onLeave { cancelPendingErase() }
        }
        .environment(\.dismissSettings, { dismiss() })
    }

    private func backUpAndErase() {
        guard !backupStore.isBackingUp else { return }
        let followUp = PendingBackupFollowUp()
        pendingErase = followUp

        Task {
            defer { if pendingErase === followUp { pendingErase = nil } }
            do {
                try await backupStore.backUpIfRoom(from: modelContext)
                guard !followUp.isCancelled else {
                    toastCenter?.show(.backupComplete)
                    return
                }
                dismiss()
                eraseAllData()
            } catch is CancellationError {
                return
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                guard !followUp.isCancelled else {
                    toastCenter?.show(.failure(String(localized: "Backup Failed"), message: syncMonitor.message(for: error)))
                    return
                }
                backupAlert = DataTransferAlert(
                    title: "Backup Failed",
                    message: "Nothing was deleted. \(syncMonitor.message(for: error))"
                )
            }
        }
    }

    private func cancelPendingErase() {
        guard let pendingErase, !pendingErase.isCancelled else { return }
        pendingErase.isCancelled = true
        self.pendingErase = nil
        toastCenter?.show(.backupContinues(String(localized: "Nothing will be deleted")))
    }
}

#Preview {
    SettingsView()
        .environment(CloudSyncMonitor())
        .environment(CloudBackupStore())
}
