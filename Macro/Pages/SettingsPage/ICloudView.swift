//
//  ICloudView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/16/26.
//

import SwiftData
import SwiftUI

struct ICloudView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CloudSyncMonitor.self) private var syncMonitor
    @Environment(CloudBackupStore.self) private var backupStore

    @State private var busyBackupID: CloudBackup.ID?
    @State private var downloadTask: Task<Void, Never>?
    @State private var backupToDelete: CloudBackup?
    @State private var restoringBackup: MacroBackupFile?
    @State private var showBackupRestore = false
    @State private var alert: DataTransferAlert?
    @State private var savedBackupURL: URL?
    @State private var isShowingBackupSaver = false
    @AppStorage(AutomaticBackup.enabledKey) private var isAutomaticBackupOn = false
    @AppStorage(AutomaticBackup.lastFailureKey) private var lastAutomaticFailure = ""

    private var unavailableReason: String? {
        switch syncMonitor.account {
        case .available:
            switch syncMonitor.issue {
            case .noAccess, .notSignedIn: String(localized: "No iCloud Access")
            default:
                syncMonitor.hasCheckedAccess ? nil : String(localized: "Checking iCloud...")
            }
        case .checking: String(localized: "Checking iCloud...")
        case .noAccount: String(localized: "No iCloud Access")
        case .restricted: String(localized: "iCloud Restricted")
        case .temporarilyUnavailable, .unknown: String(localized: "iCloud Unavailable")
        }
    }

    private var isBusy: Bool {
        backupStore.isBackingUp || busyBackupID != nil
    }

    private var lastSynced: Date? {
        [syncMonitor.lastUpload, syncMonitor.lastDownload].compactMap(\.self).max()
    }

    private var statusSymbol: String {
        if !syncMonitor.account.isAvailable && syncMonitor.account != .checking {
            return "icloud.slash"
        }
        guard let issue = syncMonitor.issue else { return "icloud" }
        return issue.blocksSync ? "icloud.slash" : "exclamationmark.icloud"
    }

    private var statusText: String {
        switch syncMonitor.account {
        case .checking:
            return String(localized: "Checking...")
        case .available:
            if !syncMonitor.hasCheckedAccess && syncMonitor.issue == nil {
                return String(localized: "Checking...")
            }
            if syncMonitor.isSyncing { return String(localized: "Syncing...") }
            return syncMonitor.issue?.title ?? String(localized: "On")
        case .noAccount:
            return String(localized: "No iCloud Access")
        case .restricted:
            return String(localized: "Restricted")
        case .temporarilyUnavailable, .unknown:
            return String(localized: "Unavailable")
        }
    }

    private var statusInfo: String? {
        switch syncMonitor.account {
        case .checking:
            return nil
        case .noAccount:
            return String(localized: "Macro doesn't have access to iCloud. In the Settings app, make sure you're signed in to iCloud and that iCloud is turned on for Macro. Until then, your data is only stored on this device.")
        case .restricted:
            return String(localized: "iCloud is restricted on this device by Screen Time or device management. Your data is only stored on this device.")
        case .temporarilyUnavailable, .unknown:
            return String(localized: "iCloud can't be reached right now. Your changes are kept on this device and sync once it's available.")
        case .available:
            switch syncMonitor.issue {
            case nil:
                return nil
            case .storageFull:
                return String(localized: "Free up space or upgrade your iCloud storage. New changes are kept on this device until then.")
            case .offline:
                return String(localized: "Your changes are kept on this device and sync when you're back online.")
            case .notSignedIn, .noAccess:
                return String(localized: "Macro doesn't have access to iCloud. Turn on iCloud for Macro in the Settings app. Until then, your data is only stored on this device.")
            case .other(let message):
                return message
            }
        }
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    syncCard
                        .padding(.horizontal)

                    backupCard
                        .padding([.top, .horizontal])

                    weeklyBackupCard
                        .padding([.top, .horizontal])
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("iCloud")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await syncMonitor.recheckAccess()
        }
        .task(id: BackupLoadKey(unavailableReason: unavailableReason, accountGeneration: backupStore.accountGeneration)) {
            guard unavailableReason == nil else { return }
            await loadBackups()
        }
        .alert(
            "Delete Backup?",
            isPresented: Binding(
                get: { backupToDelete != nil },
                set: { if !$0 { backupToDelete = nil } }
            ),
            presenting: backupToDelete
        ) { backup in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                delete(backup)
            }
        } message: { backup in
            Text(
                "The backup from \(backup.createdAt.formatted(date: .abbreviated, time: .shortened)) will be removed from iCloud. This can't be undone."
            )
        }
        .onLeave { downloadTask?.cancel() }
        .fileMover(
            isPresented: $isShowingBackupSaver,
            file: savedBackupURL
        ) { result in
            switch result {
            case .success:
                toastCenter?.show(
                    Toast(
                        group: Toast.dataTransferGroup,
                        kind: .success,
                        symbol: "checkmark",
                        title: String(localized: "Backup Saved"),
                        message: savedBackupURL?.deletingPathExtension().lastPathComponent
                    )
                )
            case .failure(let error):
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                alert = .exportFailed(error)
            }
            removeSavedBackup()
        } onCancellation: {
            removeSavedBackup()
        }
        .dataTransferAlert($alert, isEnabled: !showBackupRestore)
        .navigationDestination(isPresented: $showBackupRestore) {
            if let restoringBackup {
                BackupRestoreView(file: restoringBackup, defaultMode: .replace)
            }
        }
    }

    private var syncCard: some View {
        Card("Sync") {
            RowGroup(.divider) {
                BaseRowLayout(
                    icon: .customSymbol(statusSymbol),
                    title: "Status",
                    info: statusInfo
                ) {
                    HStack(spacing: 8) {
                        if syncMonitor.isSyncing && syncMonitor.account.isAvailable {
                            ProgressView()
                                .controlSize(.small)
                                .transition(.opacity)
                        }
                        Text(statusText)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    .animation(.snappy, value: statusText)
                }

                BaseRowLayout(
                    icon: .customSymbol("clock.arrow.circlepath"),
                    title: "Last Synced"
                ) {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let text = lastSynced?.formatted(.relative(presentation: .named)) ?? String(localized: "Never")
                        Text(text)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: text)
                    }
                }
            }

            actionButton(
                symbol: "arrow.triangle.2.circlepath",
                title: "Sync Now",
                isLoading: syncMonitor.isManualSyncing,
                loadingTitle: String(localized: "Syncing..."),
                blockedReason: syncMonitor.isInitialRestoreInProgress
                    ? (String(localized: "Restore in Progress"), "icloud.and.arrow.down")
                    : nil
            ) {
                syncNow()
            }
        }
        .animation(.snappy, value: statusInfo)
    }

    private var totalBackupSize: String? {
        guard !backupStore.backups.isEmpty else { return nil }
        let total = backupStore.backups.reduce(Int64(0)) { $0 + $1.byteCount }
        return String(localized: "\(total.formatted(.byteCount(style: .file))) in iCloud")
    }

    private var manualBackups: [CloudBackup] {
        backupStore.backups.filter { !$0.isAutomatic }
    }

    private var weeklyBackup: CloudBackup? {
        backupStore.backups.first(where: \.isAutomatic)
    }

    private var isWeeklyUploading: Bool {
        backupStore.isBackingUp && backupStore.isAutomaticUpload
    }

    private var backupCard: some View {
        Card("Backups") {
            if !manualBackups.isEmpty {
                RowGroup(.divider) {
                    ForEach(manualBackups) { backup in
                        backupRow(backup)
                    }
                }

                Divider()
                    .padding(.leading, 16)
            } else if backupStore.isLoading && !backupStore.hasLoaded {
                BaseRowLayout(
                    icon: .customSymbol("archivebox"),
                    title: "Loading Backups"
                ) {
                    ProgressView()
                        .controlSize(.small)
                }

                Divider()
                    .padding(.leading, 16)
            }

            InformationRow(
                description:
                    "Saves a copy of everything in Macro to iCloud, including photos. Later changes and deletions don't affect it, so you can restore it if something goes wrong. You can keep up to \(CloudBackupStore.maxBackups) backups. Delete one to make room for a new one."
            )

            actionButton(
                symbol: "icloud.and.arrow.up.fill",
                title: "Back Up Now",
                isLoading: backupStore.isBackingUp && !backupStore.isAutomaticUpload,
                loadingTitle: backupStore.progressTitle,
                onCancel: backupStore.canCancelBackup ? { backupStore.cancelBackup() } : nil,
                isEnabled: busyBackupID == nil,
                blockedReason: syncMonitor.isInitialRestoreInProgress
                    ? (String(localized: "Restore in Progress"), "icloud.and.arrow.down")
                    : isWeeklyUploading
                    ? (String(localized: "Automatic Backup in Progress"), "calendar.badge.clock")
                    : backupStore.isFull
                        ? (String(localized: "Backups Full"), "archivebox")
                        : nil
            ) {
                backUp()
            }
        } headerAccessory: {
            if let totalBackupSize {
                Text(totalBackupSize)
                    .font(.subtitle)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .animation(.snappy, value: manualBackups)
        .animation(.snappy, value: totalBackupSize)
        .animation(.snappy, value: backupStore.hasLoaded)
    }

    private var weeklyToggleSubtitle: String {
        if isAutomaticBackupOn, !lastAutomaticFailure.isEmpty, !isWeeklyUploading {
            return String(localized: "Last attempt failed · \(lastAutomaticFailure)")
        }
        if isAutomaticBackupOn, weeklyBackup == nil, !isWeeklyUploading {
            return String(localized: "First backup runs while charging on Wi-Fi")
        }
        return String(localized: "On Wi-Fi while charging")
    }

    private var weeklyBackupCard: some View {
        Card("Automatic Backup") {
            ToggleRow(
                icon: .customSymbol("calendar.badge.clock"),
                title: "Back Up Weekly",
                subtitle: weeklyToggleSubtitle,
                animatesSubtitle: true,
                info: String(localized: "Keeps one backup that replaces itself about once a week, made by whichever of your devices is charging on Wi-Fi first. This setting applies to all your devices, and the backup doesn't count toward your \(CloudBackupStore.maxBackups) backups."),
                isOn: $isAutomaticBackupOn
            )
            .disabled(unavailableReason != nil && !isAutomaticBackupOn)

            if isWeeklyUploading {
                Divider()
                    .padding(.leading, 16)

                weeklyProgressRow
                    .transition(.opacity)
            } else if let weeklyBackup {
                Divider()
                    .padding(.leading, 16)

                backupRow(weeklyBackup)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: weeklyBackup)
        .animation(.snappy, value: isWeeklyUploading)
        .onChange(of: isAutomaticBackupOn) {
            AutomaticBackup.enabledDidChange()
        }
    }

    private var weeklyProgressRow: some View {
        let progress = backupStore.uploadProgress ?? 0
        let status = if !backupStore.canCancelBackup {
            String(localized: "Finishing...")
        } else if progress > 0 {
            String(localized: "Uploading... \(progress.formatted(.percent.precision(.fractionLength(0))))")
        } else {
            String(localized: "Preparing...")
        }

        return BaseRowLayout(
            icon: .customSymbol("archivebox"),
            title: "New Backup",
            subtitle: status,
            animatesSubtitle: true
        ) {
            TransferRowAccessory(
                progress: progress,
                onCancel: backupStore.canCancelBackup ? { backupStore.cancelBackup() } : nil
            )
            .animation(.snappy, value: backupStore.canCancelBackup)
        }
    }

    private func backupRow(_ backup: CloudBackup) -> some View {
        let downloadProgress = busyBackupID == backup.id && downloadTask != nil ? backupStore.downloadProgress : nil
        let details = [
            backup.logCount.map { String(AttributedString(localized: "^[\($0) log](inflect: true)").characters) },
            backup.photoCount.map { String(AttributedString(localized: "^[\($0) photo](inflect: true)").characters) },
            backup.byteCount.formatted(.byteCount(style: .file)),
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
        let subtitle = downloadProgress.map {
            $0 > 0
                ? String(localized: "Downloading... \($0.formatted(.percent.precision(.fractionLength(0))))")
                : String(localized: "Downloading...")
        } ?? details

        return BaseRowLayout(
            icon: .customSymbol("archivebox"),
            title: backup.createdAt.formatted(date: .abbreviated, time: .shortened),
            titleTag: deviceTag(for: backup),
            titleTagVariant: backup.isFromThisDevice ? .accent : .neutral,
            subtitle: subtitle,
            animatesSubtitle: true
        ) {
            if let downloadProgress {
                TransferRowAccessory(progress: downloadProgress) {
                    downloadTask?.cancel()
                }
            } else if busyBackupID == backup.id {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
                    .padding(.trailing, -6)
            } else {
                backupMenu(backup)
            }
        }
    }

    private func deviceTag(for backup: CloudBackup) -> String? {
        let model = UIDevice.current.model
        if backup.isFromThisDevice { return String(localized: "This \(model)") }
        guard let deviceModel = backup.deviceModel else { return nil }
        return deviceModel == model ? String(localized: "Other \(deviceModel)") : deviceModel
    }

    private func backupMenu(_ backup: CloudBackup) -> some View {
        Menu {
            Button("Restore", systemImage: "arrow.counterclockwise") {
                download(backup, then: .restore)
            }
            .disabled(syncMonitor.isInitialRestoreInProgress)

            Button("Save to Files", systemImage: "square.and.arrow.down") {
                download(backup, then: .saveToFiles)
            }

            Button("Delete", systemImage: "trash", role: .destructive) {
                backupToDelete = backup
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.menuIcon)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.controlFill))
        }
        .buttonStyle(.plain)
        .padding(.vertical, -2)
        .padding(.trailing, -6)
        .disabled(isBusy || unavailableReason != nil)
        .accessibilityLabel("Backup Options")
    }

    @ViewBuilder
    private func actionButton(
        symbol: String,
        title: String,
        isLoading: Bool,
        loadingTitle: String,
        onCancel: (() -> Void)? = nil,
        isEnabled: Bool = true,
        blockedReason: (title: String, symbol: String)? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let disabledReason = unavailableReason ?? blockedReason?.title
        let disabledSymbol = unavailableReason == nil ? blockedReason?.symbol : nil

        ZStack {
            if isLoading {
                TransferStatus(title: loadingTitle, onCancel: onCancel)
                    .padding(.bottom, 9)
                    .frame(height: 60)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if let disabledReason {
                ButtonRow(
                    icon: .customSymbol(disabledSymbol ?? "icloud.slash", tint: .secondary),
                    title: disabledReason,
                    tint: .controlFill,
                    textColor: .secondary,
                    topPadding: 8
                ) {}
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                ButtonRow(
                    icon: .customSymbol(symbol, tint: .white),
                    title: title,
                    tint: .accentColor,
                    textColor: .white,
                    topPadding: 8
                ) {
                    guard isEnabled, disabledReason == nil else { return }
                    action()
                }
                .allowsHitTesting(isEnabled)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.snappy, value: isLoading)
        .animation(.snappy, value: disabledReason)
        .animation(.snappy, value: loadingTitle)
    }

    private func loadBackups() async {
        do {
            try await backupStore.refresh()
        } catch {
            if syncMonitor.report(error)?.blocksSync == true { return }
            toastCenter?.show(
                .failure(
                    String(localized: "Couldn't Load Backups"),
                    message: message(for: error)
                )
            )
        }
    }

    private func message(for error: Error) -> String {
        syncMonitor.message(for: error)
    }

    private func syncNow() {
        guard !syncMonitor.isManualSyncing else { return }

        Task {
            let result = await syncMonitor.syncNow(in: modelContext)
            switch result {
            case .upToDate:
                toastCenter?.show(
                    Toast(
                        group: Toast.dataTransferGroup,
                        kind: .success,
                        symbol: "checkmark",
                        title: String(localized: "Up to Date"),
                        message: String(localized: "Everything on this device is in iCloud")
                    )
                )
            case .stillUploading:
                toastCenter?.show(
                    Toast(
                        group: Toast.dataTransferGroup,
                        kind: .info,
                        symbol: "icloud.and.arrow.up",
                        title: String(localized: "Still Syncing"),
                        message: String(localized: "Your changes will finish uploading in the background")
                    )
                )
            case .failed(let issue):
                toastCenter?.show(.failure(issue.title, message: issue.message))
            }
        }
    }

    private func backUp() {
        guard !isBusy, !backupStore.isFull else { return }

        Task {
            do {
                try await backupStore.backUp(from: modelContext)
                toastCenter?.show(
                    Toast(
                        group: Toast.dataTransferGroup,
                        kind: .success,
                        symbol: "checkmark",
                        title: String(localized: "Backup Complete"),
                        message: String(localized: "Saved to iCloud")
                    )
                )
            } catch is CancellationError {
                return
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                alert = DataTransferAlert(
                    title: "Backup Failed",
                    message:
                        "Your data couldn't be backed up to iCloud. \(message(for: error))"
                )
            }
        }
    }

    private func removeSavedBackup() {
        if let folder = savedBackupURL?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: folder)
        }
        savedBackupURL = nil
    }

    private enum DownloadPurpose {
        case restore
        case saveToFiles
    }

    private func download(_ backup: CloudBackup, then purpose: DownloadPurpose) {
        guard !isBusy else { return }
        busyBackupID = backup.id

        downloadTask = Task {
            defer {
                busyBackupID = nil
                downloadTask = nil
            }
            do {
                let downloaded = try await backupStore.download(backup)
                guard !Task.isCancelled else {
                    downloaded.remove()
                    return
                }
                if purpose == .saveToFiles {
                    let named = try MacroBackupFile.moveToNamedTemporaryURL(
                        downloaded.url,
                        name: "Macro Backup \(backup.createdAt.fileNameStamp)"
                    )
                    let presenter = PresentationWaiter.topPresentedController()
                    savedBackupURL = named
                    isShowingBackupSaver = true
                    await PresentationWaiter.waitForPresentation(over: presenter) { isShowingBackupSaver }
                    return
                }
                guard downloaded.backup.version <= MacroBackup.currentVersion else {
                    downloaded.remove()
                    alert = .newerBackup
                    return
                }
                restoringBackup = downloaded
                showBackupRestore = true
            } catch _ where Task.isCancelled {
                return
            } catch MacroBackupFileError.invalid {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                alert = DataTransferAlert(
                    title: "Couldn't Read Backup",
                    message: purpose == .restore
                        ? "This backup is damaged and can't be restored."
                        : "This backup is damaged and can't be saved."
                )
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                alert = DataTransferAlert(
                    title: "Couldn't Download Backup",
                    message:
                        "The backup couldn't be downloaded from iCloud. \(message(for: error))"
                )
            }
        }
    }

    private func delete(_ backup: CloudBackup) {
        guard !isBusy else { return }
        busyBackupID = backup.id

        Task {
            defer { busyBackupID = nil }
            do {
                try await backupStore.delete(backup)
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                alert = DataTransferAlert(
                    title: "Couldn't Delete Backup",
                    message: message(for: error)
                )
            }
        }
    }
}

private struct BackupLoadKey: Equatable {
    let unavailableReason: String?
    let accountGeneration: Int
}

#Preview {
    NavigationStack {
        ICloudView()
    }
    .environment(CloudSyncMonitor())
    .environment(CloudBackupStore())
    .modelContainer(
        try! ModelContainer(
            for: User.self, FoodItem.self, LoggedEntry.self, SavedLocation.self, RecentLocation.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
    )
}
