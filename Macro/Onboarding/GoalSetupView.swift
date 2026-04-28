//
//  GoalSetupView.swift
//  Macro
//
//  Created by Shrey Gangwar on 4/27/26.
//

import ModernSlider
import SwiftUI

struct GoalSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var sliderValue = 60.0

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Text("Goal Setup")
                .font(.largeTitle)

            ModernSlider(
                "Brightness",
                systemImage: "sun.max.fill",
                value: $sliderValue,
                in: 5...100,
                onChange: { newValue in
                    print("Slider value changed to \(newValue)")
                },
                onChangeEnd: { finalValue in
                    print("Sliding ended with value \(finalValue)")
                }
            )
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    GoalSetupView()
}
