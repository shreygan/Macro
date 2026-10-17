//
//  MacroBackupFile.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/16/26.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    nonisolated static let macroBackup = UTType(exportedAs: "com.Shreyanka.Macro.backup")
}

nonisolated enum MacroBackupFileError: LocalizedError {
    case empty
    case invalid
    case notEnoughSpace(Int64)

    var errorDescription: String? {
        switch self {
        case .empty: String(localized: "The backup file is empty.")
        case .invalid: String(localized: "The file isn't a Macro backup or is damaged.")
        case .notEnoughSpace(let needed):
            String(localized: "There isn't enough free space on this device. Free up about \(needed.formatted(.byteCount(style: .file))) and try again.")
        }
    }
}

// Layout: magic | photo bytes... | manifest JSON | manifest offset (UInt64 LE) | magic
nonisolated struct MacroBackupFile: Sendable {
    let url: URL
    let backup: MacroBackup
    let byteCount: Int64

    private static let magic = Data("MACROBAK".utf8)
    private static let footerLength: UInt64 = 16
    private static let photosPerContext = 10
    private static let attachBatchBytes = 64 * 1024 * 1024
    private static let freeSpaceMargin: Int64 = 200 * 1024 * 1024

    static var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    private static var loadedDirectory: URL {
        temporaryDirectory.appendingPathComponent("Loaded", isDirectory: true)
    }

    static func temporaryURL() throws -> URL {
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        return temporaryDirectory.appendingPathComponent("\(UUID().uuidString).macrobackup")
    }

    static func newLoadedURL() throws -> URL {
        try? FileManager.default.removeItem(at: loadedDirectory)
        try FileManager.default.createDirectory(at: loadedDirectory, withIntermediateDirectories: true)
        return loadedDirectory.appendingPathComponent("\(UUID().uuidString).macrobackup")
    }

    static func moveToNamedTemporaryURL(_ source: URL, name: String) throws -> URL {
        let folder = temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent("\(name).macrobackup")
        try FileManager.default.moveItem(at: source, to: destination)
        return destination
    }

    static func removeTemporaryFiles() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    static func ensureFreeSpace(for bytes: Int64) throws {
        let values = try FileManager.default.temporaryDirectory.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        guard let available = values.volumeAvailableCapacityForImportantUsage else { return }
        if available < bytes + freeSpaceMargin {
            throw MacroBackupFileError.notEnoughSpace(bytes + freeSpaceMargin - available)
        }
    }

    static func open(_ url: URL) throws -> MacroBackupFile {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let fileSize = try handle.seekToEnd()
        guard fileSize > 0 else { throw MacroBackupFileError.empty }
        guard fileSize >= UInt64(magic.count) + footerLength else { throw MacroBackupFileError.invalid }

        try handle.seek(toOffset: 0)
        guard try handle.read(upToCount: magic.count) == magic else {
            throw MacroBackupFileError.invalid
        }

        try handle.seek(toOffset: fileSize - footerLength)
        guard let footer = try handle.read(upToCount: Int(footerLength)),
            footer.count == Int(footerLength),
            footer.suffix(magic.count) == magic
        else { throw MacroBackupFileError.invalid }

        let manifestOffset = footer.prefix(8).reduce(into: UInt64(0)) { value, byte in
            value = value >> 8 | UInt64(byte) << 56
        }
        let manifestEnd = fileSize - footerLength
        guard manifestOffset >= UInt64(magic.count), manifestOffset < manifestEnd else {
            throw MacroBackupFileError.invalid
        }

        try handle.seek(toOffset: manifestOffset)
        guard let manifest = try handle.read(upToCount: Int(manifestEnd - manifestOffset)),
            let backup = try? MacroBackup.decode(manifest),
            backup.format == MacroBackup.formatIdentifier,
            backup.photoSlices.allSatisfy({
                $0.offset >= UInt64(magic.count) && $0.offset + $0.length <= manifestOffset
            })
        else { throw MacroBackupFileError.invalid }

        return MacroBackupFile(url: url, backup: backup, byteCount: Int64(fileSize))
    }

    static func openCopy(of source: URL) throws -> MacroBackupFile {
        let url = try newLoadedURL()
        try FileManager.default.copyItem(at: source, to: url)
        do {
            return try open(url)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    @MainActor
    static func create(
        from context: ModelContext,
        includePhotos: Bool = true,
        at url: URL
    ) async throws -> MacroBackupFile {
        if context.hasChanges { try context.save() }
        let collector = BackupPhotoCollector(includesPhotos: includePhotos)
        let backup = try MacroBackup.make(from: context, photos: collector)
        let photoIDs = collector.ids
        let container = context.container
        let storeURL = includePhotos ? container.configurations.first?.url : nil

        try Task.checkCancellation()
        let task = Task.detached(priority: .userInitiated) {
            if let storeURL {
                try ensureFreeSpace(for: StoreDiskUsage.photoSize(storeURL: storeURL))
            }
            return try write(backup, photoIDs: photoIDs, container: container, to: url)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func write(
        _ manifest: MacroBackup,
        photoIDs: [PersistentIdentifier],
        container: ModelContainer,
        to url: URL
    ) throws -> MacroBackupFile {
        var backup = manifest
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        do {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }

            try handle.write(contentsOf: magic)

            var slices: [MacroBackup.PhotoSlice] = []
            slices.reserveCapacity(photoIDs.count)
            var start = 0
            while start < photoIDs.count {
                try Task.checkCancellation()
                let batch = photoIDs[start..<min(start + photosPerContext, photoIDs.count)]
                try autoreleasepool {
                    let context = ModelContext(container)
                    for id in batch {
                        let descriptor = FetchDescriptor<EntryPhoto>(
                            predicate: #Predicate { $0.persistentModelID == id }
                        )
                        let data = try context.fetch(descriptor).first?.imageData ?? Data()
                        let offset = try handle.offset()
                        try handle.write(contentsOf: data)
                        slices.append(.init(offset: offset, length: UInt64(data.count)))
                    }
                }
                start += photosPerContext
            }

            backup.photoSlices = slices
            try Task.checkCancellation()
            let manifestOffset = try handle.offset()
            try handle.write(contentsOf: try MacroBackup.encode(backup))

            var footer = Data()
            var value = manifestOffset
            for _ in 0..<8 {
                footer.append(UInt8(value & 0xFF))
                value >>= 8
            }
            footer.append(magic)
            try handle.write(contentsOf: footer)

            let byteCount = try handle.offset()
            try handle.synchronize()
            return MacroBackupFile(url: url, backup: backup, byteCount: Int64(byteCount))
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    struct PhotoJob: Sendable {
        let owner: PersistentIdentifier
        let isDraft: Bool
        let photos: [MacroBackup.PhotoRecord]
    }

    func attachPhotos(_ jobs: [PhotoJob], container: ModelContainer) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var context = ModelContext(container)
        var batchBytes = 0

        for job in jobs {
            try autoreleasepool {
                let owner = context.model(for: job.owner)
                for record in job.photos {
                    guard let index = record.index, backup.photoSlices.indices.contains(index) else {
                        continue
                    }
                    let slice = backup.photoSlices[index]
                    guard slice.length > 0 else { continue }

                    try handle.seek(toOffset: slice.offset)
                    guard let data = try handle.read(upToCount: Int(slice.length)),
                        data.count == Int(slice.length)
                    else { throw MacroBackupFileError.invalid }

                    let photo = EntryPhoto(
                        imageData: data,
                        scale: record.scale,
                        offsetX: record.offsetX,
                        offsetY: record.offsetY,
                        displayOrder: record.displayOrder
                    )
                    context.insert(photo)
                    if job.isDraft {
                        photo.parentDraft = owner as? EntryDraft
                    } else {
                        photo.parentEntry = owner as? LoggedEntry
                    }
                    batchBytes += data.count
                }
            }

            if batchBytes >= Self.attachBatchBytes {
                try context.save()
                context = ModelContext(container)
                batchBytes = 0
            }
        }

        try context.save()
    }
}

@MainActor
final class BackupPhotoCollector {
    let includesPhotos: Bool
    private(set) var ids: [PersistentIdentifier] = []

    init(includesPhotos: Bool) {
        self.includesPhotos = includesPhotos
    }

    func records(_ photos: [EntryPhoto]?) -> [MacroBackup.PhotoRecord] {
        guard includesPhotos else { return [] }
        return (photos ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }
            .map {
                ids.append($0.persistentModelID)
                return MacroBackup.PhotoRecord(
                    index: ids.count - 1,
                    scale: $0.scale,
                    offsetX: $0.offsetX,
                    offsetY: $0.offsetY,
                    displayOrder: $0.displayOrder
                )
            }
    }
}

@MainActor
final class PendingBackupPhotos {
    private var owners: [(model: any PersistentModel, isDraft: Bool, photos: [MacroBackup.PhotoRecord])] = []

    func add(_ owner: any PersistentModel, isDraft: Bool, photos: [MacroBackup.PhotoRecord]) {
        let pending = photos.filter { $0.imageData == nil && $0.index != nil }
        guard !pending.isEmpty else { return }
        owners.append((owner, isDraft, pending))
    }

    var jobs: [MacroBackupFile.PhotoJob] {
        owners.map {
            MacroBackupFile.PhotoJob(owner: $0.model.persistentModelID, isDraft: $0.isDraft, photos: $0.photos)
        }
    }
}
