//
//  QuotaBarApp.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import SwiftUI

@main
struct QuotaBarApp: App {
    @StateObject private var urlHandler = URLSchemeHandler()

    var body: some Scene {
        WindowGroup {
            ContentView(urlHandler: urlHandler)
                .onOpenURL { url in
                    urlHandler.handle(url)
                }
        }
    }
}
