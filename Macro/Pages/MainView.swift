//
//  MainView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftData
import SwiftUI

struct MainView: View {
    enum TabSelection: ProminentTabItem {
        case home, stats, library

        var symbol: String {
            switch self {
            case .home: return "house"
            case .stats: return "chart.bar.xaxis"
            case .library: return "book.pages"
            }
        }

        var title: String {
            switch self {
            case .home: return String(localized: "Home")
            case .stats: return String(localized: "Statistics")
            case .library: return String(localized: "Library")
            }
        }
    }

    @State private var selection: TabSelection = .home
    @State private var foodToLog: FoodItem? = nil

    @Query private var users: [User]

    private var isOnboardingComplete: Bool {
        users.first?.onboardingComplete == true
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            TabView(selection: $selection) {
                Tab(value: .home) {
                    HomeView()
                        .toolbarVisibility(.hidden, for: .tabBar)
                }

                Tab(value: .stats) {
                    Text("Statistics View")
                        .toolbarVisibility(.hidden, for: .tabBar)
                }

                Tab(value: .library) {
                    Text("Library View")
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ProminentTabBar(selection: $selection, prominentSymbol: "plus") {
                    NewEntryView()
                } popover: {
                    QuickLogPopover { food in
                        foodToLog = food
                    }
                }
            }
            .sheet(item: $foodToLog) { food in
                if food.type == .recipe {
                    LogRecipeView(recipe: food, isPushedView: false)
                } else {
                    LogEntryView(food: food, isPushedView: false)
                }
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
