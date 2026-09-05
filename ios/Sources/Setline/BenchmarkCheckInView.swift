import SetlineCore
import SwiftUI

// MARK: - Check-in row

struct BenchmarkCheckInRow: View {
    let checkIn: BenchmarkCheckIn
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(checkIn.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.headline.weight(.black))
                        Text("\(checkIn.profile.weight.map { "\($0.formatted()) kg" } ?? "\u{2014}") \u{00B7} \(checkIn.profile.height.map { "\($0.formatted()) cm" } ?? "\u{2014}") \u{00B7} saved snapshot")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Text("\(reachedCount) / \(BenchmarkCatalog.metrics.count) targets reached")
                            .font(.caption.weight(.bold))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
                .foregroundStyle(SetlinePalette.ink)
                .padding(16)
            }
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(BenchmarkCatalog.metrics.enumerated()), id: \.offset) { _, metric in
                        let assessment = BenchmarkEngine.assess(metric.id, checkIn: checkIn)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.name).font(.subheadline.weight(.semibold))
                                Text(assessment.current)
                                    .font(.caption.monospacedDigit())
                                Text(assessment.currentSub)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(assessment.target)
                                    .font(.caption.monospacedDigit())
                                Text(assessment.status)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        if metric.id != BenchmarkCatalog.metrics.last?.id {
                            InkRule()
                        }
                    }
                }
            }
        }
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var reachedCount: Int {
        BenchmarkCatalog.reachedCount(in: checkIn)
    }
}
