//
//  MainView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension EnvironmentValues {
    @Entry var eraseAllData: () -> Void = {}
    @Entry var replaceAllData: (MacroBackupFile) -> Void = { _ in }
    @Entry var tabBarHeight: CGFloat = 0
}

private struct TabBarScrollInsets: ViewModifier {
    @Environment(\.tabBarHeight) private var tabBarHeight

    let regions: SafeAreaRegions

    func body(content: Content) -> some View {
        content
            .contentMargins(
                .bottom,
                tabBarHeight > 0 ? tabBarHeight + 28 : 16,
                for: .scrollContent
            )
            .contentMargins(.bottom, tabBarHeight, for: .scrollIndicators)
            .ignoresSafeArea(regions, edges: tabBarHeight > 0 ? .bottom : [])
    }
}

extension View {
    func tabBarScrollInsets(ignoring regions: SafeAreaRegions = .all) -> some View {
        modifier(TabBarScrollInsets(regions: regions))
    }
}

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CloudSyncMonitor.self) private var syncMonitor

    enum TabSelection: ProminentTabItem {
        case home, stats, library

        var symbol: String {
            switch self {
            case .home: return "house"
            case .stats: return "chart.bar.xaxis"
            case .library: return "book.pages"
            }
        }

        var title: String {
            switch self {
            case .home: return String(localized: "Home")
            case .stats: return String(localized: "Statistics")
            case .library: return String(localized: "Library")
            }
        }
    }

    @State private var selection: TabSelection = .home
    @State private var isErasingData = false
    @State private var isReplacingData = false
    @State private var restoreAlert: DataTransferAlert?
    @State private var unrecoveredRestore: BackupRestoreError?
    @State private var snapshotDocument: ExportDocument?
    @State private var isShowingSnapshotExporter = false
    @State private var libraryPopToRoot = 0
    @State private var screenBottom: CGFloat = 0
    @State private var tabBarTop: CGFloat = 0

    @Query private var users: [User]

    private var isOnboardingComplete: Bool {
        users.first?.onboardingComplete == true
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).maxY
                } action: { maxY in
                    screenBottom = maxY
                }

            if !isErasingData {
                tabContent
                    .transition(.opacity)
            }

            if (!isOnboardingComplete && !syncMonitor.isInitialRestoreInProgress) || isErasingData {
                WelcomeView(
                    isRestoring: isReplacingData,
                    restoringMessage: "Restoring Backup…"
                )
                    .zIndex(1)
                    .transition(.scale(scale: 1.1).combined(with: .opacity))
            }
        }
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8),
            value: isOnboardingComplete
        )
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8),
            value: syncMonitor.isInitialRestoreInProgress
        )
        .environment(\.eraseAllData, eraseAllData)
        .environment(\.replaceAllData, replaceAllData)
        .dataTransferAlert($restoreAlert)
        .alert(
            "Restore Failed",
            isPresented: Binding(
                get: { unrecoveredRestore != nil },
                set: { if !$0 { unrecoveredRestore = nil } }
            ),
            presenting: unrecoveredRestore
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
            contentTypes: [.macroBackup],
            defaultFilename: snapshotFilename
        ) { result in
            snapshotDocument = nil
            if case .failure(let error) = result {
                restoreAlert = .exportFailed(error)
            }
        } onCancellation: {
            snapshotDocument = nil
        }
        .task {
            await restoreFromICloudIfNeeded()
        }
        .task {
            await SyncDeduplicator.watch(in: modelContext) {
                toastCenter?.show(
                    Toast(
                        group: Toast.dataTransferGroup,
                        kind: .info,
                        symbol: "icloud.and.arrow.down",
                        title: String(localized: "Goals Restored from iCloud"),
                        message: String(localized: "Your existing goals replaced the ones you just set")
                    )
                )
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await PendingLocationNamer.run(in: modelContext)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            AutomaticBackup.runIfOverdue()
        }
    }

    private var tabContent: some View {
        TabView(selection: $selection) {
            Tab(value: .home) {
                HomeView()
                    .environment(\.tabBarHeight, max(screenBottom - tabBarTop, 0))
                    .toolbarVisibility(.hidden, for: .tabBar)
            }

            Tab(value: .stats) {
                Text("Statistics View")
                    .toolbarVisibility(.hidden, for: .tabBar)
            }

            Tab(value: .library) {
                NavigationStack {
                    LibraryView(
                        searchPrompt: "Search your library",
                        isTabRoot: true,
                        popToRootTrigger: libraryPopToRoot
                    )
                }
                .environment(\.tabBarHeight, max(screenBottom - tabBarTop, 0))
                .toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProminentTabBar(
                selection: $selection,
                prominentSymbol: "plus",
                onReselect: { tab in
                    if tab == .library {
                        libraryPopToRoot += 1
                    }
                }
            ) {
                NewEntryView(
                    onBrowseLibrary: { selection = .library },
                    onFinishLogging: { selection = .home }
                )
            } popover: {
                QuickLogPopover { food in
                    quickLog(food)
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY
            } action: { minY in
                tabBarTop = minY
            }
        }
    }

    private func quickLog(_ food: FoodItem) {
        do {
            let location = QuickLogger.readyLocation(for: food, in: modelContext)
            let entry = try withAnimation {
                try QuickLogger.log(food, location: location, in: modelContext)
            }
            QuickLogger.finishLocation(
                of: entry,
                awaitingCurrent: location == nil,
                in: modelContext
            )
            if let toastCenter {
                toastCenter.show(
                    .entryLogged(
                        LogUndoRecord(entry: entry),
                        title: String(localized: "Logged for Today"),
                        in: modelContext,
                        presenter: toastCenter
                    )
                )
            }
        } catch {
            toastCenter?.show(
                .failure(String(localized: "Couldn't Log Entry"), message: food.name)
            )
        }
    }

    private func restoreFromICloudIfNeeded() async {
        if syncMonitor.hasPendingInitialRestore {
            syncMonitor.beginInitialRestore()
            await finishInitialRestore()
            return
        }

        guard !hasOnboardedUser,
            await syncMonitor.hasSyncedData(timeout: .seconds(10)) == true,
            !hasOnboardedUser
        else { return }

        syncMonitor.beginInitialRestore()
        await finishInitialRestore()
    }

    private func finishInitialRestore() async {
        while !Task.isCancelled, !syncMonitor.hasFinishedDownloadThisLaunch {
            syncMonitor.updateRestoredCounts(logs: topLevelLogCount, entries: libraryEntryCount)
            try? await Task.sleep(for: .seconds(1))
        }
        guard !Task.isCancelled else { return }

        let summary = CloudSyncMonitor.restoredSummary(logs: topLevelLogCount, entries: libraryEntryCount)
        syncMonitor.endInitialRestore()
        guard hasOnboardedUser else { return }
        toastCenter?.show(
            Toast(
                group: Toast.dataTransferGroup,
                kind: .success,
                symbol: "checkmark",
                title: String(localized: "Restore Complete"),
                message: summary ?? String(localized: "Everything from iCloud is on this device")
            )
        )
    }

    private var hasOnboardedUser: Bool {
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.onboardingComplete })
        return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }

    private var libraryEntryCount: Int {
        (try? modelContext.fetchCount(FetchDescriptor<FoodItem>())) ?? 0
    }

    private var topLevelLogCount: Int {
        let descriptor = FetchDescriptor<LoggedEntry>(predicate: #Predicate { $0.parentEntry == nil })
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private func eraseAllData() {
        AutomaticBackup.isDataChangeInProgress = true
        withAnimation(
            .spring(response: 0.6, dampingFraction: 0.8),
            completionCriteria: .removed
        ) {
            isErasingData = true
        } completion: {
            do {
                try modelContext.eraseAllData()
                try modelContext.save()
                AppSeeder.resetListSeeding()
                try AppSeeder.seedDefaults(into: modelContext)
            } catch {
                modelContext.rollback()
                toastCenter?.show(.failure(String(localized: "Couldn't Erase Data")))
            }
            isErasingData = false
            AutomaticBackup.isDataChangeInProgress = false
        }
    }

    private func replaceAllData(with backup: MacroBackupFile) {
        AutomaticBackup.isDataChangeInProgress = true
        withAnimation(
            .spring(response: 0.6, dampingFraction: 0.8),
            completionCriteria: .removed
        ) {
            isReplacingData = true
            isErasingData = true
        } completion: {
            Task {
                var restored: BackupRestoreSummary?
                do {
                    restored = try await BackupRestorer(context: modelContext)
                        .restore(backup, mode: .replace)
                    backup.remove()
                } catch let error as BackupRestoreError {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    if error.snapshotURL != nil {
                        unrecoveredRestore = error
                    } else {
                        restoreAlert = DataTransferAlert(
                            title: "Restore Failed",
                            message: error.localizedDescription
                        )
                    }
                } catch {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    restoreAlert = DataTransferAlert(
                        title: "Restore Failed",
                        message:
                            "The backup couldn't be restored and your existing data was left in place. \(error.localizedDescription)"
                    )
                }

                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isErasingData = false
                    isReplacingData = false
                }
                AutomaticBackup.isDataChangeInProgress = false

                if let restored {
                    Task { await PendingLocationNamer.run(in: modelContext) }
                    toastCenter?.show(.backupRestored(restored))
                }
            }
        }
    }

    private var snapshotFilename: String {
        "Macro Previous Data \(Date().fileNameStamp)"
    }

    private func saveSnapshot(from error: BackupRestoreError) {
        guard let url = error.snapshotURL,
            FileManager.default.fileExists(atPath: url.path)
        else {
            restoreAlert = DataTransferAlert(
                title: "Couldn't Save Copy",
                message: "The copy of your previous data is no longer available."
            )
            return
        }
        snapshotDocument = ExportDocument(fileURL: url, fileName: snapshotFilename)
        isShowingSnapshotExporter = true
    }
}

#Preview {
    MainView()
        .environment(CloudSyncMonitor())
}
