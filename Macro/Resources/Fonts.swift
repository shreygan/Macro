//
//  Fonts.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/10/26.
//

import SwiftUI

enum FontSize {
    static let row: CGFloat = 16

    static let rowLineHeight: CGFloat = UIFont.systemFont(ofSize: row).lineHeight

    static let display: CGFloat = 20
}

extension Font {
    static let rowTitle = Font.system(size: FontSize.row, weight: .medium)

    static let rowValue = Font.system(size: FontSize.row)

    static let statValue = Font.system(size: FontSize.row, weight: .semibold, design: .rounded)

    static let compactTitle = Font.system(size: 14, weight: .medium)

    static let compactValue = Font.system(size: 14)

    static let cardTitle = Font.system(size: 14, weight: .bold)

    static let sectionTitle = Font.system(size: 14, weight: .semibold)

    static let subtitle = Font.system(size: 13)

    static let detail = Font.system(size: 12)

    static let detailEmphasis = Font.system(size: 12, weight: .semibold)

    static let tag = Font.system(size: 11, weight: .semibold)

    static let swipeLabel = Font.system(size: 10, weight: .medium)

    static let characterCount = Font.system(size: 8)

    static let rowButton = Font.system(size: 14, design: .rounded)

    static let prominentButton = Font.system(size: 15, weight: .semibold, design: .rounded)

    static let display = Font.system(size: FontSize.display, weight: .bold)

    static let wordmark = Font.system(size: 34, weight: .bold)

    static let pageTitle = Font.system(size: 22, weight: .bold, design: .rounded)

    static let statusLabel = Font.system(size: 15, weight: .medium)

    static let bullet = Font.system(size: 13, weight: .bold)

    static let chevron = Font.system(size: 14, weight: .semibold)

    static let dropdownChevron = Font.system(size: 12, weight: .semibold)

    static let menuIcon = Font.system(size: 14, weight: .semibold)

    static let rowIcon = Font.system(size: 14)

    static let smallIcon = Font.system(size: 13)

    static let largeIcon = Font.system(size: 22)

    static let buttonIcon = Font.system(size: 14, weight: .medium)
}
