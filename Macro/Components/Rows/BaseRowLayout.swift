//
//  BaseRowLayout.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct BaseRowLayout<RightContent: View>: View {
    var icon: RowIcon? = nil
    var title: String
    var titleExtension: String? = nil
    var subtitle: String? = nil
    var info: String? = nil
    var thumbnail: RowThumbnail? = nil
    var fitsRightContent: Bool = false

    private let titleFontSize = FontSize.row
    private let rowSpacing: CGFloat = 16

    @ViewBuilder var rightContent: RightContent

    @State private var isShowingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if fitsRightContent {
                FittedRowLayout(spacing: rowSpacing) {
                    titleContent
                    rightContent
                }
            } else {
                HStack(spacing: rowSpacing) {
                    titleContent
                    rightContent
                }
            }

            if let info, isShowingInfo {
                Text(info)
                    .font(.subtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, iconInset)
                    .padding(.top, 6)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var titleContent: some View {
        HStack(spacing: 0) {
            if info != nil {
                leadingContent
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.3)) {
                            isShowingInfo.toggle()
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Shows more information")
            } else {
                leadingContent
            }

            Spacer(minLength: 0)
        }
    }

    private var iconInset: CGFloat {
        if thumbnail != nil { return 48 }
        return icon != nil ? 23 : 0
    }

    private var leadingContent: some View {
        HStack(spacing: 8) {
            if let thumbnail {
                ZStack {
                    Color.controlFill

                    if case .image(let image) = thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 8))
                .unredacted()
                .accessibilityHidden(true)
            } else if let icon = icon {
                switch icon {
                case .appSymbol(let symbol, let tint):
                    Image(systemName: symbol.rawValue)
                        .font(.rowIcon)
                        .foregroundStyle(tint)
                        .frame(width: 15)

                case .customSymbol(let systemName, let tint):
                    Image(systemName: systemName)
                        .font(.rowIcon)
                        .foregroundStyle(tint)
                        .frame(width: 15)

                case .custom(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(height: titleFontSize * 1.4)
                        .scaleEffect(1.4)
                        .alignmentGuide(.lastTextBaseline) { dimensions in
                            dimensions.height * 0.75
                        }
                        .padding(.leading, 4)
                        .frame(width: 15)
                }
            }

            VStack(alignment: .leading, spacing: 2) {

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(title)
                        .font(.rowTitle)
                        .foregroundStyle(.primary)

                    if let titleExtension = titleExtension {
                        Text(titleExtension)
                            .font(.rowValue)
                            .foregroundStyle(Color.tertiaryText)

                    }
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subtitle)
                        .foregroundStyle(Color.tertiaryText)
                }
            }
        }
    }
}

/// A plain `HStack` splits the row evenly between the title and the right content, so a long
/// value truncates at half the row while a short title leaves the rest empty. This gives the
/// title only the width it asks for and hands everything else to the right content.
private struct FittedRowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let widths = widths(for: proposal, subviews: subviews)
        let height = zip(subviews, widths).reduce(CGFloat.zero) { height, pair in
            let size = pair.0.sizeThatFits(
                ProposedViewSize(width: pair.1, height: proposal.height)
            )
            return max(height, size.height)
        }
        return CGSize(width: proposal.replacingUnspecifiedDimensions().width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths(for: proposal, subviews: subviews)) {
            subview.place(
                at: CGPoint(x: x, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }

    private func widths(for proposal: ProposedViewSize, subviews: Subviews) -> [CGFloat] {
        let available = proposal.replacingUnspecifiedDimensions().width
        guard subviews.count == 2 else {
            return subviews.map { _ in available }
        }

        let titleWidth = subviews[0].sizeThatFits(.unspecified).width
        let rightWidth = min(
            subviews[1].sizeThatFits(.unspecified).width,
            max(0, available - titleWidth - spacing)
        )
        return [max(0, available - rightWidth - spacing), rightWidth]
    }
}

#Preview {
    VStack(spacing: 0) {

        BaseRowLayout(
            icon: .custom(Image("Calorie")),
            title: "Calories",
            titleExtension: "(kcal)"
        ) {
            Text("2,450")
                .font(.system(size: 16, weight: .semibold))
        }

        Divider().padding(.horizontal, 14)

        BaseRowLayout(
            icon: .customSymbol("scanner"),
            title: "Calories",
            titleExtension: "(kcal)"
        ) {
            Text("2,450")
        }

        Divider().padding(.horizontal, 14)

        BaseRowLayout(
            title: "Weight",
            titleExtension: "(lbs)",
            subtitle: "Last updated today"
        ) {
            Text("175.2")
                .font(.system(size: 16, weight: .semibold))
        }

        Divider().padding(.horizontal, 14)

        BaseRowLayout(
            icon: .customSymbol("switch.2", tint: .green),
            title: "Simple Row"
        ) {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }

        Divider().padding(.horizontal, 14)

        BaseRowLayout(title: "Simple Row") {
            Text("-")
                .foregroundStyle(Color.tertiaryText)
        }

    }
    .background(Color(white: 0.96))
    .cornerRadius(24)
    .padding()
}
