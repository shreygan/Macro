//
//  ImportView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/28/26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingFilePicker = false
    @State private var isLoading = false

    @State private var parsedItems: [DraftFoodItem] = []
    @State private var showReviewSheet = false

    @State private var duplicateCount = 0
    @State private var errorCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                VStack {
                    Card("Library Entries") {
                        InformationRow(
                            blocks: [
                                .text(
                                    "Ensure your CSV columns match one of the formats below (headers are optional). Any incomplete or invalid rows will be automatically skipped."
                                ),
                                .title("Detailed Format"),
                                .code(
                                    "TBD"
                                ),
                                .title("Simplified Format"),
                                .code(
                                    "Source\nName\nCalories\nProtein\nCarbohydrates\nFat\nFiber"
                                ),
                            ]
                        )

                        ZStack {
                            if isLoading {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .tint(.blue)
                                    Text("Reading CSV...")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.bottom, 9)
                                .frame(height: 60)
                                .transition(
                                    .opacity.combined(with: .scale(scale: 0.95))
                                )
                            } else {
                                ButtonRow(
                                    icon: .customSymbol(
                                        "tray.and.arrow.down.fill",
                                        tint: .white
                                    ),
                                    title: "Select CSV File",
                                    tint: .blue,
                                    textColor: .white,
                                    topPadding: 8
                                ) {
                                    isShowingFilePicker = true
                                }
                                .transition(
                                    .opacity.combined(with: .scale(scale: 0.95))
                                )
                            }
                        }
                        .animation(.snappy, value: isLoading)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Import Data")
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
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let fileURL = urls.first else { return }

                    isLoading = true
                    processFoodCSV(at: fileURL)
                case .failure(let error):
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
            .navigationDestination(isPresented: $showReviewSheet) {
                ImportReviewView(
                    items: $parsedItems,
                    duplicateCount: $duplicateCount,
                    errorCount: $errorCount,
                    isLoading: $isLoading,
                    onProcessNewCSV: { url in
                        withAnimation(.snappy) {
                            isLoading = true
                            parsedItems = []
                        }
                        processFoodCSV(at: url)
                    },
                    onSaveComplete: {
                        dismiss()
                    }
                )
            }
        }
    }

    private func processFoodCSV(at url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }

        let descriptor = FetchDescriptor<FoodItem>()
        let existingItems = (try? modelContext.fetch(descriptor)) ?? []

        let existingKeys = Set(
            existingItems.map {
                let source =
                    $0.source?.source.lowercased().trimmingCharacters(
                        in: .whitespaces
                    ) ?? ""
                let name = $0.name.lowercased().trimmingCharacters(
                    in: .whitespaces
                )
                return "\(source)-\(name)"
            }
        )

        Task(priority: .userInitiated) {
            defer { url.stopAccessingSecurityScopedResource() }
            try? await Task.sleep(for: .seconds(1))

            do {
                let data = try String(contentsOf: url, encoding: .utf8)
                let lines = data.components(separatedBy: .newlines).filter {
                    !$0.isEmpty
                }

                var extractedItems: [DraftFoodItem] = []
                var seenInCSV = Set<String>()

                var skippedCount = 0
                var invalidCount = 0

                let parseMacro: (String) -> Double? = { str in
                    let trimmed = str.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { return 0.0 }
                    return Double(trimmed)
                }

                for (index, line) in lines.enumerated() {
                    let columns = line.components(separatedBy: ",")

                    guard columns.count >= 7 else {
                        invalidCount += 1
                        continue
                    }

                    let source = columns[0].trimmingCharacters(in: .whitespaces)
                    let name = columns[1].trimmingCharacters(in: .whitespaces)

                    if index == 0
                        && Double(
                            columns[2].trimmingCharacters(in: .whitespaces)
                        ) == nil
                    {
                        continue
                    }

                    if name.isEmpty {
                        invalidCount += 1
                        continue
                    }

                    guard let calories = parseMacro(columns[2]),
                        let protein = parseMacro(columns[3]),
                        let carbs = parseMacro(columns[4]),
                        let fat = parseMacro(columns[5]),
                        let fiber = parseMacro(columns[6])
                    else {
                        invalidCount += 1
                        continue
                    }

                    let lookupKey =
                        "\(source.lowercased())-\(name.lowercased())"
                    if existingKeys.contains(lookupKey)
                        || seenInCSV.contains(lookupKey)
                    {
                        skippedCount += 1
                        continue
                    }

                    seenInCSV.insert(lookupKey)

                    let newItem = DraftFoodItem(
                        name: name,
                        source: source,
                        category: "",
                        foodGroup: "",
                        servingSize: 1.0,
                        servingUnit: "serving",
                        servingWeight: nil,
                        servingWeightUnit: "g",
                        isAIEstimated: false,
                        calories: calories,
                        protein: protein,
                        carbs: carbs,
                        fat: fat,
                        fiber: fiber,
                        isCustomDefaultServing: false,
                        customServingSize: nil
                    )
                    extractedItems.append(newItem)
                }

                await MainActor.run {
                    withAnimation(.snappy) {
                        self.isLoading = false
                        self.duplicateCount = skippedCount
                        self.errorCount = invalidCount
                        self.parsedItems = extractedItems
                    }

                    if !extractedItems.isEmpty || skippedCount > 0
                        || invalidCount > 0
                    {
                        self.showReviewSheet = true
                    }
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

#Preview {
    ImportView()
}
