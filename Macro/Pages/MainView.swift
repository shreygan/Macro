//
//  MainView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftData
import SwiftUI

struct MainView: View {
    enum TabSelection {
        case home, stats, library, add
    }

    @State private var selection: TabSelection = .home
    @State private var showLogSheet = false

    @Query private var users: [User]

    private var isOnboardingComplete: Bool {
        users.first?.onboardingComplete == true
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            TabView(selection: $selection) {
                Tab("Home", systemImage: "house.fill", value: .home) {
                    HomeView()
                }

                Tab("Statistics", systemImage: "chart.bar.xaxis", value: .stats)
                {
                    Text("Statistics View")
                }

                Tab("Library", systemImage: "book.pages", value: .library) {
                    Text("Library View")
                }

                Tab("Add", systemImage: "plus", value: .add, role: .search) {
                    Color.accentColor
                }
            }
            .onChange(of: selection) { oldValue, newValue in
                if newValue == .add {
                    selection = oldValue
                    showLogSheet = true
                }
            }
            .sheet(isPresented: $showLogSheet) {
                NewEntryView()
            }

            if !isOnboardingComplete {
                WelcomeView()
                    .zIndex(1)
                    .transition(.scale(scale: 1.1).combined(with: .opacity))
            }
        }
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8),
            value: isOnboardingComplete
        )
    }
}

#Preview {
    MainView()
}
