//
//  EntryPhotoImage.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/10/26.
//

import ImageIO
import SwiftData
import SwiftUI

struct EntryPhotoImage: View {
    @Environment(\.displayScale) private var displayScale

    let photo: EntryPhoto
    let framingWidth: CGFloat

    @State private var loadedImage: UIImage?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let pixelSize = pixelSize(for: size)
            let image =
                loadedImage
                ?? EntryPhotoCache.shared.cachedImage(
                    for: photo,
                    pixelSize: pixelSize
                )

            ZStack {
                Color.controlFill

                if let image {
                    framedImage(image, size: size)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .task(id: pixelSize) {
                guard pixelSize > 0 else { return }
                if let image = await EntryPhotoCache.shared.image(
                    for: photo,
                    pixelSize: pixelSize
                ) {
                    loadedImage = image
                }
            }
        }
    }

    private func framedImage(_ image: UIImage, size: CGSize) -> some View {
        let ratio = framingWidth > 0 ? size.width / framingWidth : 1

        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(photo.scale)
            .offset(x: photo.offsetX * ratio, y: photo.offsetY * ratio)
    }

    private func pixelSize(for size: CGSize) -> Int {
        let needed =
            max(size.width, size.height) * displayScale
            * max(1, photo.scale) * 1.5
        guard needed > 0 else { return 0 }
        return Int((needed / 256).rounded(.up)) * 256
    }
}

final class EntryPhotoCache {
    static let shared = EntryPhotoCache()

    private let cache: NSCache<Key, UIImage> = {
        let cache = NSCache<Key, UIImage>()
        cache.totalCostLimit = 150 * 1024 * 1024
        return cache
    }()

    private var dimensions: [PersistentIdentifier: CGSize] = [:]
    private var metadata: [PersistentIdentifier: PhotoMetadata] = [:]

    func metadata(for photo: EntryPhoto) async -> PhotoMetadata? {
        let id = photo.persistentModelID
        if let cached = metadata[id] {
            return cached
        }
        guard let data = await imageData(for: photo) else { return nil }
        let parsed = await Self.readMetadata(data)
        metadata[id] = parsed
        return parsed
    }

    func pixelDimensions(for photo: EntryPhoto) async -> CGSize? {
        let id = photo.persistentModelID
        if let cached = dimensions[id] {
            return cached
        }
        guard let data = await imageData(for: photo),
            let size = await Self.readDimensions(data)
        else { return nil }

        dimensions[id] = size
        return size
    }

    private func imageData(for photo: EntryPhoto) async -> Data? {
        guard !photo.isDeleted, let container = photo.modelContext?.container
        else { return nil }

        if let data = await Self.readImageData(
            photo.persistentModelID,
            from: container
        ) {
            return data
        }

        guard !photo.isDeleted, photo.modelContext != nil else { return nil }
        return photo.imageData
    }

    @concurrent
    private nonisolated static func readImageData(
        _ id: PersistentIdentifier,
        from container: ModelContainer
    ) async -> Data? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EntryPhoto>(
            predicate: #Predicate { $0.persistentModelID == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.imageData
    }

    @concurrent
    private nonisolated static func readMetadata(_ data: Data) async -> PhotoMetadata {
        PhotoMetadata(data: data)
    }

    @concurrent
    private nonisolated static func readDimensions(_ data: Data) async -> CGSize? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(data as CFData, options),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options)
                as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Double,
            let height = properties[kCGImagePropertyPixelHeight] as? Double
        else { return nil }

        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        return orientation >= 5
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
    }

    func cachedImage(for photo: EntryPhoto, pixelSize: Int) -> UIImage? {
        guard pixelSize > 0 else { return nil }
        return cache.object(
            forKey: Key(id: photo.persistentModelID, pixelSize: pixelSize)
        )
    }

    func image(for photo: EntryPhoto, pixelSize: Int) async -> UIImage? {
        guard !photo.isDeleted, photo.modelContext != nil else { return nil }

        let key = Key(id: photo.persistentModelID, pixelSize: pixelSize)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let data = await imageData(for: photo),
            let image = await Self.downsample(data, pixelSize: pixelSize)
        else { return nil }

        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }

    @concurrent
    private nonisolated static func downsample(
        _ data: Data,
        pixelSize: Int
    ) async -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(
                data as CFData,
                sourceOptions
            )
        else { return nil }

        let thumbnailOptions =
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: pixelSize,
            ] as CFDictionary
        guard
            let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                thumbnailOptions
            )
        else { return nil }

        return UIImage(cgImage: cgImage)
    }

    private nonisolated final class Key: NSObject {
        let id: PersistentIdentifier
        let pixelSize: Int

        init(id: PersistentIdentifier, pixelSize: Int) {
            self.id = id
            self.pixelSize = pixelSize
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Key else { return false }
            return id == other.id && pixelSize == other.pixelSize
        }

        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(id)
            hasher.combine(pixelSize)
            return hasher.finalize()
        }
    }
}
