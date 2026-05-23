//
//  GoalSlider.swift
//  Macro
//
//  Initially created by Arjun Dureja as ModernSlider.
//  Forked to GoalSlider by Shrey Gangwar on 4/28/26.
//

import SwiftUI

private let formatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return f
}()

private let editingFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.usesGroupingSeparator = false
    f.maximumFractionDigits = 0
    return f
}()

public enum GoalLimitMode: String, CaseIterable, Codable {
    case ceiling = "Ceiling"
    case floor = "Floor"
    case off = "Off"
}

private func formatNumber(_ value: Double) -> String {
    formatter.string(from: NSNumber(value: value)) ?? String(value)
}

/// `GoalSlider` is a customizable slider component for Macro's onboarding flow.
///
/// # Parameters
///
/// - `title`: An optional title string for the slider.
/// - `titleIcon`: An optional Icon displayed in the title.
/// - `titleFontSize`: Font size for the title. Defaults to 20.
/// - `unit`: The slider values unit. Defaults to 'kcal'.
/// - `trackWidth`: The width of the slider track. Defaults to 235.
/// - `trackHeight`: The height of the slider track and fill. Defaults to 50.
/// - `fillColor`: The color of the slider's filled track area. Defaults to white.
/// - `trackFill`: The color of the slider's background track. Defaults to secondary with opacity.
/// - `trackStroke`: The color of the slider's border stroke. Defaults to primary with opacity.
/// - `value`: A binding to the current value of the slider.
/// - `range`: A closed range representing the minimum and maximum values for the slider. Defaults to 0...100.
/// - `onChange`: An optional closure that is called when the slider value changes.
/// - `onChangeEnd`: An optional closure that is called when the dragging ends.
/// - `onEditingChange`: An optional closure that is called when manual editing changes.
///
public struct GoalSlider: View {
    @State private var offset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var displayText: String = ""

    @Binding var limitMode: GoalLimitMode
    @State private var lastActiveMode: GoalLimitMode = .ceiling

    @FocusState private var isEditingNumber: Bool

    @Binding private var value: Double

    private let title: String?
    private let titleIcon: RowIcon?
    private let titleFontSize: CGFloat
    private let unit: String
    private let trackWidth: CGFloat
    private let trackHeight: CGFloat
    private let fillColor: Color
    private let trackFill: Color
    private let trackStroke: Color
    private let range: ClosedRange<Double>
    private let onChange: ((Double) -> Void)?
    private let onChangeEnd: ((Double) -> Void)?
    private let onEditingChanged: ((Bool) -> Void)?

    private let textFontSize: CGFloat = 12

    init(
        _ title: String? = nil,
        titleIcon: RowIcon? = nil,
        titleFontSize: CGFloat = 20,
        unit: String = "kcal",
        trackWidth: CGFloat = 325,
        trackHeight: CGFloat = 50,
        fillColor: Color = .white,
        trackFill: Color? = nil,
        trackStroke: Color? = nil,
        value: Binding<Double>,
        limitMode: Binding<GoalLimitMode>,
        in range: ClosedRange<Double> = 0...100,
        onChange: ((Double) -> Void)? = nil,
        onChangeEnd: ((Double) -> Void)? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self.titleIcon = titleIcon
        self.titleFontSize = titleFontSize
        self.unit = unit
        self.trackWidth = trackWidth
        self.trackHeight = trackHeight
        self.fillColor = fillColor
        self.trackFill = trackFill ?? .secondary.opacity(0.3)
        self.trackStroke = trackStroke ?? .primary.opacity(0.15)
        self._value = value
        self._limitMode = limitMode
        self._displayText = State(
            initialValue: formatNumber(value.wrappedValue)
        )
        self.range = range
        self.onChange = onChange
        self.onChangeEnd = onChangeEnd
        self.onEditingChanged = onEditingChanged
    }

    private var halfTrackHeight: CGFloat {
        trackHeight / 2
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let title {
                HStack(alignment: .center, spacing: 4) {
                    if let icon = titleIcon {
                        switch icon {
                        case .custom(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(height: titleFontSize * 1.4)
                                .alignmentGuide(.lastTextBaseline) {
                                    dimensions in
                                    dimensions.height * 0.75
                                }

                        case .appSymbol(let symbol, let tint):
                            Image(systemName: symbol.rawValue)
                                .font(.system(size: titleFontSize * 0.7))
                                .foregroundColor(tint)

                        case .customSymbol(let name, let tint):
                            Image(systemName: name)
                                .font(.system(size: titleFontSize * 0.7))
                                .foregroundColor(tint)
                        }
                    }

                    Text(title)
                        .fontWeight(.bold)
                        .font(.system(size: titleFontSize))

                    Spacer()

                    HStack(spacing: 4) {
                        TextField("", text: $displayText)
                            .focused($isEditingNumber)
                            .font(.system(size: textFontSize))
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 30)
                            .keyboardType(.decimalPad)
                            .onSubmit {
                                isEditingNumber = false

                                if let newValue = formatter.number(
                                    from: displayText
                                )?.doubleValue {
                                    let customValue = max(
                                        range.lowerBound,
                                        newValue
                                    )

                                    withAnimation(
                                        .interactiveSpring(
                                            response: 0.4,
                                            dampingFraction: 0.65
                                        )
                                    ) {
                                        self.value = customValue
                                    }
                                    displayText = formatNumber(customValue)
                                }
                            }
                            .onChange(of: isEditingNumber) { _, isFocused in
                                if isFocused {
                                    if limitMode == .off {
                                        withAnimation(.easeInOut(duration: 0.3))
                                        {
                                            limitMode = lastActiveMode
                                        }
                                    }

                                    displayText =
                                        editingFormatter.string(
                                            from: NSNumber(value: value)
                                        ) ?? String(value)
                                } else {
                                    let parsedValue =
                                        editingFormatter.number(
                                            from: displayText
                                        )?.doubleValue
                                        ?? formatter.number(from: displayText)?
                                        .doubleValue

                                    if let newValue = parsedValue {
                                        let customValue = max(
                                            range.lowerBound,
                                            newValue
                                        )

                                        withAnimation(
                                            .interactiveSpring(
                                                response: 0.4,
                                                dampingFraction: 0.65
                                            )
                                        ) {
                                            self.value = customValue
                                        }
                                    }

                                    displayText = formatNumber(value)
                                }
                            }

                        Text(unit)
                            .font(.system(size: textFontSize))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.tertiarySystemFill))
                            .scaleEffect(isEditingNumber ? 0.925 : 1.0)
                            .animation(
                                .interactiveSpring(
                                    response: 0.3,
                                    dampingFraction: 0.6
                                ),
                                value: isEditingNumber
                            )
                    )
                    .opacity(limitMode == .off ? 0.4 : 1.0)

                }
                .foregroundStyle(Color.primary)
            }

            SliderView(
                offset: $offset,
                isDragging: $isDragging,
                limitMode: $limitMode,
                lastActiveMode: lastActiveMode,
                trackWidth: trackWidth,
                trackHeight: trackHeight,
                halfTrackHeight: halfTrackHeight,
                fillColor: fillColor,
                trackFill: trackFill,
                trackStroke: trackStroke,
                onChange: updateValue,
                onChangeEnd: { onChangeEnd?(value) },
                onEditingChanged: onEditingChanged
            )
            .opacity(limitMode == .off ? 0.4 : 1.0)

            Picker("Limit Mode", selection: $limitMode) {
                ForEach(GoalLimitMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .scaleEffect(0.7)
            .frame(height: 20)
            .frame(width: trackWidth)
            .padding(.top, 4)
            .onChange(of: limitMode) { _, newMode in
                if newMode != .off {
                    lastActiveMode = newMode
                }
            }
        }
        .frame(width: trackWidth)
        .animation(
            .interactiveSpring(response: 0.4, dampingFraction: 0.65),
            value: value
        )
        .onAppear {
            displayText = formatNumber(value)
            updateOffset(to: value)
        }
        .onChange(of: value) { _, newValue in
            if !isEditingNumber {
                displayText = formatNumber(newValue)
            }

            if !isDragging {
                withAnimation(
                    .interactiveSpring(response: 0.4, dampingFraction: 0.65)
                ) {
                    updateOffset(to: newValue)
                }
            } else {
                updateOffset(to: newValue)
            }
        }
    }

    private func updateValue() {
        let percentage = Double(offset / trackWidth)
        value =
            range.lowerBound + percentage
            * (range.upperBound - range.lowerBound)
        onChange?(value)
    }

    private func updateOffset(to value: Double) {
        let visualValue = min(value, range.upperBound)

        let percentage =
            (visualValue - range.lowerBound)
            / (range.upperBound - range.lowerBound)
        offset = percentage * trackWidth
    }
}

private struct SliderView: View {
    @Binding var offset: CGFloat
    @Binding var isDragging: Bool
    @Binding var limitMode: GoalLimitMode

    let lastActiveMode: GoalLimitMode
    let trackWidth: CGFloat
    let trackHeight: CGFloat
    let halfTrackHeight: CGFloat
    let fillColor: Color
    let trackFill: Color
    let trackStroke: Color
    let onChange: () -> Void
    let onChangeEnd: () -> Void
    let onEditingChanged: ((Bool) -> Void)?

    private var sliderFillWidth: CGFloat {
        if limitMode == .off { return 0 }

        let clampedOffset = max(0, min(offset, trackWidth))
        return limitMode == .floor
            ? (trackWidth - clampedOffset) : clampedOffset
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if limitMode == .off {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        limitMode = lastActiveMode
                    }
                }

                if !isDragging {
                    isDragging = true
                    onEditingChanged?(true)
                }
                updateOffset(at: value.location.x)
                onChange()
            }
            .onEnded { _ in
                isDragging = false
                onEditingChanged?(false)
                onChangeEnd()
            }
    }

    var body: some View {
        ZStack(alignment: limitMode == .floor ? .trailing : .leading) {
            sliderTrack
            sliderFill
        }
        .frame(width: trackWidth, height: trackHeight)
        .clipShape(Capsule())
        .scaleEffect(isDragging ? 0.97 : 1.0)
        .animation(
            .interactiveSpring(response: 0.3, dampingFraction: 0.6),
            value: isDragging
        )
        .animation(.easeInOut(duration: 0.3), value: limitMode)
        .highPriorityGesture(dragGesture)
    }

    private var sliderTrack: some View {
        Capsule()
            .fill(trackFill)
            .frame(width: trackWidth, height: trackHeight)
            .overlay(
                Capsule()
                    .stroke(trackStroke, lineWidth: 0.25)
            )
    }

    private var sliderFill: some View {
        Rectangle()
            .fill(fillColor)
            .frame(width: sliderFillWidth, height: trackHeight)
    }

    private func updateOffset(at location: CGFloat) {
        offset = max(0, min(location, trackWidth))
    }
}

#Preview {
    VStack(spacing: 20) {
        GoalSlider(
            "Calories",
            titleIcon: .custom(Image("Calorie")),
            titleFontSize: 20,
            unit: "kcal",
            fillColor: Color.red,
            value: .constant(2000),
            limitMode: .constant(.ceiling),
            in: 0...4000
        )

        GoalSlider(
            "Calories",
            titleIcon: .calorie,
            titleFontSize: 20,
            unit: "kcal",
            fillColor: Color.red,
            value: .constant(2000),
            limitMode: .constant(.ceiling),
            in: 0...4000
        )
    }
}
