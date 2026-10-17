//
//  TransferStatus.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/16/26.
//

import SwiftUI

struct TransferStatus: View {
    let title: String
    var onCancel: (() -> Void)? = nil

    private static let cancelInset: CGFloat = 20
    private static let cancelGap: CGFloat = 8

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.accentColor)
            Text(title)
                .font(.statusLabel)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())
        }
        .padding(
            .horizontal,
            onCancel == nil ? 0 : Self.cancelInset + TransferCancelButton.size + Self.cancelGap
        )
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            if let onCancel {
                TransferCancelButton(action: onCancel)
                    .padding(.trailing, Self.cancelInset)
            }
        }
    }
}

struct TransferCancelButton: View {
    static let size: CGFloat = 28
    private static let ringWidth: CGFloat = 2.5

    var progress: Double? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.menuIcon)
                .foregroundStyle(.secondary)
                .frame(width: Self.size, height: Self.size)
                .background(Circle().fill(Color.controlFill))
                .overlay {
                    if let progress {
                        if progress > 0 {
                            ring(to: min(progress, 1))
                                .rotationEffect(.degrees(-90))
                                .animation(.snappy, value: progress)
                        } else {
                            TimelineView(.animation) { context in
                                ring(to: 0.25)
                                    .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) * 360))
                            }
                        }
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cancel")
        .accessibilityValue(progress.map { $0 > 0 ? $0.formatted(.percent.precision(.fractionLength(0))) : "" } ?? "")
    }

    private func ring(to end: Double) -> some View {
        Circle()
            .inset(by: Self.ringWidth / 2)
            .trim(from: 0, to: end)
            .stroke(.secondary, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
    }
}

struct TransferRowAccessory: View {
    let progress: Double
    var onCancel: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onCancel {
                TransferCancelButton(progress: progress, action: onCancel)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: TransferCancelButton.size, height: TransferCancelButton.size)
            }
        }
        .padding(.vertical, -2)
        .padding(.trailing, -6)
    }
}

#Preview {
    VStack(spacing: 24) {
        TransferStatus(title: "Uploading Backup... 42%") {}
        TransferStatus(title: "Restoring Backup...")
        HStack(spacing: 24) {
            TransferCancelButton(progress: 0) {}
            TransferCancelButton(progress: 0.42) {}
            TransferRowAccessory(progress: 1)
        }
    }
}
