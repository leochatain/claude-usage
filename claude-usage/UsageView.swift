import SwiftUI

struct UsageView: View {
    let service: UsageService
    var onRefresh: () -> Void
    var onSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claude Usage")
                .font(.headline)

            if service.isLoading && service.sessionUsage == nil {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading…")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if let error = service.errorMessage, service.sessionUsage == nil {
                VStack(spacing: 8) {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                    Button("Retry") { onRefresh() }
                        .buttonStyle(.bordered)
                }
            } else {
                if let session = service.sessionUsage {
                    UsageRow(
                        label: "Session (5 hr)",
                        usage: session,
                        resetText: resetText(for: service.sessionResetsAt, relative: true)
                    )
                }

                if let weekly = service.weeklyUsage {
                    UsageRow(
                        label: "Weekly (7 day)",
                        usage: weekly,
                        resetText: resetText(for: service.weeklyResetsAt, relative: false)
                    )
                }

                if let opus = service.opusUsage {
                    UsageRow(
                        label: "Opus Weekly",
                        usage: opus,
                        resetText: nil
                    )
                }

                if service.extraUsageEnabled == true,
                   let limit = service.monthlyLimitCents,
                   let used = service.usedCreditsCents,
                   let currency = service.currency,
                   limit > 0 {
                    Divider()
                    ExtraUsageRow(
                        usedCents: used,
                        limitCents: limit,
                        currency: currency
                    )
                }

                if let error = service.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Divider()

            HStack {
                Button("Refresh") { onRefresh() }
                Spacer()
                Button("Settings") { onSettings() }
                Button("Quit") { onQuit() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .frame(width: 300)
    }

    private func resetText(for date: Date?, relative: Bool) -> String? {
        guard let date else { return nil }
        if relative {
            let remaining = date.timeIntervalSinceNow
            guard remaining > 0 else { return "Resets soon" }
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            return "Resets in \(hours)h \(minutes)m"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
            return "Resets \(formatter.string(from: date))"
        }
    }
}

private struct ExtraUsageRow: View {
    let usedCents: Int
    let limitCents: Int
    let currency: String

    private var symbol: String {
        switch currency {
        case "GBP": return "£"
        case "EUR": return "€"
        default: return "$"
        }
    }

    private func format(_ cents: Int) -> String {
        let value = Double(cents) / 100.0
        return String(format: "\(symbol)%.2f", value)
    }

    var body: some View {
        let fraction = Double(usedCents) / Double(limitCents)
        let percentage = min(fraction * 100, 100)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Extra Usage")
                    .font(.callout.weight(.medium))
                Spacer()
                Text("\(format(usedCents)) of \(format(limitCents))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(fraction, 1.0), total: 1.0)
                .tint(percentage >= 80 ? .red : percentage >= 50 ? .orange : .accentColor)
            Text("\(format(limitCents - usedCents)) remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct UsageRow: View {
    let label: String
    let usage: Double
    let resetText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.callout.weight(.medium))
                Spacer()
                Text("\(Int(usage))% used")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(usage, 100), total: 100)
                .tint(usage >= 80 ? .red : usage >= 50 ? .orange : .accentColor)
            if let resetText {
                Text(resetText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
