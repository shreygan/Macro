//
//  PhotoEncoder.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/17/26.
//

import ImageIO
import UIKit
import UniformTypeIdentifiers

nonisolated enum PhotoEncoder {
    static let quality = 0.80
    static let maxPixelArea = 4032 * 3024
    static let fallbackQuality = 0.85
    static let minimumSavings = 0.10

    private static let reusableTypes: Set<String> = [
        UTType.heic.identifier,
        UTType.jpeg.identifier,
    ]

    @concurrent
    static func encode(_ data: Data) async -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0
        else { return nil }

        let sourceType = CGImageSourceGetType(source) as String?
        let maxPixelSize = maxPixelSize(width: width, height: height)
        var options: [CFString: Any] = [:]
        if let maxPixelSize {
            options[kCGImageDestinationImageMaxPixelSize] = maxPixelSize
        }

        guard
            let output = write(options: options, adding: { destination, properties in
                CGImageDestinationAddImageFromSource(destination, source, 0, properties)
            })
        else { return data }

        if maxPixelSize == nil, let sourceType, reusableTypes.contains(sourceType),
            Double(output.count) > Double(data.count) * (1 - minimumSavings)
        {
            return data
        }
        return output
    }

    @concurrent
    static func encode(_ image: UIImage, metadata: [String: Any]?) async -> Data? {
        guard let original = image.cgImage else { return nil }

        let cgImage = downscaled(original) ?? original
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        var properties: [CFString: Any] = [:]
        for (key, value) in metadata ?? [:] {
            properties[key as CFString] = value
        }
        properties[kCGImagePropertyPixelWidth] = nil
        properties[kCGImagePropertyPixelHeight] = nil
        if var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = nil
            exif[kCGImagePropertyExifPixelYDimension] = nil
            properties[kCGImagePropertyExifDictionary] = exif
        }
        if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = orientation.rawValue
            properties[kCGImagePropertyTIFFDictionary] = tiff
        }
        properties[kCGImagePropertyOrientation] = orientation.rawValue

        return write(options: properties, adding: { destination, properties in
            CGImageDestinationAddImage(destination, cgImage, properties)
        })
    }

    private static func scaleFactor(width: Int, height: Int) -> Double? {
        let area = width * height
        guard area > maxPixelArea else { return nil }
        return (Double(maxPixelArea) / Double(area)).squareRoot()
    }

    private static func maxPixelSize(width: Int, height: Int) -> Int? {
        guard let scale = scaleFactor(width: width, height: height) else { return nil }
        return Int((Double(max(width, height)) * scale).rounded())
    }

    private static func downscaled(_ image: CGImage) -> CGImage? {
        guard let scale = scaleFactor(width: image.width, height: image.height) else {
            return nil
        }
        let width = Int((Double(image.width) * scale).rounded())
        let height = Int((Double(image.height) * scale).rounded())
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func write(
        options: [CFString: Any],
        adding addImage: (CGImageDestination, CFDictionary) -> Void
    ) -> Data? {
        let attempts = [
            (UTType.heic.identifier, quality),
            (UTType.jpeg.identifier, fallbackQuality),
        ]
        for (type, quality) in attempts {
            let output = NSMutableData()
            guard
                let destination = CGImageDestinationCreateWithData(
                    output as CFMutableData,
                    type as CFString,
                    1,
                    nil
                )
            else { continue }

            var properties = options
            properties[kCGImageDestinationLossyCompressionQuality] = quality
            addImage(destination, properties as CFDictionary)
            if CGImageDestinationFinalize(destination) {
                return output as Data
            }
        }
        return nil
    }
}

nonisolated extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
