//
//  WelcomeView.swift
//  Macro
//
//  Created by Shrey Gangwar on 4/14/26.
//

import SwiftUI

struct WelcomeView: View {
    @State private var revealedProgress: CGFloat = 0
    @State private var dragDelta: CGFloat = 0
    @State private var isDragging = false

    var anim: Animation {
        .interactiveSpring(
            response: 0.5,
            dampingFraction: 0.8,
            blendDuration: 0.4
        )
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            // Effective progress (0 = Welcome, 1 = GoalSetup), clamped to [0, 1]
            let p = max(0, min(1, revealedProgress + dragDelta))

            ZStack(alignment: .top) {
                // Bottom layer: GoalSetup (slides up from below as p → 1)
                GoalSetupView()
                    .offset(y: (1 - p) * height)

                // Top layer: Welcome (Grouped so the background slides with the text!)
                ZStack {
                    Color.white.ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120)
                            .padding(.bottom, 8)
                        
                        Text("Macro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("The Nutrition Tracker")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        VStack(spacing: -12) {
                            Image(systemName: "chevron.up").opacity(0.3)
                            Image(systemName: "chevron.up").opacity(0.6)
                            Image(systemName: "chevron.up").opacity(1.0)
                        }
                        .font(.title2)
                        .foregroundColor(.gray)
                        .padding(.bottom, 40)
                        .phaseAnimator([false, true]) { content, floating in
                            // Lock to center (0) when dragging, otherwise bob
                            content.offset(y: isDragging ? 0 : (floating ? -8 : 8))
                        } animation: { _ in
                            // 'nil' instantly kills the animation so it doesn't fight your finger
                            isDragging ? nil : .easeInOut(duration: 1.0)
                        }
                        
                        Text("by Shrey and Priyanka")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.bottom)
                    }
                }
                .offset(y: -p * height)
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        // FIX: Only trigger the state change ONCE to prevent lag
                        if !isDragging {
                            isDragging = true
                        }
                        
                        // Constrain drag direction
                        if revealedProgress == 0 {
                            dragDelta = max(0, -value.translation.height / height)
                        } else {
                            dragDelta = min(0, -value.translation.height / height)
                        }
                    }
                    .onEnded { value in
                        let currentDragEnd = revealedProgress + dragDelta
                        let predicted = currentDragEnd - (value.predictedEndTranslation.height / height)
                        let targetProgress: CGFloat = predicted >= 0.5 ? 1 : 0
                        
                        withAnimation(anim) {
                            dragDelta = .zero
                            revealedProgress = targetProgress
                        }
                        
                        // FIX: Wait for the screen snap animation to finish before unpausing the chevrons
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isDragging = false
                        }
                    }
            )
        }
    }
}
