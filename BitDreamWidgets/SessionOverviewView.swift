import SwiftUI
import WidgetKit

// MARK: - Widget Ratio Chip

enum WidgetSpeedChipSize {
    case compact
    case regular
    
    var font: Font {
        switch self {
        case .compact: return .system(.caption, design: .monospaced)
        case .regular: return .system(.footnote, design: .monospaced)
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .compact: return 8
        case .regular: return 10
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .compact: return 4
        case .regular: return 6
        }
    }
}

struct WidgetRatioChip: View {
    let ratio: Double
    var size: WidgetSpeedChipSize = .compact
    
    private var progressRingSize: CGFloat {
        switch size {
        case .compact: return 12  // Smaller for header use
        case .regular: return 18
        }
    }
    
    var body: some View {
        HStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                    .frame(width: progressRingSize, height: progressRingSize)
                
                Circle()
                    .trim(from: 0, to: min(ratio, 1.0))
                    .stroke(ratio >= 1.0 ? .green : .orange, lineWidth: 1.5)
                    .frame(width: progressRingSize, height: progressRingSize)
                    .rotationEffect(.degrees(-90))
            }
            
            Text(String(format: "%.2f", ratio))
                .monospacedDigit()
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Compact Speed Display

struct CompactSpeedView: View {
    let downloadSpeed: Int64
    let uploadSpeed: Int64
    
    // Recreate byteCountFormatter locally since we can't import from Utilities
    private var byteCountFormatter: ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .imageScale(.small)
                Text(formatSpeed(downloadSpeed))
                    .monospacedDigit()
            }
            
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .imageScale(.small)
                Text(formatSpeed(uploadSpeed))
                    .monospacedDigit()
            }
        }
        .font(.system(.caption2, design: .monospaced))
    }
    
    private func formatSpeed(_ speed: Int64) -> String {
        if speed == 0 { return "0" }
        let formatted = byteCountFormatter.string(fromByteCount: speed)
        return formatted.replacingOccurrences(of: " bytes", with: "B")
            .replacingOccurrences(of: " KB", with: "K")
            .replacingOccurrences(of: " MB", with: "M")
            .replacingOccurrences(of: " GB", with: "G")
    }
}


struct SessionOverviewView: View {
    let entry: SessionOverviewEntry

    var body: some View {
        if let snap = entry.snapshot {
            let headerHeight: CGFloat = 32 // Match the container header height
            ZStack(alignment: .topLeading) {
                // Main content below banner (banner is drawn in container background)
                VStack(spacing: 8) {
                    // Stats display - keep it simple and compact
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Image(systemName: "tray.full")
                                    .imageScale(.small)
                                    .foregroundStyle(.secondary)
                                Text("Total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(snap.total)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("Ratio")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            WidgetRatioChip(ratio: snap.ratio)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.top, headerHeight)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Header visuals handled in container background; keep only spacing via top padding above
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "server.rack")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Select Server")
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                Text("Edit this widget to choose a server.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#if DEBUG
struct SessionOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        SessionOverviewView(entry: .init(date: .now, snapshot: .init(serverId: "1", serverName: "Home Server", active: 2, paused: 5, total: 12, downloadSpeed: 1_200_000, uploadSpeed: 140_000, ratio: 1.42, timestamp: .now), isStale: false))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
#endif


