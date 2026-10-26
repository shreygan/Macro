//
//  MacroProgressRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/29/26.
//

import SwiftUI

struct GoalMarker: View {
    static let verticalOffset: CGFloat = -1

    var mode: GoalLimitMode

    var body: some View {
        Text(mode == .floor ? "[" : "]")
            .font(.goalMarker)
            .foregroundColor(.primary)
    }
}

struct MacroProgressRow: View {
    var title: String
    var iconSymbol: AppSymbols
    var tintColor: Color
    var current: Double
    var goal: Double
    var mode: GoalLimitMode
    var unit: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    iconView
                    Text(title)
                        .font(.compactTitle)
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 6) {
                    if mode == .off {
                        Text("\(currentText) \(unit)")
                            .font(.compactValue)
                            .foregroundColor(.secondary)
                            .contentTransition(.numericText(value: current))
                    } else {
                        let modeText = mode == .floor ? "min" : "max"

                        Text(
                            "\(currentText) \(unit) / \(Int(goal)) \(unit) \(modeText)"
                        )
                        .font(.compactValue)
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText(value: current))

                        statusIcon
                            .font(.compactValue)
                            .foregroundColor(.primary)
                    }
                }
            }

            if mode != .off {
                GeometryReader { geo in
                    let maxVal = max(current, goal)
                    let safeMax = maxVal == 0 ? 1 : maxVal

                    let fillWidth = (current / safeMax) * geo.size.width
                    let markerPosition = (goal / safeMax) * geo.size.width

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.trackFill)
                            .frame(height: 8)
                            .position(x: geo.size.width / 2, y: 12)

                        Capsule()
                            .fill(tintColor)
                            .frame(width: fillWidth, height: 6)
                            .position(x: fillWidth / 2, y: 12)

                        GoalMarker(mode: mode)
                            .position(x: markerPosition, y: 12 + GoalMarker.verticalOffset)
                    }
                }
                .frame(height: 14)
            }
        }
    }

    private var currentText: Text {
        Text("\(Int(current))")
            .font(.compactTitle)
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var iconView: some View {
        Image(systemName: iconSymbol.rawValue)
            .font(.rowIcon)
            .foregroundStyle(tintColor)
            .frame(width: 15)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if mode == .floor {
            if current >= goal {
                Image(systemName: "checkmark")
            } else {
                Image(systemName: "xmark")
            }
        } else if mode == .ceiling {
            if current <= goal {
                Image(systemName: "checkmark")
            } else {
                Image(systemName: "xmark")
            }
        }
    }
}
