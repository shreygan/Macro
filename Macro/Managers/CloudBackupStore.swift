//
//  CloudBackupStore.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/16/26.
//

import CloudKit
import Foundation
import Observation
import SwiftData
import UIKit

struct CloudBackup: Identifiable, Hashable {
    let id: CKRecord.ID
    let createdAt: Date
    let appVersion: String?
    let byteCount: Int64
    let foodCount: Int?
    let logCount: Int?
    let photoCount: Int?
    let chunkCount: Int
    let isFromThisDevice: Bool
    let deviceModel: String?
    let isAutomatic: Bool
}

enum CloudBackupError: LocalizedError {
    case full

    var errorDescription: String? {
        String(localized: "You already have \(CloudBackupStore.maxBackups) backups. Delete one in Settings › iCloud to make room.")
    }
}

final class PendingBackupFollowUp {
    var isCancelled = false
}

@Observable
final class CloudBackupStore {
    static let maxBackups = 3

    private static let zoneID = CKRecordZone.ID(zoneName: "Backups", ownerName: CKCurrentUserDefaultName)
    private static let recordType = "Backup"
    private static let chunkRecordType = "BackupChunk"
    private static let chunkSize: Int64 = 50 * 1024 * 1024
    private nonisolated static let copyBufferSize = 4 * 1024 * 1024
    private static let staleUploadAge: TimeInterval = 24 * 60 * 60

    private nonisolated enum Field {
        static let createdAt = "createdAt"
        static let appVersion = "appVersion"
        static let byteCount = "byteCount"
        static let foodCount = "foodCount"
        static let logCount = "logCount"
        static let photoCount = "photoCount"
        static let installID = "installID"
        static let deviceModel = "deviceModel"
        static let isAutomatic = "isAutomatic"
        static let formatVersion = "formatVersion"
        static let chunkCount = "chunkCount"
        static let isComplete = "isComplete"
        static let backup = "backup"
        static let index = "index"
        static let file = "file"

        static let summary = [
            createdAt, appVersion, byteCount, foodCount, logCount, photoCount,
            formatVersion, chunkCount, isComplete, installID, deviceModel, isAutomatic,
        ]
    }

    private(set) var backups: [CloudBackup] = []
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var uploadProgress: Double?
    private(set) var isAutomaticUpload = false
    private(set) var isFinishingUpload = false
    private(set) var downloadProgress: Double?

    @ObservationIgnored private var uploadTask: Task<Void, Error>?
    @ObservationIgnored private let database = CKContainer(
        identifier: CloudSyncMonitor.containerIdentifier
    ).privateCloudDatabase
    private(set) var accountGeneration = 0

    init() {
        Task { await observeAccountChanges() }
    }

    var isBackingUp: Bool { uploadProgress != nil }
    var canCancelBackup: Bool { isBackingUp && !isFinishingUpload }
    var isFull: Bool { backups.filter { !$0.isAutomatic }.count >= Self.maxBackups }

    var knownFull: Bool { hasLoaded && isFull }

    var progressTitle: String {
        let progress = uploadProgress ?? 0
        let percent = progress.formatted(.percent.precision(.fractionLength(0)))
        if isAutomaticUpload {
            guard progress > 0 else { return String(localized: "Preparing Automatic Backup...") }
            return String(localized: "Uploading Automatic Backup... \(percent)")
        }
        guard progress > 0 else { return String(localized: "Preparing Backup...") }
        return String(localized: "Uploading Backup... \(percent)")
    }

    func backUpIfRoom(from context: ModelContext) async throws {
        try await refresh()
        guard !isFull else { throw CloudBackupError.full }
        try await backUp(from: context)
    }

    func reset() {
        accountGeneration += 1
        backups = []
        hasLoaded = false
    }

    private func observeAccountChanges() async {
        for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
            reset()
        }
    }

    func refresh() async throws {
        isLoading = true
        defer { isLoading = false }
        let generation = accountGeneration

        var records: [CKRecord] = []
        var token: CKServerChangeToken?
        do {
            while true {
                let changes = try await database.recordZoneChanges(
                    inZoneWith: Self.zoneID,
                    since: token,
                    desiredKeys: Field.summary
                )
                records += changes.modificationResultsByID.values.compactMap { try? $0.get().record }
                token = changes.changeToken
                guard changes.moreComing else { break }
            }
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            records = []
        }

        let parents = records.filter { $0.recordType == Self.recordType }
        let complete = parents.filter { ($0[Field.isComplete] as? Int64) == 1 }
        let stale = parents.filter {
            ($0[Field.isComplete] as? Int64) == 0
                && ($0.creationDate ?? .distantFuture) < Date().addingTimeInterval(-Self.staleUploadAge)
        }

        guard generation == accountGeneration else { return }
        backups = complete.compactMap(Self.backup).sorted { $0.createdAt > $1.createdAt }
        hasLoaded = true

        if !stale.isEmpty {
            _ = try? await database.modifyRecords(saving: [], deleting: stale.map(\.recordID))
        }
    }

    func cancelBackup() {
        guard canCancelBackup else { return }
        uploadTask?.cancel()
    }

    func backUp(from context: ModelContext, automatic: Bool = false) async throws {
        uploadProgress = 0
        isAutomaticUpload = automatic
        let task = Task { try await performBackUp(from: context, automatic: automatic) }
        uploadTask = task
        defer {
            uploadTask = nil
            uploadProgress = nil
            isAutomaticUpload = false
            isFinishingUpload = false
        }

        do {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        } catch where task.isCancelled {
            throw CancellationError()
        }
    }

    private func performBackUp(from context: ModelContext, automatic: Bool) async throws {
        let url = try MacroBackupFile.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try await MacroBackupFile.create(from: context, at: url)
        let backup = file.backup

        try Task.checkCancellation()
        try MacroBackupFile.ensureFreeSpace(for: min(Self.chunkSize, file.byteCount))
        try await ensureZone()

        let chunkCount = Int((file.byteCount + Self.chunkSize - 1) / Self.chunkSize)
        let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(zoneID: Self.zoneID))
        record[Field.createdAt] = backup.createdAt
        record[Field.installID] = InstallID.current
        record[Field.deviceModel] = UIDevice.current.model
        record[Field.appVersion] = backup.appVersion
        record[Field.byteCount] = file.byteCount
        record[Field.foodCount] = backup.foods.count
        record[Field.logCount] = backup.logs.count
        record[Field.photoCount] = backup.photoCount
        record[Field.formatVersion] = backup.version
        record[Field.chunkCount] = chunkCount
        record[Field.isComplete] = Int64(0)
        record[Field.isAutomatic] = Int64(automatic ? 1 : 0)

        let parent = try await Self.save(record, to: database)

        do {
            for index in 0..<chunkCount {
                try Task.checkCancellation()
                let start = Int64(index) * Self.chunkSize
                let length = min(Self.chunkSize, file.byteCount - start)
                let chunkURL = try await Task.detached(priority: .userInitiated) {
                    try Self.copyChunk(of: url, start: start, length: length)
                }.value
                defer { try? FileManager.default.removeItem(at: chunkURL) }

                let chunk = CKRecord(
                    recordType: Self.chunkRecordType,
                    recordID: Self.chunkID(for: parent.recordID, index: index)
                )
                chunk[Field.backup] = CKRecord.Reference(recordID: parent.recordID, action: .deleteSelf)
                chunk[Field.index] = index
                chunk[Field.file] = CKAsset(fileURL: chunkURL)

                let total = Double(file.byteCount)
                _ = try await Self.save(chunk, to: database) { value in
                    let progress = (Double(start) + value * Double(length)) / total
                    Task { @MainActor in
                        guard self.uploadProgress != nil else { return }
                        self.uploadProgress = max(progress, 0.01)
                    }
                }
            }

            try Task.checkCancellation()
            isFinishingUpload = true
            parent[Field.isComplete] = Int64(1)
            _ = try await Self.save(parent, to: database, policy: .changedKeys)
        } catch {
            let database = database
            await Task {
                _ = try? await database.deleteRecord(withID: parent.recordID)
            }.value
            throw error
        }

        try? await refresh()

        if automatic {
            let replaced = backups.filter { $0.isAutomatic && $0.id != parent.recordID }.map(\.id)
            if !replaced.isEmpty, (try? await database.modifyRecords(saving: [], deleting: replaced)) != nil {
                backups.removeAll { replaced.contains($0.id) }
            }
        }
    }

    func download(_ backup: CloudBackup) async throws -> MacroBackupFile {
        guard backup.chunkCount > 0 else { throw MacroBackupFileError.invalid }
        try MacroBackupFile.ensureFreeSpace(for: backup.byteCount)

        let url = try MacroBackupFile.newLoadedURL()
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        downloadProgress = 0
        defer { downloadProgress = nil }

        do {
            let total = Double(max(backup.byteCount, 1))
            for index in 0..<backup.chunkCount {
                try Task.checkCancellation()
                let start = Int64(index) * Self.chunkSize
                let length = Double(max(min(Self.chunkSize, backup.byteCount - start), 0))
                let chunk = try await Self.fetch(
                    Self.chunkID(for: backup.id, index: index),
                    from: database
                ) { value in
                    let progress = min((Double(start) + value * length) / total, 1)
                    Task { @MainActor in
                        guard self.downloadProgress != nil else { return }
                        self.downloadProgress = max(progress, 0.01)
                    }
                }
                guard let chunkURL = (chunk[Field.file] as? CKAsset)?.fileURL else {
                    throw MacroBackupFileError.invalid
                }
                try await Task.detached(priority: .userInitiated) {
                    try Self.append(chunkURL, to: url)
                }.value
            }
            try Task.checkCancellation()
            return try await Task.detached(priority: .userInitiated) {
                try MacroBackupFile.open(url)
            }.value
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    func delete(_ backup: CloudBackup) async throws {
        _ = try await database.deleteRecord(withID: backup.id)
        backups.removeAll { $0.id == backup.id }
    }

    private func ensureZone() async throws {
        do {
            _ = try await database.recordZone(for: Self.zoneID)
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            _ = try await database.save(CKRecordZone(zoneID: Self.zoneID))
        }
    }

    private nonisolated static func chunkID(for parent: CKRecord.ID, index: Int) -> CKRecord.ID {
        CKRecord.ID(recordName: "\(parent.recordName)-\(index)", zoneID: parent.zoneID)
    }

    private nonisolated static func copyChunk(of source: URL, start: Int64, length: Int64) throws -> URL {
        let url = try MacroBackupFile.temporaryURL()
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            let input = try FileHandle(forReadingFrom: source)
            defer { try? input.close() }
            let output = try FileHandle(forWritingTo: url)
            defer { try? output.close() }

            try input.seek(toOffset: UInt64(start))
            var remaining = length
            while remaining > 0 {
                try autoreleasepool {
                    let count = Int(min(Int64(copyBufferSize), remaining))
                    guard let data = try input.read(upToCount: count), !data.isEmpty else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    try output.write(contentsOf: data)
                    remaining -= Int64(data.count)
                }
            }
            return url
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private nonisolated static func append(_ source: URL, to destination: URL) throws {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        try output.seekToEnd()
        var isFinished = false
        while !isFinished {
            try autoreleasepool {
                guard let data = try input.read(upToCount: copyBufferSize), !data.isEmpty else {
                    isFinished = true
                    return
                }
                try output.write(contentsOf: data)
            }
        }
    }

    private nonisolated static func save(
        _ record: CKRecord,
        to database: CKDatabase,
        policy: CKModifyRecordsOperation.RecordSavePolicy = .allKeys,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> CKRecord {
        let operation = CKModifyRecordsOperation(recordsToSave: [record])
        operation.savePolicy = policy
        operation.qualityOfService = .userInitiated
        if let progress {
            operation.perRecordProgressBlock = { @Sendable _, value in
                progress(value)
            }
        }
        let saved = RecordResultBox()
        operation.perRecordSaveBlock = { @Sendable _, result in
            saved.result = result
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
                operation.modifyRecordsResultBlock = { @Sendable result in
                    switch result {
                    case .success:
                        continuation.resume(with: saved.result ?? .failure(CKError(.internalError)))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                database.add(operation)
            }
        } onCancel: {
            operation.cancel()
        }
    }

    private nonisolated static func fetch(
        _ id: CKRecord.ID,
        from database: CKDatabase,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> CKRecord {
        let operation = CKFetchRecordsOperation(recordIDs: [id])
        operation.qualityOfService = .userInitiated
        operation.perRecordProgressBlock = { @Sendable _, value in
            progress(value)
        }
        let fetched = RecordResultBox()
        operation.perRecordResultBlock = { @Sendable _, result in
            fetched.result = result
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
                operation.fetchRecordsResultBlock = { @Sendable result in
                    switch result {
                    case .success:
                        continuation.resume(with: fetched.result ?? .failure(CKError(.internalError)))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                database.add(operation)
            }
        } onCancel: {
            operation.cancel()
        }
    }

    fileprivate nonisolated static func backup(from record: CKRecord) -> CloudBackup? {
        guard let createdAt = record[Field.createdAt] as? Date else { return nil }
        return CloudBackup(
            id: record.recordID,
            createdAt: createdAt,
            appVersion: record[Field.appVersion] as? String,
            byteCount: record[Field.byteCount] as? Int64 ?? 0,
            foodCount: record[Field.foodCount] as? Int,
            logCount: record[Field.logCount] as? Int,
            photoCount: record[Field.photoCount] as? Int,
            chunkCount: record[Field.chunkCount] as? Int ?? 0,
            isFromThisDevice: (record[Field.installID] as? String).map { $0 == InstallID.current } ?? false,
            deviceModel: record[Field.deviceModel] as? String,
            isAutomatic: (record[Field.isAutomatic] as? Int64) == 1
        )
    }
}

private nonisolated final class RecordResultBox: @unchecked Sendable {
    var result: Result<CKRecord, Error>?
}
