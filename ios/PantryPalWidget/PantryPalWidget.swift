import WidgetKit
import SwiftUI

struct PantryEntry: TimelineEntry {
    let date: Date
    let expiringCount: Int
    let urgentItem: String
    let totalItems: Int
}

struct PantryProvider: TimelineProvider {
    func placeholder(in context: Context) -> PantryEntry {
        PantryEntry(date: Date(), expiringCount: 2, urgentItem: "Milk", totalItems: 12)
    }
    func getSnapshot(in context: Context, completion: @escaping (PantryEntry) -> Void) {
        completion(entry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PantryEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(Date().addingTimeInterval(1800))))
    }
    func entry() -> PantryEntry {
        let ud = UserDefaults(suiteName: "group.com.tsaira.receiptscanner")
        return PantryEntry(
            date: Date(),
            expiringCount: ud?.integer(forKey: "expiringCount") ?? 0,
            urgentItem: ud?.string(forKey: "urgentItem") ?? "",
            totalItems: ud?.integer(forKey: "totalItems") ?? 0
        )
    }
}

struct PantryWidgetView: View {
    var entry: PantryEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("🌱 PantryPal")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
            Spacer()
            if entry.expiringCount == 0 {
                Text("✅ All fresh!")
                    .font(.title3).fontWeight(.bold).foregroundColor(.white)
                Text("\(entry.totalItems) items tracked")
                    .font(.caption2).foregroundColor(.white.opacity(0.7))
            } else {
                Text("\(entry.expiringCount)")
                    .font(.system(size: 38, weight: .black)).foregroundColor(.white)
                Text("expiring soon")
                    .font(.caption2).foregroundColor(.white.opacity(0.8))
                if !entry.urgentItem.isEmpty {
                    Text("⚠️ \(entry.urgentItem)")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.yellow).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding()
        .containerBackground(
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.37, blue: 0.13),
                         Color(red: 0.18, green: 0.49, blue: 0.20)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            for: .widget
        )
    }
}

struct PantryPalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PantryPalWidget", provider: PantryProvider()) { entry in
            PantryWidgetView(entry: entry)
        }
        .configurationDisplayName("PantryPal")
        .description("See what's expiring in your pantry")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
