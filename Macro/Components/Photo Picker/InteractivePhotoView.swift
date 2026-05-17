//
//  InteractivePhotoView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/15/26.
//

import SwiftUI
import UIKit

struct InteractivePhotoView: View {
    let image: UIImage
    let onDelete: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                )
                .clipped()
                .overlay(
                    TwoFingerGestureOverlay { scaleDelta, translationDelta in
                        applyGestures(scaleDelta: scaleDelta, translationDelta: translationDelta, size: geometry.size)
                    }
                )
                .overlay(alignment: .topTrailing) {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(.regularMaterial)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                    .padding(12)
                }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func applyGestures(scaleDelta: CGFloat, translationDelta: CGSize, size: CGSize) {
        scale *= scaleDelta
        scale = max(1.0, scale)
        
        offset.width += translationDelta.width
        offset.height += translationDelta.height
        
        let imageRatio = image.size.height == 0 ? 1 : image.size.width / image.size.height
        var baseWidth = size.width
        var baseHeight = size.height
        
        if imageRatio > 1 {
            baseWidth = size.height * imageRatio
        } else {
            baseHeight = size.width / imageRatio
        }
        
        let scaledWidth = baseWidth * scale
        let scaledHeight = baseHeight * scale
        
        let maxX = max(0, (scaledWidth - size.width) / 2)
        let maxY = max(0, (scaledHeight - size.height) / 2)
        
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
    }
}

struct TwoFingerGestureOverlay: UIViewRepresentable {
    var onGesture: (CGFloat, CGSize) -> Void

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

        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onGesture: onGesture)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onGesture: (CGFloat, CGSize) -> Void

        init(onGesture: @escaping (CGFloat, CGSize) -> Void) {
            self.onGesture = onGesture
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            let scaleDelta = gesture.scale
            gesture.scale = 1.0
            onGesture(scaleDelta, .zero)
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
