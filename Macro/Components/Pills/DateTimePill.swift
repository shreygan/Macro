//
//  DateTimePill.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/23/26.
//

import SwiftUI

struct DateTimePill: View {
    @Binding var selection: Date
    var components: DatePickerComponents
    var range: ClosedRange<Date>? = nil

    @ViewBuilder
    private var picker: some View {
        if let range {
            DatePicker(
                "",
                selection: $selection,
                in: range,
                displayedComponents: components
            )
        } else {
            DatePicker(
                "",
                selection: $selection,
                displayedComponents: components
            )
        }
    }

    var body: some View {
        ZStack {
            Text(
                selection,
                format: components == .date
                    ? .dateTime.month().day().year() : .dateTime.hour().minute()
            )
            .pillBackground()
            .allowsHitTesting(false)

            picker
                .labelsHidden()
                .frame(height: RowMetrics.controlHeight)
                .opacity(0.011)
            .clipped()
        }
        .fixedSize()
        .contentShape(Capsule())
    }
}
