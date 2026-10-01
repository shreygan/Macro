//
//  MainView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftData
import SwiftUI

extension EnvironmentValues {
    @Entry var eraseAllData: () -> Void = {}
}

struct MainView: View {
    @Environment(\.modelContext) private var modelContext

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
    @State private var isErasingData = false

    @Query private var users: [User]

    private var isOnboardingComplete: Bool {
        users.first?.onboardingComplete == true
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            if !isErasingData {
                tabContent
                    .transition(.opacity)
            }

            if !isOnboardingComplete || isErasingData {
                WelcomeView()
                    .zIndex(1)
                    .transition(.scale(scale: 1.1).combined(with: .opacity))
            }
        }
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8),
            value: isOnboardingComplete
        )
        .environment(\.eraseAllData, eraseAllData)
    }

    private var tabContent: some View {
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
    }

    private func eraseAllData() {
        withAnimation(
            .spring(response: 0.6, dampingFraction: 0.8),
            completionCriteria: .removed
        ) {
            isErasingData = true
        } completion: {
            do {
                try modelContext.eraseAllData()
                try modelContext.save()
                try AppSeeder.seedDefaults(into: modelContext)
            } catch {
                modelContext.rollback()
                print("Failed to clear or reseed data: \(error.localizedDescription)")
            }
            isErasingData = false
        }
    }
}

#Preview {
    MainView()
}
