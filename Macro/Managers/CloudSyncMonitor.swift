//
//  CloudSyncMonitor.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/16/26.
//

import CloudKit
import CoreData
import Foundation
import Observation
import SwiftData

@Observable
final class CloudSyncMonitor {
    static let containerIdentifier = "iCloud.Shreyanka.Macro"
    private static let syncZoneName = "com.apple.coredata.cloudkit.zone"
    private static let lastUploadKey = "CloudSyncMonitor.lastUpload"
    private static let lastDownloadKey = "CloudSyncMonitor.lastDownload"
    private static let initialRestorePendingKey = "CloudSyncMonitor.initialRestorePending"

    enum AccountState: Equatable {
        case checking
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case unknown

        var isAvailable: Bool { self == .available }
    }

    enum Issue: Equatable {
        case storageFull
        case offline
        case notSignedIn
        case noAccess
        case other(String)

        var title: String {
            switch self {
            case .storageFull: String(localized: "iCloud Storage Full")
            case .offline: String(localized: "No Connection")
            case .notSignedIn, .noAccess: String(localized: "No iCloud Access")
            case .other: String(localized: "Couldn't Sync")
            }
        }

        var blocksSync: Bool {
            self == .notSignedIn || self == .noAccess
        }

        var message: String? {
            if case .other(let description) = self { return description }
            return nil
        }
    }

    enum SyncNowResult: Equatable {
        case upToDate
        case stillUploading
        case failed(Issue)
    }

    private(set) var account: AccountState = .checking
    private(set) var lastUpload: Date?
    private(set) var lastDownload: Date?
    private(set) var issue: Issue?
    private(set) var isManualSyncing = false
    private(set) var hasFinishedDownloadThisLaunch = false
    private(set) var hasCheckedAccess = false
    private(set) var isInitialRestoreInProgress = false
    private(set) var restoredLogCount = 0
    private(set) var restoredEntryCount = 0

    private var activeEvents: [UUID: NSPersistentCloudKitContainer.EventType] = [:]
    private var lastExportStart: Date?
    private var lastExportEnd: Date?
    private var lastExportIssue: Issue?

    @ObservationIgnored private let container = CKContainer(identifier: containerIdentifier)

    var isSyncing: Bool {
        activeEvents.values.contains { $0 == .import || $0 == .export }
    }

    var hasPendingInitialRestore: Bool {
        UserDefaults.standard.bool(forKey: Self.initialRestorePendingKey)
    }

    var isInitialRestorePaused: Bool {
        issue == .offline || issue?.blocksSync == true
            || account == .noAccount || account == .restricted
    }

    func beginInitialRestore() {
        isInitialRestoreInProgress = true
        UserDefaults.standard.set(true, forKey: Self.initialRestorePendingKey)
    }

    func updateRestoredCounts(logs: Int, entries: Int) {
        if logs != restoredLogCount { restoredLogCount = logs }
        if entries != restoredEntryCount { restoredEntryCount = entries }
    }

    static func restoredSummary(logs: Int, entries: Int) -> String? {
        let parts = [
            logs > 0 ? String(AttributedString(localized: "^[\(logs) log](inflect: true)").characters) : nil,
            entries > 0 ? String(AttributedString(localized: "^[\(entries) entry](inflect: true)").characters) : nil,
        ]
        .compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func endInitialRestore() {
        isInitialRestoreInProgress = false
        restoredLogCount = 0
        restoredEntryCount = 0
        UserDefaults.standard.removeObject(forKey: Self.initialRestorePendingKey)
    }

    var canReachICloud: Bool {
        account.isAvailable && issue?.blocksSync != true
    }

    func message(for error: Error) -> String {
        if let error = error as? CloudBackupError {
            return error.localizedDescription
        }
        return switch report(error) {
        case .noAccess, .notSignedIn:
            String(localized: "Macro doesn't have access to iCloud. Make sure you're signed in to iCloud and that iCloud is turned on for Macro in the Settings app.")
        case .storageFull:
            String(localized: "Your iCloud storage is full.")
        case .offline:
            String(localized: "Check your connection and try again.")
        case .other, nil:
            error.localizedDescription
        }
    }

    var hasAccess: Bool {
        switch account {
        case .available, .temporarilyUnavailable, .unknown:
            issue?.blocksSync != true
        case .checking, .noAccount, .restricted:
            false
        }
    }

    init() {
        let defaults = UserDefaults.standard
        lastUpload = defaults.object(forKey: Self.lastUploadKey) as? Date
        lastDownload = defaults.object(forKey: Self.lastDownloadKey) as? Date

        Task { await refreshAccount() }
        Task { await observeAccountChanges() }
        Task { await observeSyncEvents() }
    }

    func refreshAccount() async {
        do {
            account = switch try await container.accountStatus() {
            case .available: .available
            case .noAccount: .noAccount
            case .restricted: .restricted
            case .temporarilyUnavailable: .temporarilyUnavailable
            case .couldNotDetermine: .unknown
            @unknown default: .unknown
            }
        } catch {
            account = .unknown
        }
        if account.isAvailable, issue == .notSignedIn {
            issue = nil
        }
    }

    func waitForAccountStatus() async -> AccountState {
        while account == .checking, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return account
    }

    func hasSyncedData(timeout: Duration) async -> Bool? {
        await withTaskGroup(of: Bool?.self) { group in
            group.addTask { await self.hasSyncedData() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    func hasSyncedData() async -> Bool? {
        guard await waitForAccountStatus().isAvailable else { return nil }
        let zoneID = CKRecordZone.ID(zoneName: Self.syncZoneName, ownerName: CKCurrentUserDefaultName)
        do {
            var token: CKServerChangeToken?
            for _ in 0..<5 {
                let changes = try await container.privateCloudDatabase.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: token,
                    desiredKeys: [],
                    resultsLimit: 10
                )
                if !changes.modificationResultsByID.isEmpty { return true }
                guard changes.moreComing else { return false }
                token = changes.changeToken
            }
            return true
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            return false
        } catch {
            return nil
        }
    }

    func report(_ error: Error) -> Issue? {
        let reported = Self.issue(from: error)
        if let reported, reported.blocksSync {
            issue = reported
        }
        return reported
    }

    func recheckAccess() async {
        await refreshAccount()
        defer { hasCheckedAccess = true }
        guard account.isAvailable else { return }
        do {
            _ = try await container.privateCloudDatabase.allRecordZones()
            if issue == .noAccess { issue = nil }
        } catch {
            if Self.issue(from: error) == .noAccess {
                issue = .noAccess
            } else if issue == .noAccess {
                issue = nil
            }
        }
    }

    func syncNow(in context: ModelContext) async -> SyncNowResult {
        guard account.isAvailable else { return .failed(.notSignedIn) }
        if let issue, issue.blocksSync { return .failed(issue) }

        isManualSyncing = true
        defer { isManualSyncing = false }

        let requested = Date.now
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                return .failed(.other(error.localizedDescription))
            }
        }

        var started = activeEvents.values.contains(.export)
        if !started {
            started = await waitUntil(.seconds(3)) {
                (self.lastExportStart ?? .distantPast) >= requested
            }
        }
        guard started else {
            if let issue { return .failed(issue) }
            record(upload: .now)
            return .upToDate
        }

        let finished = await waitUntil(.seconds(60)) {
            (self.lastExportEnd ?? .distantPast) >= requested
        }
        guard finished else { return .stillUploading }
        return lastExportIssue.map(SyncNowResult.failed) ?? .upToDate
    }

    private func waitUntil(_ timeout: Duration, _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline, !Task.isCancelled {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return condition()
    }

    private func observeAccountChanges() async {
        for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
            resetSyncDates()
            await refreshAccount()
        }
    }

    private func resetSyncDates() {
        lastUpload = nil
        lastDownload = nil
        UserDefaults.standard.removeObject(forKey: Self.lastUploadKey)
        UserDefaults.standard.removeObject(forKey: Self.lastDownloadKey)
    }

    private func observeSyncEvents() async {
        let events = NotificationCenter.default.notifications(
            named: NSPersistentCloudKitContainer.eventChangedNotification
        )
        for await notification in events {
            guard
                let event = notification.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event
            else { continue }
            handle(event)
        }
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        guard let endDate = event.endDate else {
            activeEvents[event.identifier] = event.type
            if event.type == .export { lastExportStart = event.startDate }
            return
        }

        activeEvents[event.identifier] = nil
        let eventIssue = event.succeeded ? nil : Self.issue(from: event.error)

        switch event.type {
        case .export:
            lastExportEnd = endDate
            lastExportIssue = eventIssue
            if event.succeeded { record(upload: endDate) }
        case .import:
            if event.succeeded {
                record(download: endDate)
                hasFinishedDownloadThisLaunch = true
            }
        default:
            break
        }

        if event.succeeded {
            if issue != .notSignedIn { issue = nil }
        } else if let eventIssue {
            issue = eventIssue
        }
    }

    private func record(upload date: Date) {
        lastUpload = date
        UserDefaults.standard.set(date, forKey: Self.lastUploadKey)
    }

    private func record(download date: Date) {
        lastDownload = date
        UserDefaults.standard.set(date, forKey: Self.lastDownloadKey)
    }

    private nonisolated static func issue(from error: Error?) -> Issue? {
        guard let error else { return nil }
        let nsError = error as NSError

        if isMissingAccountError(nsError) {
            return .noAccess
        }
        guard let ckError = cloudKitError(in: error) else {
            return .other(error.localizedDescription)
        }

        switch ckError.code {
        case .permissionFailure, .managedAccountRestricted:
            return .noAccess
        case .quotaExceeded:
            return .storageFull
        case .networkUnavailable, .networkFailure:
            return .offline
        case .notAuthenticated:
            return .notSignedIn
        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return nil
        case .partialFailure:
            let partials = ckError.partialErrorsByItemID?.values.compactMap { $0 as? CKError } ?? []
            if partials.contains(where: { $0.code == .quotaExceeded }) { return .storageFull }
            return .other(ckError.localizedDescription)
        default:
            return .other(ckError.localizedDescription)
        }
    }

    private nonisolated static func isMissingAccountError(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain && error.code == 134400 { return true }
        guard let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError else { return false }
        return isMissingAccountError(underlying)
    }

    private nonisolated static func cloudKitError(in error: Error) -> CKError? {
        if let ckError = error as? CKError { return ckError }
        let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error
        return underlying.flatMap(cloudKitError)
    }
}
