//
//  SavePromptPopover.swift
//  Macro
//

import SwiftUI

struct SavePromptAction {
    let title: String
    var next: SavePromptStep? = nil
    var action: () -> Void = {}
}

struct SavePromptStep {
    let title: String
    let message: String
    let actions: [SavePromptAction]
}

private struct SavePromptPopoverContent: View {
    let step: SavePromptStep
    let onAction: (SavePromptAction) -> Void

    @State private var showsNextStep = false
    @State private var didAct = false
    @State private var firstHeight: CGFloat?
    @State private var nextHeight: CGFloat?

    private var nextStep: SavePromptStep? {
        step.actions.lazy.compactMap(\.next).first
    }

    private var currentHeight: CGFloat? {
        showsNextStep ? nextHeight : firstHeight
    }

    var body: some View {
        stepContent(step)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                firstHeight = $0
            }
            .opacity(showsNextStep ? 0 : 1)
            .allowsHitTesting(!showsNextStep)
            .overlay(alignment: .top) {
                if let nextStep {
                    stepContent(nextStep)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            nextHeight = $0
                        }
                        .opacity(showsNextStep ? 1 : 0)
                        .allowsHitTesting(showsNextStep)
                }
            }
            .frame(width: 300)
            .frame(height: currentHeight, alignment: .top)
            .clipped()
    }

    private func stepContent(_ step: SavePromptStep) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(step.title)
                    .font(.rowTitle)

                Text(step.message)
                    .font(.subtitle)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 8) {
                ForEach(Array(step.actions.enumerated()), id: \.offset) { _, item in
                    ButtonRow(
                        title: item.title,
                        topPadding: 0,
                        bottomPadding: 0
                    ) {
                        if item.next != nil {
                            item.action()
                            withAnimation(.smooth(duration: 0.3)) {
                                showsNextStep = true
                            }
                        } else if !didAct {
                            didAct = true
                            onAction(item)
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
    }
}

private struct SavePromptPopover: ViewModifier {
    @Binding var prompt: SavePromptStep?
    let dismissesScreen: Bool

    @State private var shownPrompt: SavePromptStep?

    private func run(_ item: SavePromptAction) {
        if !dismissesScreen {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                prompt = nil
            }
        }
        item.action()
    }

    func body(content: Content) -> some View {
        content
            .popover(
                isPresented: Binding(
                    get: { prompt != nil },
                    set: { if !$0 { prompt = nil } }
                )
            ) {
                if let step = prompt ?? shownPrompt {
                    SavePromptPopoverContent(step: step, onAction: run)
                        .presentationCompactAdaptation(.popover)
                }
            }
            .onChange(of: prompt != nil) { _, isPresented in
                if isPresented { shownPrompt = prompt }
            }
    }
}

extension View {
    func savePromptPopover(
        _ prompt: Binding<SavePromptStep?>,
        dismissesScreen: Bool = false
    ) -> some View {
        modifier(SavePromptPopover(prompt: prompt, dismissesScreen: dismissesScreen))
    }
}

extension SavePromptStep {
    static func macroCheck(
        _ issue: String,
        confirmTitle: LocalizedStringResource,
        onConfirm: @escaping () -> Void
    ) -> SavePromptStep {
        SavePromptStep(
            title: String(localized: "Check Macros?"),
            message: issue,
            actions: [SavePromptAction(title: String(localized: confirmTitle), action: onConfirm)]
        )
    }

    static func alcoholCheck(
        _ issue: String,
        alcoholCalories: Double,
        next: SavePromptStep? = nil,
        onUse: @escaping () -> Void,
        onSaveAnyway: @escaping () -> Void = {}
    ) -> SavePromptStep {
        SavePromptStep(
            title: String(localized: "Check Macros?"),
            message: issue,
            actions: [
                SavePromptAction(
                    title: String(localized: "Use \(EntryHelper.format(alcoholCalories)) kcal"),
                    next: next,
                    action: onUse
                ),
                SavePromptAction(title: String(localized: "Save Anyway"), next: next, action: onSaveAnyway),
            ]
        )
    }
}
