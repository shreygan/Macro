//
//  InteractivePhotoView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/15/26.
//

import SwiftUI
import UIKit

struct InteractivePhotoView: View {
    @Binding var photo: LoggedPhoto
    var isAdjustable: Bool = true
    var onTap: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(photo.scale)
                        .offset(photo.offset)
                )
                .clipped()
                .overlay(
                    TwoFingerGestureOverlay(
                        isEnabled: isAdjustable,
                        onGesture: { scaleDelta, translationDelta in
                            applyGestures(
                                scaleDelta: scaleDelta,
                                translationDelta: translationDelta,
                                size: geometry.size
                            )
                        },
                        onTap: onTap
                    )
                )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func applyGestures(
        scaleDelta: CGFloat,
        translationDelta: CGSize,
        size: CGSize
    ) {
        photo.scale *= scaleDelta
        photo.scale = max(1.0, photo.scale)

        photo.offset.width += translationDelta.width
        photo.offset.height += translationDelta.height

        let imageRatio =
            photo.image.size.height == 0
            ? 1 : photo.image.size.width / photo.image.size.height
        var baseWidth = size.width
        var baseHeight = size.height

        if imageRatio > 1 {
            baseWidth = size.height * imageRatio
        } else {
            baseHeight = size.width / imageRatio
        }

        let scaledWidth = baseWidth * photo.scale
        let scaledHeight = baseHeight * photo.scale

        let maxX = max(0, (scaledWidth - size.width) / 2)
        let maxY = max(0, (scaledHeight - size.height) / 2)

        photo.offset.width = min(max(photo.offset.width, -maxX), maxX)
        photo.offset.height = min(max(photo.offset.height, -maxY), maxY)
    }
}

struct TwoFingerGestureOverlay: UIViewRepresentable {
    var isEnabled: Bool = true
    var onGesture: (CGFloat, CGSize) -> Void
    var onTap: (() -> Void)? = nil

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2

        pinch.delegate = context.coordinator
        pan.delegate = context.coordinator

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap)
        )

        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onGesture = onGesture
        context.coordinator.onTap = onTap
        uiView.gestureRecognizers?
            .filter { $0 is UIPinchGestureRecognizer || $0 is UIPanGestureRecognizer }
            .forEach { $0.isEnabled = isEnabled }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onGesture: onGesture)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onGesture: (CGFloat, CGSize) -> Void
        var onTap: (() -> Void)?

        init(onGesture: @escaping (CGFloat, CGSize) -> Void) {
            self.onGesture = onGesture
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            let scaleDelta = gesture.scale
            gesture.scale = 1.0
            onGesture(scaleDelta, .zero)
        }

        @objc func handleTap() {
            onTap?()
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let translation = gesture.translation(in: view)
            gesture.setTranslation(.zero, in: view)

            let translationSize = CGSize(
                width: translation.x,
                height: translation.y
            )
            onGesture(1.0, translationSize)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer:
                UIGestureRecognizer
        ) -> Bool {
            return gestureRecognizer.view == otherGestureRecognizer.view
        }
    }
}
