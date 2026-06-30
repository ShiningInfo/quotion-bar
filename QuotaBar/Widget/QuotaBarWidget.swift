//
//  QuotaBarWidget.swift
//  QuotaBarWidgetExtension
//
//  Created by QuotaBar on 2026/06/30.
//

import WidgetKit
import SwiftUI

struct QuotaBarWidget: Widget {
    let kind: String = "QuotaBarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuotaTimelineProvider()) { entry in
            if #available(macOS 14.0, *) {
                QuotaWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                QuotaWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Quota Bar")
        .description("在 Widget 中展示 Codex / MiniMax / DeepSeek 额度")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
