//
//  AutomaticBackup.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/16/26.
//

import BackgroundTasks
import Foundation
import Network
import os
import SwiftData

enum AutomaticBackup {
    static let enabledKey = "automaticBackupsEnabled"
    static let lastFailureKey = "lastAutomaticBackupFailure"

    private static let taskIdentifier = "com.Shreyanka.Macro.automaticBackup"
    private static let lastBackupKey = "lastAutomaticBackup"
    private static let enabledSinceKey = "automaticBackupsEnabledSince"
    private static let interval: TimeInterval = 7 * 24 * 60 * 60
    private static let retryDelay: TimeInterval = 24 * 60 * 60
    private static let overdueAge: TimeInterval = 10 * 24 * 60 * 60
    private static let syncWait: Duration = .seconds(90)
    private static let freshnessSlack: TimeInterval = 12 * 60 * 60
    private static let cloudSettings = NSUbiquitousKeyValueStore.default

    private static var store: CloudBackupStore?
    private static var container: ModelContainer?
    private static var syncMonitor: CloudSyncMonitor?
    private static var isRegistered = false
    private static var overdueRun: Task<Void, Never>?

    static var isDataChangeInProgress = false

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var lastBackup: Date? {
        UserDefaults.standard.object(forKey: lastBackupKey) as? Date
    }

    static var lastBackupOrEnabledDate: Date? {
        lastBackup ?? UserDefaults.standard.object(forKey: enabledSinceKey) as? Date
    }

    static func register(store: CloudBackupStore, container: ModelContainer, syncMonitor: CloudSyncMonitor) {
        self.store = store
        self.container = container
        self.syncMonitor = syncMonitor
        guard !isRegistered else { return }
        isRegistered = true
        if cloudSettings.object(forKey: enabledKey) == nil, isEnabled {
            cloudSettings.set(true, forKey: enabledKey)
        }
        pullCloudSetting()
        Task { await observeCloudSetting() }
        cloudSettings.synchronize()
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil,
            launchHandler: launchHandler()
        )
        schedule()
    }

    static func enabledDidChange() {
        if cloudSettings.object(forKey: enabledKey) as? Bool != isEnabled {
            cloudSettings.set(isEnabled, forKey: enabledKey)
        }
        applyEnabledChange()
    }

    private static func observeCloudSetting() async {
        let changes = NotificationCenter.default.notifications(
            named: NSUbiquitousKeyValueStore.didChangeExternallyNotification
        )
        for await _ in changes {
            pullCloudSetting()
        }
    }

    private static func pullCloudSetting() {
        guard let value = cloudSettings.object(forKey: enabledKey) as? Bool,
            value != isEnabled
        else { return }
        UserDefaults.standard.set(value, forKey: enabledKey)
        applyEnabledChange()
    }

    private static func applyEnabledChange() {
        if isEnabled {
            if UserDefaults.standard.object(forKey: enabledSinceKey) == nil {
                UserDefaults.standard.set(Date(), forKey: enabledSinceKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: enabledSinceKey)
            UserDefaults.standard.removeObject(forKey: lastFailureKey)
            if store?.isAutomaticUpload == true {
                store?.cancelBackup()
            }
        }
        schedule()
    }

    static func runIfOverdue() {
        guard overdueRun == nil, isEnabled,
            let reference = lastBackup ?? UserDefaults.standard.object(forKey: enabledSinceKey) as? Date,
            Date().timeIntervalSince(reference) > overdueAge
        else { return }

        overdueRun = Task {
            defer { overdueRun = nil }
            guard await isOnUnmeteredNetwork() else { return }
            _ = await perform()
        }
    }

    private static func run(_ task: BGTask) async {
        let work = Task { await perform() }
        task.expirationHandler = expirationHandler(cancelling: work)
        let succeeded = await work.value
        task.setTaskCompleted(success: succeeded)
    }

    private static func perform() async -> Bool {
        guard isEnabled, let store, let container, let syncMonitor else {
            schedule()
            return false
        }

        guard !store.isBackingUp, !isDataChangeInProgress,
            await waitForSync(syncMonitor),
            !store.isBackingUp, !isDataChangeInProgress
        else {
            schedule(retrying: true)
            return false
        }

        do {
            try await store.refresh()
        } catch {
            if !(error is CancellationError) {
                UserDefaults.standard.set(syncMonitor.message(for: error), forKey: lastFailureKey)
            }
            schedule(retrying: true)
            return false
        }

        if let latest = store.backups.first(where: \.isAutomatic)?.createdAt {
            UserDefaults.standard.set(latest, forKey: lastBackupKey)
            if Date().timeIntervalSince(latest) < interval - freshnessSlack {
                UserDefaults.standard.removeObject(forKey: lastFailureKey)
                schedule()
                return true
            }
        }

        guard hasData(in: container.mainContext) else {
            UserDefaults.standard.set(
                String(localized: "Skipped because Macro has no data"),
                forKey: lastFailureKey
            )
            schedule(retrying: true)
            return false
        }

        guard !store.isBackingUp, !isDataChangeInProgress else {
            schedule(retrying: true)
            return false
        }

        do {
            try await store.backUp(from: container.mainContext, automatic: true)
            UserDefaults.standard.set(Date(), forKey: lastBackupKey)
            UserDefaults.standard.removeObject(forKey: lastFailureKey)
            schedule()
            return true
        } catch {
            if !(error is CancellationError) {
                UserDefaults.standard.set(syncMonitor.message(for: error), forKey: lastFailureKey)
            }
            schedule(retrying: true)
            return false
        }
    }

    private static func waitForSync(_ syncMonitor: CloudSyncMonitor) async -> Bool {
        let deadline = ContinuousClock.now + syncWait
        while !syncMonitor.hasFinishedDownloadThisLaunch {
            guard ContinuousClock.now < deadline, !Task.isCancelled else { return false }
            try? await Task.sleep(for: .seconds(1))
        }
        return true
    }

    private static func hasData(in context: ModelContext) -> Bool {
        let foods = (try? context.fetchCount(FetchDescriptor<FoodItem>())) ?? 0
        let logs = (try? context.fetchCount(FetchDescriptor<LoggedEntry>())) ?? 0
        return foods + logs > 0
    }

    private static func schedule(retrying: Bool = false) {
        guard isEnabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
            return
        }

        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        request.earliestBeginDate = retrying
            ? Date().addingTimeInterval(retryDelay)
            : lastBackup.map { $0.addingTimeInterval(interval) } ?? Date()
        BGTaskScheduler.shared.submitTaskRequest(request) { _ in }
    }

    private nonisolated static func launchHandler() -> @Sendable (BGTask) -> Void {
        { task in
            nonisolated(unsafe) let task = task
            Task { @MainActor in
                await run(task)
            }
        }
    }

    private nonisolated static func expirationHandler(cancelling work: Task<Bool, Never>) -> @Sendable () -> Void {
        { work.cancel() }
    }

    private static func isOnUnmeteredNetwork() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = pathHandler(for: monitor, resuming: continuation)
            monitor.start(queue: .global(qos: .utility))
        }
    }

    private nonisolated static func pathHandler(
        for monitor: NWPathMonitor,
        resuming continuation: CheckedContinuation<Bool, Never>
    ) -> @Sendable (NWPath) -> Void {
        let resumed = OSAllocatedUnfairLock(initialState: false)
        return { path in
            let isFirst = resumed.withLock { done in
                defer { done = true }
                return !done
            }
            guard isFirst else { return }
            monitor.cancel()
            continuation.resume(
                returning: path.status == .satisfied && !path.isExpensive && !path.isConstrained
            )
        }
    }
}
