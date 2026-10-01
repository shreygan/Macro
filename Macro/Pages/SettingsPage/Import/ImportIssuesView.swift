//
//  ImportIssuesView.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import SwiftUI

struct ImportIssuesView: View {
    @Environment(\.dismiss) private var dismiss

    let kind: ImportIssue.Kind
    let issues: [ImportIssue]

    private var title: String {
        switch kind {
        case .duplicate: return "Duplicates"
        case .repeated: return "Repeated Rows"
        case .invalid: return "Errors"
        }
    }

    private var description: String {
        switch kind {
        case .duplicate:
            return "These rows match something you already have. Choose how to handle them with Handle Duplicates on the review screen."
        case .repeated:
            return "These rows repeat an earlier row in the same file, so only the first one is imported."
        case .invalid:
            return "These rows couldn't be read and were skipped. Fix them in your CSV and import it again."
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom, 4)

                        Card {
                            RowGroup(.divider) {
                                ForEach(issues) { issue in
                                    BaseRowLayout(
                                        title: issue.name ?? "Row \(issue.row)",
                                        subtitle: issue.reason
                                    ) {
                                        if issue.name != nil {
                                            Text("Row \(issue.row)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("\(title) (\(issues.count))")
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
        }
    }
}

#Preview {
    ImportIssuesView(
        kind: .invalid,
        issues: [
            ImportIssue(
                kind: .invalid,
                row: 4,
                name: "Greek Yogurt",
                reason: "\"abc\" isn't a valid number for Calories."
            ),
            ImportIssue(
                kind: .invalid,
                row: 9,
                name: nil,
                reason: "Entry is missing a name."
            ),
        ]
    )
}
