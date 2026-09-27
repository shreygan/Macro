//
//  DateTimePillRow.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-11.
//

import SwiftUI

struct DateTimePillRow: View {
    var icon: RowIcon? = nil
    var title: String
    var titleExtension: String? = nil
    var subtitle: String? = nil
    var isEnabled: Bool = true

    @Binding var dateSelection: Date
    @Binding var timeSelection: Date

    private var formattedDateTime: String {
        let dateString = dateSelection.formatted(
            date: .abbreviated,
            time: .omitted
        )
        let timeString = timeSelection.formatted(
            date: .omitted,
            time: .shortened
        )
        return "\(dateString) at \(timeString)"
    }

    var body: some View {
        BaseRowLayout(
            icon: icon,
            title: title,
            titleExtension: titleExtension,
            subtitle: subtitle
        ) {
            HStack(spacing: 0) {
                Spacer()

                ZStack(alignment: .trailing) {
                    HStack(spacing: 0) {
                        DateTimePill(
                            selection: $dateSelection,
                            components: .date
                        )
                        DateTimePill(
                            selection: $timeSelection,
                            components: .hourAndMinute
                        )
                        .padding(.trailing, -5)
                    }
                    .opacity(isEnabled ? 1.0 : 0.0)
                    .allowsHitTesting(isEnabled)
                    .accessibilityHidden(!isEnabled)

                    Text(formattedDateTime)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                        .opacity(isEnabled ? 0.0 : 1.0)
                        .accessibilityHidden(isEnabled)
                }
            }
            .padding(.vertical, -2)
            .animation(.snappy(duration: 0.3), value: isEnabled)
        }
    }
}

#Preview {
    struct DateTimePillPreviewWrapper: View {
        @State private var date = Date()
        @State private var time = Date()

        @State private var options = ["1 Cup", "100 grams"]
        @State private var selection = "1 Cup"

        var body: some View {
            ZStack {
                Color.gray.opacity(0.1).ignoresSafeArea()

                VStack {
                    Card("Entry Details") {
                        RowGroup(.divider) {
                            DropdownPillRow(
                                title: "Portion Size One",
                                options: options,
                                selection: $selection
                            )

                            DropdownPillRow(
                                title: "Portion Size One",
                                options: options,
                                selection: $selection
                            )

                            DateTimePillRow(
                                title: "Date & Time",
                                dateSelection: $date,
                                timeSelection: $time
                            )

                            DateTimePillRow(
                                title: "Date & Time",
                                isEnabled: false,
                                dateSelection: $date,
                                timeSelection: $time,
                            )

                            DropdownPillRow(
                                title: "Portion Size One",
                                options: options,
                                selection: $selection
                            )
                        }
                    }
                    .padding()
                    Spacer()
                }
            }
        }
    }

    return DateTimePillPreviewWrapper()
}
