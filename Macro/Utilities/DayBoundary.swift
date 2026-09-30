//
//  DayBoundary.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import Foundation

extension Calendar {
    func logicalDay(for date: Date, dayStartMinutes: Int) -> Date {
        let shifted =
            self.date(byAdding: .minute, value: -dayStartMinutes, to: date)
            ?? date
        return startOfDay(for: shifted)
    }

    func logicalDayRange(for day: Date, dayStartMinutes: Int) -> Range<Date> {
        let midnight = startOfDay(for: day)
        let nextMidnight =
            self.date(byAdding: .day, value: 1, to: midnight) ?? midnight
        let start =
            self.date(byAdding: .minute, value: dayStartMinutes, to: midnight)
            ?? midnight
        let end =
            self.date(
                byAdding: .minute,
                value: dayStartMinutes,
                to: nextMidnight
            ) ?? nextMidnight
        return start..<end
    }
}
