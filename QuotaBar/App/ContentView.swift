//
//  ContentView.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var urlHandler: URLSchemeHandler

    var body: some View {
        VStack {
            Image(systemName: "chart.bar")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Quota Bar")
                .font(.title)
            Text(statusText)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    private var statusText: String {
        guard let route = urlHandler.currentRoute else {
            return "初始化中..."
        }

        switch route.action {
        case .details:
            return "已打开 \(route.providerID) 详情"
        case .reauthorize:
            return "正在为 \(route.providerID) 准备重新授权"
        }
    }
}

#Preview {
    ContentView(urlHandler: URLSchemeHandler())
}
