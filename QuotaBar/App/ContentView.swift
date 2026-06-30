//
//  ContentView.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "chart.bar")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Quota Bar")
                .font(.title)
            Text("初始化中...")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView()
}
