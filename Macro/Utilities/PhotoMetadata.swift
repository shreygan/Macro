//
//  PhotoMetadata.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import CoreLocation
import ImageIO

nonisolated struct PhotoMetadata: Sendable {
    var coordinate: CLLocationCoordinate2D?
    var capturedAt: Date?

    init(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any]
        else { return }

        if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            coordinate = Self.coordinate(from: gps)
        }
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            capturedAt = Self.date(from: exif)
        }
    }

    static func captureText(for date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return time }
        let isThisYear = calendar.isDate(date, equalTo: .now, toGranularity: .year)
        let day = date.formatted(
            isThisYear
                ? .dateTime.month(.abbreviated).day()
                : .dateTime.month(.abbreviated).day().year()
        )
        return String(localized: "\(day), \(time)")
    }

    private static func coordinate(from gps: [CFString: Any]) -> CLLocationCoordinate2D? {
        guard let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
            let longitude = gps[kCGImagePropertyGPSLongitude] as? Double
        else { return nil }

        let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String
        let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
        let coordinate = CLLocationCoordinate2D(
            latitude: latitudeRef == "S" ? -latitude : latitude,
            longitude: longitudeRef == "W" ? -longitude : longitude
        )
        guard CLLocationCoordinate2DIsValid(coordinate),
            coordinate.latitude != 0 || coordinate.longitude != 0
        else { return nil }
        return coordinate
    }

    private static func date(from exif: [CFString: Any]) -> Date? {
        guard let stamp = exif[kCGImagePropertyExifDateTimeOriginal] as? String else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
            if let date = formatter.date(from: stamp + offset) { return date }
        }
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter.date(from: stamp)
    }
}
