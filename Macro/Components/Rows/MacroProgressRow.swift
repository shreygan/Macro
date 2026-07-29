//
//  MacroProgressRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/29/26.
//

import SwiftUI

struct MacroProgressRow: View {
    var title: String
    var iconSymbol: AppSymbols
    var tintColor: Color
    var current: Double
    var goal: Double
    var mode: GoalLimitMode
    var unit: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    iconView
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 6) {
                    if mode == .off {
                        Text("\(Int(current)) \(unit)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        let modeText = mode == .floor ? "min" : "max"

                        Text(
                            "\(Int(current)) / \(Int(goal)) \(unit) \(modeText)"
                        )
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                        statusIcon
                            .font(.system(size: 14))
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
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .position(x: geo.size.width / 2, y: 12)

                        Capsule()
                            .fill(tintColor)
                            .frame(width: fillWidth, height: 8)
                            .position(x: fillWidth / 2, y: 12)

                        let isFloor = mode == .floor

                        Text(isFloor ? "[" : "]")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .position(x: markerPosition, y: 11)
                    }
                }
                .frame(height: 24)
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        Image(systemName: iconSymbol.rawValue)
            .font(.system(size: 14))
            .foregroundStyle(tintColor)
            .frame(width: 15)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if mode == .floor {
            if current >= goal {
                Image(systemName: "checkmark")
            } else {
                Image(systemName: "progress.indicator")
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
