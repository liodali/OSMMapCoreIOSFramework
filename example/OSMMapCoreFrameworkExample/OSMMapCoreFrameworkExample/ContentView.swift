//
//  ContentView.swift
//  OSMMapCoreFrameworkExample
//
//  Created by Dali Hamza on 19.03.24.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapCoreOSM()
                .ignoresSafeArea()
                .tabItem {
                    Label("MapCore", systemImage: "map")
                }
                .tag(0)

            MapLibreView()
                .ignoresSafeArea()
                .tabItem {
                    Label("MapLibre", systemImage: "map.fill")
                }
                .tag(1)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
