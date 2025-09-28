import SwiftUI
import Foundation

// MARK: - Shared Peer Components

/// Small badge-style label for protocol display (e.g., TCP/uTP)
struct ProtocolBadge: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
            .cornerRadius(4)
            .help("Protocol: \(text)")
    }
}

/// Boolean indicator rendered as green check/red x with a tooltip
struct BoolCheckIcon: View {
    let value: Bool
    let label: String
    
    var body: some View {
        Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
            .imageScale(.medium)
            .foregroundColor(value ? .green : .red)
            .help("\(label): \(value ? "true" : "false")")
    }
}
