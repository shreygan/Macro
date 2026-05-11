//
//  MainView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftUI

struct MainView: View {
    enum TabSelection {
        case home, stats, library, add
    }

    @State private var selection: TabSelection = .home
    @State private var showLogSheet = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                HomeView()
            }

            Tab("Statistics", systemImage: "chart.bar.xaxis", value: .stats) {
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
            NewEntrySheetView()
        }
    }
}

#Preview {
    MainView()
}
