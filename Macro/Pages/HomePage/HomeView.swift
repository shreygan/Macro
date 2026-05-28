//
//  HomeView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftUI

struct HomeView: View {

    func currDate() -> String {
        let date = Date()
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text("Hello World!")
            }
            .navigationTitle("Home")
            .navigationSubtitle(currDate())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "calendar")
                    }

                    Button {
                    } label: {
                        Image(systemName: "gear")
                    }

                    Menu {
                        Button {
                        } label: {
                            Label(
                                "Import...",
                                systemImage: "square.and.arrow.down"
                            )
                        }

                        Divider()

                        Button(role: .destructive) {
                        } label: {
                            Label(
                                "Delete All",
                                systemImage: "trash",

                            )
                        }

                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
