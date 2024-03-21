//
//  ContentView.swift
//  OSMMapCoreFrameworkExample
//
//  Created by Dali Hamza on 19.03.24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VMap()
    }
}
struct VMap :View {
    var body: some View {
        NavigationView {
            VStack {
               /* MapCoreNOSM(width: 250,height: 250)
                .frame(width: 250,height: 250)
                    .padding(EdgeInsets(top: 0, leading: 36, bottom: 32, trailing: 42))*/
                MapCoreOSM(width: 500,height: 500)
                .frame(width: 500,height: 500)
                    .padding(EdgeInsets(top: 0, leading: 36, bottom: 65, trailing: 42))
               
              /*MapView()
                    .padding(EdgeInsets(top: 0, leading: 36, bottom: 0, trailing: 0))*/
                NavigationLink {
                    VMap()
                } label:{
                    Text("open new map").padding(EdgeInsets(top: 0, leading: 0, bottom: 32, trailing: 0))
                }
            }
            
        }
    }
}
#Preview {
    ContentView()
}
