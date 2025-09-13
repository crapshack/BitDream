import WidgetKit
import SwiftUI
import AppIntents

struct SessionOverviewEntry: TimelineEntry {
    let date: Date
    let snapshot: SessionOverviewSnapshot?
    let isStale: Bool
}

struct SessionOverviewProvider: AppIntentTimelineProvider {
    typealias Entry = SessionOverviewEntry
    typealias Intent = SessionOverviewIntent

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: nil, isStale: false)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        await loadEntry(for: configuration.server?.id)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry = await loadEntry(for: configuration.server?.id)
        let next = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date().addingTimeInterval(600)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func loadEntry(for serverId: String?) async -> Entry {
        guard let serverId = serverId,
              let url = AppGroup.Files.sessionURL(for: serverId),
              let snap: SessionOverviewSnapshot = AppGroupJSON.read(SessionOverviewSnapshot.self, from: url) else {
            return Entry(date: .now, snapshot: nil, isStale: true)
        }
        let isStale = (Date().timeIntervalSince(snap.timestamp) > 600)
        return Entry(date: .now, snapshot: snap, isStale: isStale)
    }
}

@main
struct SessionOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SessionOverviewWidget", intent: SessionOverviewIntent.self, provider: SessionOverviewProvider()) { entry in
            SessionOverviewView(entry: entry)
                .containerBackground(for: .widget) {
                    // Full-bleed background with banner and header content
                    let headerHeight: CGFloat = 32
                    ZStack(alignment: .topLeading) {
                        ContainerRelativeShape().fill(.background)
                        // Banner layer
                        Color(red: 0x67/255.0, green: 0xa3/255.0, blue: 0xd9/255.0)
                        .frame(height: headerHeight)
                        .frame(maxWidth: .infinity, alignment: .top)

                        // Header content inside the banner
                        HStack {
                            Text(entry.snapshot?.serverName ?? "")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(.white.opacity(0.9))
                            
                            Spacer()
                            
                            // Ratio chip and speeds grouped together on the RIGHT (matching main app)
                            if let snap = entry.snapshot {
                                let formatter: ByteCountFormatter = {
                                    var f = ByteCountFormatter()
                                    f.allowsNonnumericFormatting = false
                                    f.countStyle = .file
                                    f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
                                    return f
                                }()
                                let speedFont = Font.system(size: 10, weight: .regular, design: .monospaced)

                                HStack(spacing: 6) {
                                    // Speed chips only - cleaner header
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.down")
                                        Text("\(formatter.string(fromByteCount: snap.downloadSpeed))/s")
                                    }
                                    .font(speedFont)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                                    
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.up")
                                        Text("\(formatter.string(fromByteCount: snap.uploadSpeed))/s")
                                    }
                                    .font(speedFont)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: headerHeight, alignment: .center)
                    }
                }
        }
        .configurationDisplayName("Session Overview")
        .description("Total, speeds, and ratio for a server.")
        .supportedFamilies([.systemMedium])
    }
}


