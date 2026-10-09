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
    @Entry var tabBarHeight: CGFloat = 0
}

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter

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
    @State private var isErasingData = false
    @State private var libraryPopToRoot = 0
    @State private var screenBottom: CGFloat = 0
    @State private var tabBarTop: CGFloat = 0

    @Query private var users: [User]

    private var isOnboardingComplete: Bool {
        users.first?.onboardingComplete == true
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).maxY
                } action: { maxY in
                    screenBottom = maxY
                }

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
                NavigationStack {
                    LibraryView(
                        searchPrompt: "Search your library",
                        isTabRoot: true,
                        popToRootTrigger: libraryPopToRoot
                    )
                }
                .environment(\.tabBarHeight, max(screenBottom - tabBarTop, 0))
                .toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProminentTabBar(
                selection: $selection,
                prominentSymbol: "plus",
                onReselect: { tab in
                    if tab == .library {
                        libraryPopToRoot += 1
                    }
                }
            ) {
                NewEntryView(
                    onBrowseLibrary: { selection = .library },
                    onFinishLogging: { selection = .home }
                )
            } popover: {
                QuickLogPopover { food in
                    quickLog(food)
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY
            } action: { minY in
                tabBarTop = minY
            }
        }
    }

    private func quickLog(_ food: FoodItem) {
        do {
            let entry = try withAnimation {
                try QuickLogger.log(food, in: modelContext)
            }
            if let toastCenter {
                toastCenter.show(
                    .entryLogged(
                        LogUndoRecord(entry: entry),
                        title: String(localized: "Logged for Today"),
                        in: modelContext,
                        presenter: toastCenter
                    )
                )
            }
        } catch {
            toastCenter?.show(
                .failure(String(localized: "Couldn't Log Entry"), message: food.name)
            )
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
                AppSeeder.resetListSeeding()
                try AppSeeder.seedDefaults(into: modelContext)
            } catch {
                modelContext.rollback()
                toastCenter?.show(.failure(String(localized: "Couldn't Erase Data")))
            }
            isErasingData = false
        }
    }
}

#Preview {
    MainView()
}
