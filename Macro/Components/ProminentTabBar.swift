//
//  ProminentTabBar.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import SwiftUI

protocol ProminentTabItem: CaseIterable, Hashable {
    var symbol: String { get }
    var title: String { get }
}

struct PopoverDragState: Equatable {
    var location: CGPoint? = nil
    var releaseLocation: CGPoint? = nil
    var releaseCount = 0
}

extension EnvironmentValues {
    @Entry var popoverDrag = PopoverDragState()
}

struct ProminentTabBar<Item: ProminentTabItem, SheetContent: View, PopoverContent: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var namespace

    @Binding var selection: Item
    var prominentSymbol: String
    var prominentLabel: LocalizedStringKey = "Add"
    var popoverActionLabel: LocalizedStringKey = "More Options"
    @ContentBuilder var sheet: SheetContent
    @ContentBuilder var popover: PopoverContent

    @State private var showSheet: Bool = false
    @State private var showPopover: Bool = false
    @State private var popoverDrag = PopoverDragState()
    @State private var holdEndedAt: Date = .distantPast
    @State private var holdOrigin: CGPoint? = nil
    @State private var isTrackingDrag = false
    @GestureState private var isHolding = false

    var body: some View {
        let tabCount = Item.allCases.count
        let isSmall = tabCount <= 2 || horizontalSizeClass == .regular
        
        
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                CustomProminentTabBar(selection: $selection)
                    .padding(2)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .frame(width: isSmall ? CGFloat(tabCount) * 90 : nil)
                    .frame(maxWidth: .infinity, alignment: isSmall ? .leading : .center)
                
                Button {
                    guard !showPopover, Date.now.timeIntervalSince(holdEndedAt) > 0.3 else { return }
                    showSheet = true
                } label: {
                    Image(systemName: prominentSymbol)
                        .font(.title)
                        .scaleEffect(0.95)
                        .frame(width: 40, height: 50)
                        .matchedTransitionSource(id: "POPOVER", in: namespace)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(prominentLabel)
                .accessibilityAction(named: popoverActionLabel) {
                    showPopover = true
                }
                .simultaneousGesture(holdAndDragGesture)
                .onChange(of: isHolding) { _, holding in
                    if !holding {
                        resetDragTracking()
                    }
                }
                .sensoryFeedback(.impact, trigger: showPopover) { _, isShowing in isShowing }
                .sheet(isPresented: $showSheet) {
                    sheet
                }
                .popover(isPresented: $showPopover) {
                    popover
                        .environment(\.popoverDrag, popoverDrag)
                        .presentationCompactAdaptation(.popover)
                        .navigationTransition(.zoom(sourceID: "POPOVER", in: namespace))
                }
            }
        }
        .padding([.bottom, .horizontal], 25)
        .ignoresSafeArea(.all, edges: .bottom)
    }

    private var holdAndDragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.4)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($isHolding) { value, state, _ in
                if case .second(true, _) = value {
                    state = true
                }
            }
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if !showPopover {
                    showPopover = true
                }
                guard let location = drag?.location else { return }

                guard let origin = holdOrigin else {
                    holdOrigin = location
                    return
                }
                if !isTrackingDrag,
                    hypot(location.x - origin.x, location.y - origin.y) > 10
                {
                    isTrackingDrag = true
                }
                if isTrackingDrag {
                    popoverDrag.location = location
                }
            }
            .onEnded { value in
                holdEndedAt = .now
                if isTrackingDrag, case .second(true, let drag) = value, let drag {
                    popoverDrag.releaseLocation = drag.location
                    popoverDrag.releaseCount += 1
                }
                resetDragTracking()
            }
    }

    private func resetDragTracking() {
        holdOrigin = nil
        isTrackingDrag = false
        popoverDrag.location = nil
    }
}

fileprivate struct CustomProminentTabBar<Item: ProminentTabItem>: UIViewRepresentable {
    @Environment(\.displayScale) private var displayScale
    
    @Binding var selection: Item
    
    func makeUIView(context: Context) -> UISegmentedControl {
        let control = InstantSelectSegmentedControl(items: allTabs.compactMap({ generateItemImage($0) }))
        
        control.selectedSegmentIndex = allTabs.firstIndex(of: selection) ?? 0
        control.selectedSegmentTintColor = UIColor(Color.gray.opacity(0.18))
        control.setTitleTextAttributes([.foregroundColor: UIColor(Color.accentColor)], for: .selected)
        control
            .addTarget(
                context.coordinator,
                action: #selector(context.coordinator.didChange(_:)),
                for: .valueChanged
            )
        context.coordinator.renderedScale = displayScale

        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        if let seletionIndex = allTabs.firstIndex(of: selection), uiView.selectedSegmentIndex != seletionIndex {
            uiView.selectedSegmentIndex = seletionIndex
        }

        if context.coordinator.renderedScale != displayScale {
            context.coordinator.renderedScale = displayScale
            for (index, item) in allTabs.enumerated() {
                uiView.setImage(generateItemImage(item), forSegmentAt: index)
            }
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        return .init(width: proposal.replacingUnspecifiedDimensions().width, height: 60)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }
    
    class Coordinator: NSObject {
        @Binding var selection: Item
        var renderedScale: CGFloat = 0

        init(selection: Binding<Item>) {
            self._selection = selection
        }
        
        @objc
        func didChange(_ control: UISegmentedControl) {
            selection = Array(Item.allCases)[control.selectedSegmentIndex]
        }
    }
    
    private func generateItemImage(_ item: Item) -> UIImage? {
        let renderer = ImageRenderer(content: VStack(spacing: 4) {
            Image(systemName: item.symbol)
                .font(.title2)
                .fontWeight(.regular)
                .symbolVariant(.fill)
                .frame(height: 25)
            
            Text(item.title)
                .font(.caption2)
        })
        
        renderer.scale = displayScale
        let image = renderer.uiImage
        image?.accessibilityLabel = item.title
        return image
    }
    
    private var allTabs: [Item] {
        Array(Item.allCases)
    }
}

fileprivate final class InstantSelectSegmentedControl: UISegmentedControl {
    override func layoutSubviews() {
        super.layoutSubviews()
        for subview in subviews where subview is UIImageView && subview != subviews.last {
            subview.alpha = 0
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first, numberOfSegments > 0 {
            let segmentWidth = bounds.width / CGFloat(numberOfSegments)
            var index = Int(touch.location(in: self).x / segmentWidth)
            if effectiveUserInterfaceLayoutDirection == .rightToLeft {
                index = numberOfSegments - 1 - index
            }
            index = min(max(index, 0), numberOfSegments - 1)

            if index != selectedSegmentIndex {
                UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
                    self.selectedSegmentIndex = index
                    self.layoutIfNeeded()
                }
                sendActions(for: .valueChanged)
            }
        }

        super.touchesBegan(touches, with: event)
    }
}
