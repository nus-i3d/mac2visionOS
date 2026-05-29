//
//  ContentView.swift
//  mac2visionOS
//
//  Created by Carey Lai  on 29/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(visionOS)
        BubbleHostView()
        #elseif os(macOS)
        BubbleControllerView()
        #else
        Text("Run this prototype on macOS or visionOS.")
            .padding()
        #endif
    }
}
