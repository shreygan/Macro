//
//  DrinkIconSheet.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import SwiftUI

struct DrinkIconSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var symbol: String
    @Binding var tint: DrinkTint

    @State private var scrollPosition = ScrollPosition(idType: String.self)

    private let symbolColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)
    private let tintColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)

    private var subtitle: String {
        [DrinkSymbol.label(for: symbol), tint.name].compactMap(\.self).joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        ForEach(DrinkSymbol.groups) { group in
                            Card(group.title) {
                                LazyVGrid(columns: symbolColumns, spacing: 10) {
                                    ForEach(group.options, id: \.symbol) { option in
                                        symbolButton(option)
                                    }
                                }
                                .padding(16)
                            }
                            .padding(.horizontal)
                            .padding(.top, group.id == DrinkSymbol.groups.first?.id ? 0 : nil)
                            .id(group.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.bottom)
                }
                .scrollPosition($scrollPosition)
                .safeAreaBar(edge: .top) {
                    colorCard
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                }
                .onAppear {
                    if let group = DrinkSymbol.group(containing: symbol) {
                        scrollPosition.scrollTo(id: group.id, anchor: .center)
                    }
                }
            }
            .navigationTitle("Icon & Color")
            .navigationSubtitle(subtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.large])
    }

    private var colorCard: some View {
        Card {
            LazyVGrid(columns: tintColumns, spacing: 8) {
                ForEach(DrinkTint.allCases, id: \.self) { option in
                    tintButton(option)
                }
            }
            .padding(16)
        }
    }

    private func tintButton(_ option: DrinkTint) -> some View {
        let isSelected = option == tint
        return Button {
            tint = option
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: 26, height: 26)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.tag)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func symbolButton(_ option: DrinkSymbol.Option) -> some View {
        let isSelected = option.symbol == symbol
        return Button {
            symbol = option.symbol
        } label: {
            Image(symbol: option.symbol)
                .font(.largeIcon)
                .foregroundStyle(isSelected ? Color.white : tint.color)
                .frame(width: 46, height: 46)
                .background(Circle().fill(isSelected ? tint.color : Color.controlFill))
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var symbol = "drop.fill"
    @Previewable @State var tint = DrinkTint.blue

    DrinkIconSheet(symbol: $symbol, tint: $tint)
}
