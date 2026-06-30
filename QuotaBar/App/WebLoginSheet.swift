//
//  WebLoginSheet.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import SwiftUI
import WebKit

struct WebLoginSheet: View {
    let provider: ProviderViewState
    let onComplete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.headline)
                    Text(provider.loginURL.host() ?? provider.loginURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("完成", action: onComplete)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            LoginWebView(url: provider.loginURL)
                .frame(minWidth: 860, minHeight: 620)
        }
    }
}

private struct LoginWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.processPool = SharedWebViewProcessPool.pool

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {}
    }
}

private enum SharedWebViewProcessPool {
    static let pool = WKProcessPool()
}
