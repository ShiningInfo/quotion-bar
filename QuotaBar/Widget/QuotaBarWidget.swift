//
//  QuotaBarWidget.swift
//  QuotaBarWidgetExtension
//
//  Created by QuotaBar on 2026/06/30.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), text: "Quota Bar 初始化中")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), text: "Quota Bar 初始化中")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, text: "Quota Bar 初始化中")
        entries.append(entry)

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let text: String
}

struct QuotaBarWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Image(systemName: "chart.bar")
                .imageScale(.large)
            Text(entry.text)
                .font(.headline)
        }
    }
}

struct QuotaBarWidget: Widget {
    let kind: String = "QuotaBarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(macOS 14.0, *) {
                QuotaBarWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                QuotaBarWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Quota Bar")
        .description("在 Widget 中展示 Codex / MiniMax / DeepSeek 额度")
    }
}
