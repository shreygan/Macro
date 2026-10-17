//
//  StoreDiskUsage.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/16/26.
//

import Foundation

nonisolated struct StoreDiskUsage: Sendable {
    let total: Int64
    let photos: Int64

    var database: Int64 { total - photos }

    init(storeURL: URL) {
        let directory = storeURL.deletingLastPathComponent()
        let storeName = storeURL.lastPathComponent
        let support = Self.supportDirectory(for: storeURL)

        let storeFiles = [storeName, "\(storeName)-wal", "\(storeName)-shm"]
            .map { Self.allocatedSize(of: directory.appending(path: $0)) }
            .reduce(0, +)

        photos = Self.photoSize(storeURL: storeURL)
        total = storeFiles + Self.allocatedSize(of: support)
    }

    static func photoSize(storeURL: URL) -> Int64 {
        allocatedSize(
            of: supportDirectory(for: storeURL).appending(path: "_EXTERNAL_DATA", directoryHint: .isDirectory)
        )
    }

    private static func supportDirectory(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent().appending(
            path: ".\(storeURL.deletingPathExtension().lastPathComponent)_SUPPORT",
            directoryHint: .isDirectory
        )
    }

    private static let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]

    private static func allocatedSize(of url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        guard isDirectory.boolValue else { return fileSize(url) }

        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys)) else {
            return 0
        }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            total += fileSize(file)
        }
        return total
    }

    private static func fileSize(_ url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { return 0 }
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}
