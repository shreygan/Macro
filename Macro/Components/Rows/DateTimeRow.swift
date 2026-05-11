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
    
    @Binding var dateSelection: Date
    @Binding var timeSelection: Date

    var body: some View {
        BaseRowLayout(
            icon: icon,
            title: title,
            titleExtension: titleExtension,
            subtitle: subtitle
        ) {
            HStack(spacing: 8) {
                Spacer()
                
                DateTimePill(selection: $dateSelection, components: .date)
                    .padding(.trailing, -10)
                DateTimePill(selection: $timeSelection, components: .hourAndMinute)
            }
            .padding(.vertical, -2)
        }
    }
}

private struct DateTimePill: View {
    @Binding var selection: Date
    var components: DatePickerComponents
    
    var body: some View {
        ZStack {
            Text(selection, format: components == .date ?
                 .dateTime.month().day().year() :
                 .dateTime.hour().minute())
                .font(.system(size: 16))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(UIColor.tertiarySystemFill))
                )
                .allowsHitTesting(false)

            DatePicker("", selection: $selection, displayedComponents: components)
                .labelsHidden()
                .opacity(0.011)
                .clipped()
        }
        .fixedSize()
        .contentShape(Capsule())
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
