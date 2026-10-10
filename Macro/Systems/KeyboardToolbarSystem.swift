//
//  KeyboardToolbarSystem.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/14/26.
//

import SwiftUI

enum KeyboardToolbarStyle {
    case done
    case operators
    case fractions
}

struct KeyboardFraction: Identifiable {
    let label: String
    let value: Double

    var id: String { label }

    static let all: [KeyboardFraction] = [
        KeyboardFraction(label: "⅛", value: 1 / 8),
        KeyboardFraction(label: "¼", value: 1 / 4),
        KeyboardFraction(label: "⅓", value: 1 / 3),
        KeyboardFraction(label: "⅜", value: 3 / 8),
        KeyboardFraction(label: "½", value: 1 / 2),
        KeyboardFraction(label: "⅝", value: 5 / 8),
        KeyboardFraction(label: "⅔", value: 2 / 3),
        KeyboardFraction(label: "¾", value: 3 / 4),
        KeyboardFraction(label: "⅞", value: 7 / 8),
    ]

    func applied(to text: String) -> String {
        let operandStart =
            text.lastIndex { KeyboardOperator($0) != nil }
            .map(text.index(after:)) ?? text.startIndex
        let operand = text[operandStart...]

        let whole = Int(operand.prefix { $0 != "." }) ?? 0
        let hundredths = Int((value * 100).rounded(.down))
        var decimals = String(format: "%02d", hundredths)
        while decimals.hasSuffix("0") { decimals.removeLast() }
        let result = decimals.isEmpty ? "\(whole)" : "\(whole).\(decimals)"
        return text[..<operandStart] + result
    }
}

enum KeyboardOperator: String, CaseIterable, Identifiable {
    case add = "+"
    case subtract = "−"
    case multiply = "×"
    case divide = "÷"

    var id: String { rawValue }

    var character: Character { Character(rawValue) }

    var symbolName: String {
        switch self {
        case .add: "plus"
        case .subtract: "minus"
        case .multiply: "multiply"
        case .divide: "divide"
        }
    }

    init?(_ character: Character) {
        self.init(rawValue: String(character))
    }
}

enum KeyboardExpression {
    private static let digits = "0123456789"

    static func containsOperator(_ text: String) -> Bool {
        text.contains { KeyboardOperator($0) != nil }
    }

    static func filtered(_ text: String) -> String {
        var result = ""
        var operandHasDecimal = false

        for character in text {
            if KeyboardOperator(character) != nil {
                result.append(character)
                operandHasDecimal = false
            } else if character == "." {
                guard !operandHasDecimal else { continue }
                operandHasDecimal = true
                result.append(character)
            } else if digits.contains(character) {
                result.append(character)
            }
        }

        return result
    }

    static func evaluate(_ text: String) -> Double? {
        var operands: [Double] = []
        var operators: [KeyboardOperator] = []
        var pending: KeyboardOperator?
        var current = ""

        func flush() -> Bool {
            guard !current.isEmpty else { return true }
            guard let value = current == "." ? 0 : Double(current) else {
                return false
            }
            if !operands.isEmpty {
                operators.append(pending ?? .add)
            }
            operands.append(value)
            pending = nil
            current = ""
            return true
        }

        for character in text {
            if let symbol = KeyboardOperator(character) {
                guard flush() else { return nil }
                pending = symbol
            } else {
                current.append(character)
            }
        }
        guard flush(), let first = operands.first else { return nil }

        var terms = [first]
        var signs: [KeyboardOperator] = []

        for (symbol, value) in zip(operators, operands.dropFirst()) {
            switch symbol {
            case .multiply:
                terms[terms.count - 1] *= value
            case .divide:
                guard value != 0 else { return nil }
                terms[terms.count - 1] /= value
            case .add, .subtract:
                signs.append(symbol)
                terms.append(value)
            }
        }

        var result = terms[0]
        for (symbol, term) in zip(signs, terms.dropFirst()) {
            result += symbol == .add ? term : -term
        }

        return result.isFinite ? result : nil
    }

    static func format(_ value: Double) -> String {
        let rounded = (max(value, 0) * 100).rounded() / 100
        var text = String(format: "%.2f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    static func resolved(_ text: String, fallback: String) -> String {
        guard containsOperator(text) else { return text }
        guard let value = evaluate(text) else { return fallback }
        return format(value)
    }

    static func inserting(
        _ symbol: KeyboardOperator,
        into text: String,
        selection: Range<Int>?
    ) -> (text: String, cursor: Int)? {
        var characters = Array(text)
        let operatorOffsets = characters.indices.filter {
            KeyboardOperator(characters[$0]) != nil
        }

        if let selection {
            let selected = operatorOffsets.first {
                selection.contains($0)
            }
            let touching = operatorOffsets.first {
                $0 + 1 >= selection.lowerBound && $0 <= selection.upperBound
            }
            if let target = selected ?? touching {
                characters[target] = symbol.character
                return (String(characters), target + 1)
            }
        }

        if let last = characters.last, KeyboardOperator(last) != nil {
            characters[characters.count - 1] = symbol.character
            return (String(characters), characters.count)
        }

        guard characters.contains(where: { digits.contains($0) }) else {
            return nil
        }
        characters.append(symbol.character)
        return (String(characters), characters.count)
    }
}

struct KeyboardToolbarActions {
    var canConfirm: Bool = true
    var onCancel: () -> Void
    var onConfirm: () -> Void
}

struct KeyboardToolbarActionsKey: FocusedValueKey {
    typealias Value = KeyboardToolbarActions
}

struct KeyboardToolbarKey: FocusedValueKey {
    typealias Value = KeyboardToolbarStyle
}

struct KeyboardToolbarTextKey: FocusedValueKey {
    typealias Value = Binding<String>
}

struct KeyboardToolbarSelectionKey: FocusedValueKey {
    typealias Value = Binding<TextSelection?>
}

extension FocusedValues {
    /// The property that text fields will broadcast up the view hierarchy
    var activeKeyboardToolbar: KeyboardToolbarStyle? {
        get { self[KeyboardToolbarKey.self] }
        set { self[KeyboardToolbarKey.self] = newValue }
    }

    var keyboardToolbarText: Binding<String>? {
        get { self[KeyboardToolbarTextKey.self] }
        set { self[KeyboardToolbarTextKey.self] = newValue }
    }

    var keyboardToolbarSelection: Binding<TextSelection?>? {
        get { self[KeyboardToolbarSelectionKey.self] }
        set { self[KeyboardToolbarSelectionKey.self] = newValue }
    }

    var keyboardToolbarActions: KeyboardToolbarActions? {
        get { self[KeyboardToolbarActionsKey.self] }
        set { self[KeyboardToolbarActionsKey.self] = newValue }
    }
}

@MainActor
@Observable
final class KeyboardFieldRegistry {
    private static let sameRowTolerance: CGFloat = 12

    private struct Field {
        var frame: CGRect = .zero
        var isEnabled: Bool = true
    }

    private var fields: [UUID: Field] = [:]

    var focusedField: UUID?

    /// Bumped whenever the focused input grows a line, so the page can pull the
    /// new bottom edge back out from under the toolbar.
    private(set) var revealRequest = 0

    private var orderedFields: [UUID] {
        let candidates = fields
            .filter { $0.value.isEnabled }
            .sorted { $0.value.frame.midY < $1.value.frame.midY }

        var rows: [[(key: UUID, value: Field)]] = []

        for candidate in candidates {
            let midY = candidate.value.frame.midY
            if let previous = rows.last?.last,
                abs(midY - previous.value.frame.midY) <= Self.sameRowTolerance
            {
                rows[rows.index(before: rows.endIndex)].append(candidate)
            } else {
                rows.append([candidate])
            }
        }

        return rows.flatMap { row in
            row.sorted { $0.value.frame.minX < $1.value.frame.minX }
                .map(\.key)
        }
    }

    var previousField: UUID? { neighbour(offset: -1) }

    var nextField: UUID? { neighbour(offset: 1) }

    func frame(for id: UUID) -> CGRect? { fields[id]?.frame }

    func update(_ id: UUID, frame: CGRect) {
        let previousHeight = fields[id]?.frame.height
        fields[id, default: Field()].frame = frame

        if id == focusedField, let previousHeight,
            frame.height > previousHeight
        {
            revealRequest += 1
        }
    }

    func setEnabled(_ id: UUID, _ isEnabled: Bool) {
        fields[id, default: Field()].isEnabled = isEnabled
    }

    func remove(_ id: UUID) {
        fields[id] = nil
        if focusedField == id { focusedField = nil }
    }

    private func neighbour(offset: Int) -> UUID? {
        guard let focusedField else { return nil }
        let order = orderedFields
        guard let index = order.firstIndex(of: focusedField) else { return nil }
        let target = index + offset
        return order.indices.contains(target) ? order[target] : nil
    }
}

extension EnvironmentValues {
    @Entry var keyboardFieldRegistry: KeyboardFieldRegistry? = nil
}

extension View {
    /// Attach this to the outermost container of any screen that has text inputs.
    /// Pass `insetsContent: false` alongside `keyboardAvoidingScrollView`, which
    /// reserves the room below the focused input itself.
    func withCustomKeyboardToolbar(insetsContent: Bool = true) -> some View {
        self.modifier(FloatingKeyboardModifier(insetsContent: insetsContent))
    }

    /// Wrap a page that has no scroll view of its own. Without one the keyboard
    /// translates the entire layout upwards, which drags the floating toolbar up
    /// behind the keyboard and can push the focused input off the top of the
    /// screen. A scroll view makes the keyboard inset the content instead.
    func keyboardAvoidingScrollView(alwaysScrollable: Bool) -> some View {
        self.modifier(
            KeyboardAvoidingScrollModifier(alwaysScrollable: alwaysScrollable)
        )
    }

    /// Registers a text field with the page's floating toolbar, so it both broadcasts
    /// the toolbar it wants and joins the previous/next navigation order.
    func autoFloatingToolbar(
        for keyboardType: UIKeyboardType,
        text: Binding<String>? = nil,
        draft: Binding<String>? = nil,
        selection: Binding<TextSelection?>? = nil,
        allowsFractions: Bool = true,
        actions: KeyboardToolbarActions? = nil
    ) -> some View {
        self.modifier(
            KeyboardFieldModifier(
                keyboardType: keyboardType,
                text: text,
                draft: draft,
                selection: selection,
                allowsFractions: allowsFractions,
                actions: actions
            )
        )
    }
}

enum KeyboardToolbarMetrics {
    static let inputClearance: CGFloat = 16
    static let estimatedToolbarHeight: CGFloat = 48

    static var clearance: CGFloat { estimatedToolbarHeight + inputClearance }
}

struct KeyboardAvoidingScrollModifier: ViewModifier {
    let alwaysScrollable: Bool

    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(minHeight: proxy.size.height)
            }
            .scrollDisabled(!alwaysScrollable && keyboardHeight == 0)
            .safeAreaPadding(
                .bottom,
                keyboardHeight == 0
                    ? 0
                    : keyboardHeight + KeyboardToolbarMetrics.clearance
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification
            )
        ) { notification in
            guard
                let frame = notification.userInfo?[
                    UIResponder.keyboardFrameEndUserInfoKey
                ] as? CGRect
            else { return }
            keyboardHeight = frame.height
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification
            )
        ) { _ in
            keyboardHeight = 0
        }
    }
}

struct KeyboardFieldModifier: ViewModifier {
    let keyboardType: UIKeyboardType
    let text: Binding<String>?
    let draft: Binding<String>?
    let selection: Binding<TextSelection?>?
    let allowsFractions: Bool
    let actions: KeyboardToolbarActions?

    @Environment(\.keyboardFieldRegistry) private var registry
    @Environment(\.isEnabled) private var isEnabled

    @FocusState private var isFocused: Bool
    @State private var id = UUID()
    @State private var textAtFocus = ""

    private var displayText: Binding<String>? { draft ?? text }

    private var toolbarStyle: KeyboardToolbarStyle {
        guard keyboardType == .decimalPad, displayText != nil else {
            return .done
        }
        return allowsFractions ? .fractions : .operators
    }

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .id(id)
            .focusedValue(\.activeKeyboardToolbar, toolbarStyle)
            .focusedValue(\.keyboardToolbarText, displayText)
            .focusedValue(\.keyboardToolbarSelection, selection)
            .focusedValue(\.keyboardToolbarActions, actions)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                registry?.update(id, frame: frame)
            }
            .onChange(of: isEnabled, initial: true) { _, enabled in
                registry?.setEnabled(id, enabled)
            }
            .onChange(of: draft?.wrappedValue) {
                commitDraft()
            }
            .onChange(of: text?.wrappedValue, initial: true) {
                syncDraft()
            }
            .onChange(of: isFocused) { _, focused in
                resolveExpression(focused: focused)
                guard let registry else { return }
                if focused {
                    registry.focusedField = id
                } else if registry.focusedField == id {
                    registry.focusedField = nil
                }
            }
            .onChange(of: registry?.focusedField) { _, target in
                if target == id, !isFocused {
                    isFocused = true
                }
            }
            .onDisappear {
                registry?.remove(id)
            }
    }

    private func committedValue(for value: String) -> String? {
        guard toolbarStyle != .done,
            KeyboardExpression.containsOperator(value)
        else { return value }
        return KeyboardExpression.evaluate(value).map(KeyboardExpression.format)
    }

    private func commitDraft() {
        guard let draft, let text,
            let committed = committedValue(for: draft.wrappedValue),
            committed != text.wrappedValue
        else { return }
        text.wrappedValue = committed
    }

    private func syncDraft() {
        guard let draft, let text else { return }
        let committed = committedValue(for: draft.wrappedValue)
        if committed == text.wrappedValue || (committed == nil && isFocused) {
            return
        }
        draft.wrappedValue = text.wrappedValue
    }

    private func resolveExpression(focused: Bool) {
        guard toolbarStyle != .done, let displayText else { return }

        if focused {
            textAtFocus = displayText.wrappedValue
            return
        }

        guard KeyboardExpression.containsOperator(displayText.wrappedValue)
        else { return }

        if let draft, let text {
            draft.wrappedValue = text.wrappedValue
        } else {
            displayText.wrappedValue = KeyboardExpression.resolved(
                displayText.wrappedValue,
                fallback: textAtFocus
            )
        }
    }
}

private enum KeyboardMenu {
    case operators
    case fractions
}

struct FloatingKeyboardModifier: ViewModifier {
    private static let inputClearance = KeyboardToolbarMetrics.inputClearance
    private static let estimatedToolbarHeight =
        KeyboardToolbarMetrics.estimatedToolbarHeight
    private static let menuSpacing: CGFloat = 8

    let insetsContent: Bool

    @State private var isSystemKeyboardVisible = false
    @State private var measuredToolbarHeight: CGFloat?
    @State private var measuredToolbarTop: CGFloat?
    @State private var registry = KeyboardFieldRegistry()
    @State private var expandedMenu: KeyboardMenu?

    @Namespace private var glassNamespace

    @FocusedValue(\.activeKeyboardToolbar) var requestedToolbar
    @FocusedBinding(\.keyboardToolbarText) private var focusedText: String?
    @FocusedValue(\.keyboardToolbarSelection) private var focusedSelection
    @FocusedValue(\.keyboardToolbarActions) private var focusedActions

    private var activeToolbar: KeyboardToolbarStyle? {
        guard isSystemKeyboardVisible else { return nil }
        return requestedToolbar ?? .done
    }

    private var keyboardClearance: CGFloat {
        guard insetsContent, activeToolbar != nil else { return 0 }
        return (measuredToolbarHeight ?? Self.estimatedToolbarHeight)
            + Self.inputClearance
    }

    /// A growing input is only pulled back into view once its bottom edge
    /// reaches the gap above the toolbar, so fields higher up the page are
    /// left where they are.
    private var revealLimit: CGFloat? {
        guard let measuredToolbarTop else { return nil }
        return measuredToolbarTop - Self.inputClearance
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {

            ScrollViewReader { scrollProxy in
                content
                    .environment(\.keyboardFieldRegistry, registry)
                    .scrollDismissesKeyboard(.immediately)
                    .safeAreaPadding(.bottom, keyboardClearance)
                    .animation(
                        .easeOut(duration: 0.25),
                        value: keyboardClearance
                    )
                    .onChange(of: registry.revealRequest) {
                        revealFocusedField(using: scrollProxy)
                    }
                    .onChange(of: registry.focusedField) {
                        expandedMenu = nil
                    }
            }

            if let toolbar = activeToolbar {
                toolbarView(for: toolbar)
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        measuredToolbarHeight = frame.height
                        measuredToolbarTop = frame.minY
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillShowNotification
            )
        ) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                isSystemKeyboardVisible = true
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification
            )
        ) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                isSystemKeyboardVisible = false
            }
            expandedMenu = nil
        }
    }

    @ViewBuilder
    private func toolbarView(for style: KeyboardToolbarStyle) -> some View {
        GlassEffectContainer(spacing: 0) {
            HStack {
                if style == .done, let focusedActions {
                    glassButton(icon: "xmark", action: focusedActions.onCancel)
                        .transition(.opacity)
                }

                if hasFieldNavigation
                    && !(style != .done && expandedMenu != nil)
                {
                    navigationButtons
                        .transition(.opacity)
                }

                Spacer()

                if style != .done {
                    menuSizingReference(count: style == .fractions ? 2 : 1)
                } else if let focusedActions {
                    confirmButton(focusedActions)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .trailing) {
                if style != .done {
                    menuBar(showsFractions: style == .fractions)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var hasFieldNavigation: Bool {
        registry.previousField != nil || registry.nextField != nil
    }

    private var navigationButtons: some View {
        HStack(spacing: 0) {
            navigationButton(
                icon: "chevron.up",
                target: registry.previousField
            )
            navigationButton(
                icon: "chevron.down",
                target: registry.nextField
            )
        }
    }

    private func menuSizingReference(count: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                Button {} label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 20, weight: .semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
        .padding(.vertical, 2)
        .hidden()
    }

    private func menuBar(showsFractions: Bool) -> some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let collapsedWidth = height * (showsFractions ? 2 : 1)
            let expandedWidth = max(
                collapsedWidth,
                proxy.size.width - height - Self.menuSpacing
            )

            HStack(spacing: Self.menuSpacing) {
                if expandedMenu != nil {
                    Button {
                        setExpandedMenu(nil)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: height, height: height)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                }

                Spacer(minLength: 0)

                ZStack {
                    switch expandedMenu {
                    case .operators:
                        operatorOptions
                            .transition(.opacity)
                    case .fractions:
                        fractionOptions(height: height)
                            .transition(.opacity)
                    case nil:
                        HStack(spacing: 0) {
                            menuButton(.operators, size: height) {
                                Image(systemName: "plus.forwardslash.minus")
                                    .font(.system(size: 18, weight: .semibold))
                            }

                            if showsFractions {
                                menuButton(.fractions, size: height) {
                                    Text("½")
                                        .font(.system(size: 20, weight: .semibold))
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .frame(
                    width: expandedMenu == nil ? collapsedWidth : expandedWidth,
                    height: height
                )
                .clipShape(.capsule)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
    }

    private func menuButton<Label: View>(
        _ menu: KeyboardMenu,
        size: CGFloat,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            setExpandedMenu(menu)
        } label: {
            label()
                .frame(width: size, height: size)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var operatorOptions: some View {
        HStack(spacing: 0) {
            ForEach(KeyboardOperator.allCases) { symbol in
                Button {
                    apply(symbol)
                } label: {
                    Image(systemName: symbol.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }

    private func fractionOptions(height: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(KeyboardFraction.all) { fraction in
                    Button {
                        apply(fraction)
                    } label: {
                        Text(fraction.label)
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: height, height: height)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func apply(_ fraction: KeyboardFraction) {
        guard let text = focusedText else { return }
        focusedText = fraction.applied(to: text)
        setExpandedMenu(nil)
    }

    private func apply(_ symbol: KeyboardOperator) {
        defer { setExpandedMenu(nil) }

        guard let text = focusedText,
            let insertion = KeyboardExpression.inserting(
                symbol,
                into: text,
                selection: selectedOffsets(in: text)
            )
        else { return }

        focusedText = insertion.text
        let cursor = insertion.text.index(
            insertion.text.startIndex,
            offsetBy: insertion.cursor
        )
        focusedSelection?.wrappedValue = TextSelection(insertionPoint: cursor)
    }

    private func selectedOffsets(in text: String) -> Range<Int>? {
        guard case .selection(let range) = focusedSelection?.wrappedValue?.indices
        else { return nil }

        func offset(of index: String.Index) -> Int {
            text.indices.prefix { $0 < index }.count
        }

        let lower = offset(of: range.lowerBound)
        let upper = offset(of: range.upperBound)
        return min(lower, upper)..<max(lower, upper)
    }

    private func setExpandedMenu(_ menu: KeyboardMenu?) {
        withAnimation(.bouncy(duration: 0.4)) {
            expandedMenu = menu
        }
    }

    private func navigationButton(icon: String, target: UUID?) -> some View {
        Button {
            registry.focusedField = target
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .glassEffectUnion(id: "keyboardFieldNavigation", namespace: glassNamespace)
        .disabled(target == nil)
    }

    private func confirmButton(_ actions: KeyboardToolbarActions) -> some View {
        Button(action: actions.onConfirm) {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .semibold))
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .disabled(!actions.canConfirm)
    }

    private func glassButton(icon: String, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
    }

    private func revealFocusedField(using proxy: ScrollViewProxy) {
        guard let focusedField = registry.focusedField,
            let frame = registry.frame(for: focusedField),
            let revealLimit,
            frame.maxY > revealLimit
        else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(focusedField, anchor: .bottom)
        }
    }
}

extension UIApplication {
    func dismissKeyboard() {
        sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
