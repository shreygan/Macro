//
//  Colors.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/2/26.
//

import SwiftUI

extension Color {
    static let calorie = Color(uiColor: .systemRed)

    static let protein = Color(uiColor: .systemBlue)

    static let carbs = Color(uiColor: .systemGreen)

    static let fat = Color(uiColor: .systemPurple)

    static let fiber = Color(uiColor: .systemYellow)

    private static func tertiaryTextAlpha(_ traits: UITraitCollection) -> CGFloat {
        traits.accessibilityContrast == .high ? 0.54 : 0.3
    }

    static let tertiaryText = Color(
        uiColor: UIColor { traits in
            let base: UIColor = traits.userInterfaceStyle == .dark ? .white : .black
            return base.withAlphaComponent(tertiaryTextAlpha(traits))
        }
    )

    static let solidTertiaryText = Color(
        uiColor: UIColor { traits in
            let alpha = tertiaryTextAlpha(traits)
            return UIColor(white: traits.userInterfaceStyle == .dark ? alpha : 1 - alpha, alpha: 1)
        }
    )

    static let placeholderText = Color(uiColor: .placeholderText)

    static var background: Color {
        Color.gray.opacity(0.15)
    }

    static let controlFill = Color(uiColor: .tertiarySystemFill)

    static let trackFill = Color(uiColor: .systemFill)

    static let segmentTrackUnderlay = Color(uiColor: .tertiarySystemFill).opacity(0.65)

    static let highlightFill = Color(uiColor: .secondarySystemFill)

    static let accentFill = Color.accentColor.opacity(0.15)

    static let progressFill = Color(
        uiColor: UIColor { traits in
            let base: UIColor = traits.userInterfaceStyle == .dark ? .white : .black
            return base.withAlphaComponent(0.55)
        }
    )

    static let destructiveFill = Color.red.opacity(0.1)
}
