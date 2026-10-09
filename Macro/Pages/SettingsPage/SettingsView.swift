//
//  SettingsView.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import SwiftData
import SwiftUI

extension EnvironmentValues {
    @Entry var dismissSettings: () -> Void = {}
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.eraseAllData) private var eraseAllData
    @Environment(\.toastCenter) private var toastCenter

    @Query private var users: [User]

    @State private var showDeleteConfirmation = false

    private let maxDayStartMinutes = 12 * 60

    private var dayStartRange: ClosedRange<Date> {
        let midnight = Calendar.current.startOfDay(for: Date())
        let latest =
            Calendar.current.date(
                byAdding: .minute,
                value: maxDayStartMinutes,
                to: midnight
            ) ?? midnight
        return midnight...latest
    }

    private var dayStartSelection: Binding<Date> {
        Binding(
            get: {
                let midnight = dayStartRange.lowerBound
                return Calendar.current.date(
                    byAdding: .minute,
                    value: users.first?.dayStartMinutes ?? 0,
                    to: midnight
                ) ?? midnight
            },
            set: { newValue in
                guard let user = users.first else { return }
                let components = Calendar.current.dateComponents(
                    [.hour, .minute],
                    from: newValue
                )
                let minutes =
                    (components.hour ?? 0) * 60 + (components.minute ?? 0)
                user.dayStartMinutes = min(minutes, maxDayStartMinutes)
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    toastCenter?.show(.failure(String(localized: "Couldn't Save Day Start")))
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Card("Goals") {
                            RowGroup(.divider) {
                                NavigationLink {
                                    GoalSetupView(
                                        isCalorieActive: .constant(false),
                                        isProteinActive: .constant(false),
                                        isCarbsActive: .constant(false),
                                        isFatActive: .constant(false),
                                        isFiberActive: .constant(false)
                                    )
                                } label: {
                                    NavigationRow(
                                        icon: .customSymbol("target"),
                                        title: "Macro Goals"
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if let user = users.first {
                                    NavigationLink {
                                        GoalHistoryView(user: user)
                                    } label: {
                                        NavigationRow(
                                            icon: .customSymbol(
                                                "clock.arrow.circlepath"
                                            ),
                                            title: "Goal History"
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)

                        if users.first != nil {
                            Card("Tracking") {
                                BaseRowLayout(
                                    icon: .customSymbol("sunrise"),
                                    title: "Day Starts At",
                                    info:
                                        "Meals logged before this time count toward the previous day."
                                ) {
                                    DateTimePill(
                                        selection: dayStartSelection,
                                        components: .hourAndMinute,
                                        range: dayStartRange
                                    )
                                    .padding(.trailing, -5)
                                    .padding(.vertical, -2)
                                }
                            }
                            .padding([.top, .leading, .trailing])
                        }

                        Card("Data") {
                            RowGroup(.divider) {
                                NavigationLink {
                                    ImportView()
                                } label: {
                                    NavigationRow(
                                        icon: .customSymbol(
                                            "square.and.arrow.down"
                                        ),
                                        title: "Import"
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    ExportView()
                                } label: {
                                    NavigationRow(
                                        icon: .customSymbol(
                                            "square.and.arrow.up"
                                        ),
                                        title: "Export"
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Card("Reset") {
                            InformationRow(
                                description:
                                    "Permanently removes all logged entries, saved foods, goals, and personal data from this device. This action cannot be undone."
                            )

                            ButtonRow(
                                icon: .customSymbol("trash", tint: .red),
                                title: "Delete All Data",
                                tint: .red.opacity(0.1),
                                textColor: .red,
                                topPadding: 0
                            ) {
                                showDeleteConfirmation = true
                            }
                        }
                        .padding([.top, .horizontal])
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    dismiss()
                    eraseAllData()
                }
            } message: {
                Text(
                    "This will permanently delete all your logged entries, saved foods, and personal data. This action cannot be undone."
                )
            }
        }
        .environment(\.dismissSettings, { dismiss() })
    }
}

#Preview {
    SettingsView()
}
