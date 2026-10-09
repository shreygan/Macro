//
//  ToastSystem.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/7/26.
//

import SwiftUI

struct Toast: Identifiable {
    struct Action {
        var title: String
        var handler: () -> Void
    }

    enum Kind {
        case info, success, warning, error

        var feedback: SensoryFeedback {
            switch self {
            case .info: .impact(weight: .light)
            case .success: .success
            case .warning: .warning
            case .error: .error
            }
        }
    }

    let id = UUID()
    var group: String? = nil
    var kind: Kind = .info
    var symbol: String
    var tint: Color = .accentColor
    var title: String
    var message: String? = nil
    var duration: TimeInterval? = nil
    var action: Action? = nil
    var secondaryAction: Action? = nil

    var displayDuration: TimeInterval {
        duration ?? (action == nil ? 5 : secondaryAction == nil ? 7 : 9)
    }
}

extension EnvironmentValues {
    @Entry var toastCenter: ToastCenter? = nil
}

@MainActor
@Observable
final class ToastCenter {
    private(set) var current: Toast?
    var isSceneActive = true
    @ObservationIgnored var toastFrame: CGRect = .null
    @ObservationIgnored weak var windowScene: UIWindowScene?
    @ObservationIgnored private var queue: [Toast] = []
    @ObservationIgnored private var isAdvancing = false

    private let exitGap: Duration = .seconds(0.35)

    func show(_ toast: Toast) {
        if let group = toast.group {
            if let current, current.group == group {
                queue.removeAll { $0.group == group }
                queue.insert(toast, at: 0)
                dismiss(current)
                return
            }
            if let index = queue.firstIndex(where: { $0.group == group }) {
                queue.removeAll { $0.group == group }
                queue.insert(toast, at: index)
                return
            }
        }

        guard current == nil, !isAdvancing else {
            queue.append(toast)
            return
        }
        present(toast)
    }

    func dismiss(_ toast: Toast) {
        guard current?.id == toast.id else { return }
        toastFrame = .null
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            current = nil
        }

        isAdvancing = true
        Task {
            try? await Task.sleep(for: exitGap)
            isAdvancing = false
            if !queue.isEmpty {
                present(queue.removeFirst())
            }
        }
    }

    private func present(_ toast: Toast) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            current = toast
        }
    }

    func presentSheet<Content: View>(_ content: Content) {
        guard let scene = windowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow && !($0 is ToastWindow) })
                ?? scene.windows.first(where: { !($0 is ToastWindow) }),
            var top = window.rootViewController
        else { return }

        while let presented = top.presentedViewController {
            if presented.isBeingDismissed {
                presented.transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] _ in
                    self?.presentSheet(content)
                }
                return
            }
            top = presented
        }

        let host = UIHostingController(rootView: content.environment(\.toastCenter, self))
        top.present(host, animated: true)
    }
}

struct ToastHostModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var center = ToastCenter()
    @State private var window: ToastWindow?

    func body(content: Content) -> some View {
        content
            .environment(\.toastCenter, center)
            .onChange(of: scenePhase, initial: true) { _, phase in
                center.isSceneActive = phase == .active
            }
            .background {
                WindowSceneReader { scene in
                    guard window?.windowScene !== scene else { return }
                    center.windowScene = scene
                    window = ToastWindow(windowScene: scene, center: center)
                }
            }
    }
}

private struct ToastOverlay: View {
    let center: ToastCenter

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            if let toast = center.current {
                ToastView(toast: toast, isSceneActive: center.isSceneActive) {
                    center.dismiss(toast)
                }
                .id(toast.id)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    if center.current?.id == toast.id {
                        center.toastFrame = frame
                    }
                }
                .transition(
                    .move(edge: .top)
                        .combined(with: .scale(scale: 0.85, anchor: .top))
                        .combined(with: .opacity)
                )
            }
        }
        .sensoryFeedback(trigger: center.current?.id) { _, _ in
            center.current?.kind.feedback
        }
    }
}

private final class ToastWindow: UIWindow {
    private let toastCenter: ToastCenter

    init(windowScene: UIWindowScene, center: ToastCenter) {
        self.toastCenter = center
        super.init(windowScene: windowScene)

        let host = UIHostingController(rootView: ToastOverlay(center: center))
        host.view.backgroundColor = .clear
        rootViewController = host
        backgroundColor = .clear
        windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        isHidden = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard toastCenter.current != nil, toastCenter.toastFrame.contains(point) else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

private struct WindowSceneReader: UIViewRepresentable {
    var onResolve: (UIWindowScene) -> Void

    func makeUIView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onResolve = onResolve
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ReaderView, context: Context) {
        uiView.onResolve = onResolve
    }

    final class ReaderView: UIView {
        var onResolve: ((UIWindowScene) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let scene = window?.windowScene else { return }
            Task { @MainActor [weak self] in
                self?.onResolve?(scene)
            }
        }
    }
}

extension View {
    func toastHost() -> some View {
        self.modifier(ToastHostModifier())
    }
}

struct ToastView: View {
    let toast: Toast
    var isSceneActive = true
    var onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var elapsed: TimeInterval = 0
    @State private var resumedAt: Date? = nil
    @GestureState private var isDragging = false

    private let exitLead: TimeInterval = 0.4

    private var isPaused: Bool {
        isDragging || !isSceneActive
    }

    private var isStacked: Bool {
        toast.action != nil && toast.secondaryAction != nil
    }

    private var shape: AnyShape {
        isStacked
            ? AnyShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            : AnyShape(Capsule())
    }

    var body: some View {
        Group {
            if let primary = toast.action, let secondary = toast.secondaryAction {
                VStack(spacing: 12) {
                    header

                    HStack(spacing: 8) {
                        actionButton(secondary, foreground: .secondary, fillsWidth: true)
                        actionButton(primary, foreground: toast.tint, fillsWidth: true)
                    }
                }
            } else {
                HStack(spacing: 14) {
                    header

                    if let action = toast.action {
                        actionButton(action, foreground: toast.tint, fillsWidth: false)
                    }
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, isStacked ? 12 : 14)
        .padding(.vertical, 12)
        .overlay(
            shape.stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                .padding(0.75)
        )
        .glassEffect(
            .regular.tint(Color(white: 0.96).opacity(0.7)).interactive(),
            in: shape
        )
        .padding(.horizontal, 12)
        .padding(.top, -0.5)
        .offset(y: dragOffset)
        .highPriorityGesture(dragGesture)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Dismiss", onDismiss)
        .onAppear {
            AccessibilityNotification.Announcement(toast.title).post()
        }
        .task(id: isPaused) {
            if isPaused {
                if let resumedAt {
                    elapsed += Date.now.timeIntervalSince(resumedAt)
                }
                resumedAt = nil
                return
            }

            resumedAt = .now
            let remaining = toast.displayDuration - elapsed - exitLead
            try? await Task.sleep(for: .seconds(max(remaining, 0)))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            TimelineView(.animation(paused: resumedAt == nil)) { context in
                countdownIcon(progress: progress(at: context.date))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(toast.title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)

                if let message = toast.message {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func actionButton(
        _ action: Toast.Action,
        foreground: Color,
        fillsWidth: Bool
    ) -> some View {
        Button {
            action.handler()
            onDismiss()
        } label: {
            Text(action.title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(foreground)
                .padding(.horizontal, 16)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(height: 36)
                .background(Capsule().fill(Color.gray.opacity(0.1)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func countdownIcon(progress: Double) -> some View {
        ZStack {
            Circle()
                .fill(toast.tint.opacity(0.15))

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    toast.tint,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(1.5)

            Image(systemName: toast.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(toast.tint)
        }
        .frame(width: 44, height: 44)
    }

    private func progress(at date: Date) -> Double {
        let running = resumedAt.map { date.timeIntervalSince($0) } ?? 0
        return max(0, 1 - (elapsed + running) / toast.displayDuration)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                let translation = value.translation.height
                dragOffset =
                    translation < 0
                    ? translation
                    : translation / (1 + translation / 60)
            }
            .onEnded { value in
                if value.translation.height < -30
                    || value.predictedEndTranslation.height < -100
                {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

#Preview {
    @Previewable @State var center = ToastCenter()

    ZStack {
        Color.background.ignoresSafeArea()

        VStack(spacing: 20) {
            Button("Show Toast") {
                center.show(
                    Toast(
                        symbol: "checkmark",
                        tint: .carbs,
                        title: "Entry Logged",
                        message: "Chicken Bowl · 540 kcal",
                        action: Toast.Action(title: "Undo") {}
                    )
                )
            }

            Button("Show Two-Action Toast") {
                center.show(
                    Toast(
                        symbol: "checkmark",
                        tint: .carbs,
                        title: "Entry Logged",
                        message: "Chicken Bowl · 540 kcal",
                        action: Toast.Action(title: "View Entry") {},
                        secondaryAction: Toast.Action(title: "Undo") {}
                    )
                )
            }
        }
    }
    .overlay(alignment: .top) {
        if let toast = center.current {
            ToastView(toast: toast) { center.dismiss(toast) }
                .id(toast.id)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
