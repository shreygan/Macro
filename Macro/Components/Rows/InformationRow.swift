//
//  InformationRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/30/26.
//

import SwiftUI

struct InformationRow: View {
    var title: String? = nil
    var blocks: [InformationRowBlock]

    init(title: String? = nil, blocks: [InformationRowBlock]) {
        self.title = title
        self.blocks = blocks
    }

    init(title: String? = nil, description: String, codeSnippet: String? = nil)
    {
        self.title = title

        var defaultBlocks: [InformationRowBlock] = [.text(description)]
        if let code = codeSnippet {
            defaultBlocks.append(.code(code))
        }

        self.blocks = defaultBlocks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(blocks.indices, id: \.self) { index in
                    renderBlock(blocks[index])
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func renderBlock(_ block: InformationRowBlock) -> some View {
        switch block {
        case .text(let string):
            Text(string)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

        case .code(let string):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(string)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.tertiary)

                        Text(item)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 4)

        case .title(let title):
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    ZStack {
        Color.background.ignoresSafeArea()

        VStack {

            Card {
                InformationRow(
                    title: "Title",
                    description: "Testing",
                    codeSnippet: "test\ntest\ntest"
                )
            }
            .padding([.horizontal, .vertical])

            Card {
                InformationRow(
                    title: "Testing",
                    blocks: [
                        .text(
                            "Your file must include a header row with exact columns. Missing data will be handled as follows:"
                        ),
                        .bullets([
                            "Calories, protein, carbs, and fat are strictly required.",
                            "If fiber is missing, it defaults to 0g.",
                            "Serving weight units must be standard (g, oz, ml).",
                        ]),
                        .code(
                            "name, type, calories, protein, carbs, fat, fiber, servingSize, servingWeightUnit"
                        ),
                        .title("Testing"),
                        .title("Another Title"),
                        .text(
                            "Make sure to export your spreadsheet using UTF-8 encoding to prevent formatting issues."
                        ),
                    ]
                )
            }
            .padding([.horizontal, .bottom])
        }
    }
}
