//
//  DrinkFillGlyph.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/21/26.
//

import SwiftUI

struct DrinkFillGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let symbol: String
    let tint: Color
    let fraction: Double
    let animatesLevel: Bool

    @State private var level: Double

    static let size = CGSize(width: 170, height: 210)
    private static let wavePeriod: Double = 3

    init(symbol: String, tint: Color, fraction: Double, animatesLevel: Bool = true) {
        self.symbol = symbol
        self.tint = tint
        self.fraction = fraction
        self.animatesLevel = animatesLevel
        _level = State(initialValue: Self.clamp(fraction))
    }

    private static func clamp(_ fraction: Double) -> Double {
        min(max(fraction, 0), 1)
    }

    var body: some View {
        Image(symbol: symbol)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.trackFill)
            .overlay {
                TimelineView(.animation(paused: reduceMotion || level <= 0 || level >= 1)) { context in
                    let seconds = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: Self.wavePeriod)
                    Image(symbol: symbol)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(tint)
                        .mask {
                            WaveFill(
                                level: level,
                                phase: seconds / Self.wavePeriod * 2 * .pi,
                                amplitude: reduceMotion ? 0 : 3
                            )
                        }
                }
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .onChange(of: Self.clamp(fraction)) { _, newLevel in
                withAnimation(animatesLevel ? .snappy : nil) {
                    level = newLevel
                }
            }
            .accessibilityHidden(true)
    }
}

private struct WaveFill: Shape {
    var level: Double
    var phase: Double
    var amplitude: CGFloat

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let surface = rect.maxY - rect.height * level
        let taper = min(1, min(level, 1 - level) * 10)
        let height = amplitude * taper
        let cycles = 1.5

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for x in stride(from: rect.minX, through: rect.maxX, by: 2) {
            let progress = (x - rect.minX) / rect.width
            let y = surface + height * sin(progress * cycles * 2 * .pi + phase)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    let samples: [(String, DrinkTint, Double)] = [
        ("drop.fill", .blue, 0.5),
        ("mug.fill", .brown, 0.7),
        ("waterbottle.fill", .teal, 0.3),
        ("wineglass.fill", .red, 0.6),
        ("takeoutbag.and.cup.and.straw.fill", .orange, 0.45),
        ("leaf.fill", .green, 0.8),
        ("tumbler.handle.fill", .teal, 0.5),
        ("pitcher.fill", .blue, 0.65),
        ("stickpack.fill", .purple, 0.4),
        ("citrusslice.fill", .orange, 0.55),
        ("cup.boba.fill", .brown, 0.35),
        ("tropicaldrink.fill", .pink, 0.6),
        ("carton.fill", .blue, 0.75),
        ("beerstein.fill", .yellow, 0.5),
    ]

    ZStack {
        Color.background.ignoresSafeArea()
        ScrollView {
            Card {
                LazyVGrid(columns: [GridItem(), GridItem()], spacing: 24) {
                    ForEach(samples, id: \.0) { symbol, tint, fraction in
                        DrinkFillGlyph(symbol: symbol, tint: tint.color, fraction: fraction)
                    }
                }
                .padding(16)
            }
            .padding()
        }
    }
}
