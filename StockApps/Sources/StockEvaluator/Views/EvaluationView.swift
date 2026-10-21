import StockCore
import SwiftUI

struct EvaluationView: View {
    let stock: StockSnapshot
    let summary: CompanySummary?
    let summaryError: String?
    let evaluation: Evaluation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                VerdictCard(evaluation: evaluation)
                if let summaryError, summary == nil {
                    Label("Company financials unavailable: \(summaryError) The verdict is based on price trend and risk only.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                } else if summary?.isFund == true {
                    Label("This is a fund, so company measures like P/E and margins don't apply. It's judged mostly on trend and risk.",
                          systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                FlagsSection(evaluation: evaluation)
                CategoriesSection(evaluation: evaluation)
                FairValueSection(evaluation: evaluation)
                section("Price History") {
                    PriceChart(bars: stock.bars, height: 260)
                }
                if let about = summary?.businessSummary, !about.isEmpty {
                    section("About the Company") {
                        Text(about)
                            .font(.callout)
                            .textSelection(.enabled)
                            .lineSpacing(2)
                    }
                }
                disclaimer
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(stock.symbol).font(.largeTitle.bold())
                    Text(stock.name).font(.title3).foregroundStyle(.secondary).lineLimit(1)
                }
                let details = [summary?.sector, summary?.industry, stock.exchange.isEmpty ? nil : stock.exchange]
                    .compactMap { $0 }
                if !details.isEmpty {
                    Text(details.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Format.price(stock.price)).font(.title.monospacedDigit())
                    Text(stock.currency).foregroundStyle(.secondary)
                }
                ChangeText(value: stock.changeDay)
                if let cap = summary?.marketCap {
                    Text("Market cap \(Format.compact(cap))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("This is an automated, rules-based checklist built on Yahoo Finance data, which can be delayed, incomplete or wrong. It is not financial advice and can't know your goals, taxes or the rest of your portfolio. Read the company's filings and consider a licensed adviser before investing.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            content()
        }
    }
}

// MARK: - Verdict

extension Verdict {
    var color: Color {
        switch self {
        case .strongBuy: .green
        case .buy: Color(red: 0.35, green: 0.7, blue: 0.3)
        case .watch: .orange
        case .avoid: .red
        case .insufficientData: .gray
        }
    }
}

/// Color for a 0–100 score.
func scoreColor(_ score: Double) -> Color {
    switch score {
    case 70...: .green
    case 50..<70: .yellow
    case 35..<50: .orange
    default: .red
    }
}

private struct VerdictCard: View {
    let evaluation: Evaluation

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            ScoreRing(score: evaluation.overall, color: evaluation.verdict.color)
                .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 8) {
                Label(evaluation.verdict.title, systemImage: evaluation.verdict.systemImage)
                    .font(.title.bold())
                    .foregroundStyle(evaluation.verdict.color)
                Text(evaluation.verdict.explanation)
                    .fixedSize(horizontal: false, vertical: true)
                Text(headline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if evaluation.downgradedForRedFlags {
                    Text("Lowered one level because of \(evaluation.redFlags.count) red flags.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                if evaluation.coverage < 0.75 && evaluation.verdict != .insufficientData {
                    Text("Based on \(Format.percent(evaluation.coverage * 100, signed: false)) of the usual data, so treat it with extra caution.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(evaluation.verdict.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(evaluation.verdict.color.opacity(0.35)))
    }

    /// "Scored for a Value investor. Strongest: … Weakest: …"
    private var headline: String {
        let scored = evaluation.categories
            .filter { evaluation.style.weight($0.category) > 0 }
            .compactMap { category in category.score.map { (category.category.title, $0) } }
            .sorted { $0.1 > $1.1 }
        var text = "Scored for a \(evaluation.style.title.lowercased()) investor."
        if let best = scored.first {
            text += " Strongest: \(best.0) (\(Int(best.1.rounded())))."
        }
        if scored.count > 1, let worst = scored.last {
            text += " Weakest: \(worst.0) (\(Int(worst.1.rounded())))."
        }
        if let upside = evaluation.upsideToFairValue {
            text += upside >= 0
                ? " Estimated fair value is \(Format.percent(upside, signed: false)) above the current price."
                : " The price is \(Format.percent(-upside, signed: false)) above estimated fair value."
        }
        return text
    }
}

private struct ScoreRing: View {
    let score: Double?
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: (score ?? 0) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(score.map { "\(Int($0.rounded()))" } ?? "—")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("out of 100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Flags

private struct FlagsSection: View {
    let evaluation: Evaluation

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            list("Strengths", systemImage: "checkmark.circle.fill", color: .green,
                 items: evaluation.strengths, empty: "No standout strengths.")
            list("Red Flags", systemImage: "flag.fill", color: .red,
                 items: evaluation.redFlags, empty: "No red flags found.")
        }
    }

    private func list(_ title: String, systemImage: String, color: Color, items: [String], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(color)
            if items.isEmpty {
                Text(empty).foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•").foregroundStyle(color)
                        Text(item).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .font(.callout)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Categories

private struct CategoriesSection: View {
    let evaluation: Evaluation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scorecard").font(.title3.bold())
            Text("Click a row to see what went into it. Weights reflect the \(evaluation.style.title) style.")
                .font(.callout)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(evaluation.categories) { category in
                    CategoryRow(category: category, weight: evaluation.style.weight(category.category))
                    Divider()
                }
            }
        }
    }
}

private struct CategoryRow: View {
    let category: CategoryScore
    let weight: Double
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text(category.category.question)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if category.factors.isEmpty {
                    Text("No data available.").foregroundStyle(.secondary)
                }
                ForEach(category.factors) { factor in
                    FactorRow(factor: factor)
                }
            }
            .padding(.leading, 28)
            .padding(.vertical, 8)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.category.systemImage)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                Text(category.category.title)
                    .frame(width: 150, alignment: .leading)
                ScoreBar(score: category.score)
                    .frame(height: 8)
                Text(category.score.map { "\(Int($0.rounded()))" } ?? "—")
                    .monospacedDigit()
                    .bold()
                    .frame(width: 32, alignment: .trailing)
                Text(weight > 0 ? "\(Int(weight))%" : "not weighted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
                    .help("Share of the overall score for this investor style")
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { expanded.toggle() } }
        }
        .padding(.vertical, 6)
        .opacity(weight > 0 ? 1 : 0.6)
    }
}

private struct FactorRow: View {
    let factor: Factor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(factor.name)
                    .frame(width: 180, alignment: .leading)
                Text(factor.value)
                    .monospacedDigit()
                    .bold()
                    .frame(width: 140, alignment: .leading)
                ScoreBar(score: factor.score)
                    .frame(width: 120, height: 6)
                Text(rating)
                    .font(.caption)
                    .foregroundStyle(scoreColor(factor.score))
            }
            Text(factor.guide)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rating: String {
        switch factor.score {
        case 70...: "Good"
        case 40..<70: "Fair"
        default: "Weak"
        }
    }
}

private struct ScoreBar: View {
    let score: Double?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                if let score {
                    Capsule()
                        .fill(scoreColor(score))
                        .frame(width: max(proxy.size.height, proxy.size.width * score / 100))
                }
            }
        }
    }
}

// MARK: - Fair value

private struct FairValueSection: View {
    let evaluation: Evaluation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What Is It Worth?").font(.title3.bold())
            if evaluation.fairValues.isEmpty {
                Text("Not enough earnings or analyst data to estimate a fair value.")
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                    GridRow {
                        Text("Method").foregroundStyle(.secondary)
                        Text("Estimate").foregroundStyle(.secondary)
                        Text("Vs price").foregroundStyle(.secondary)
                        Text("How it's calculated").foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    ForEach(evaluation.fairValues) { estimate in
                        GridRow {
                            Text(estimate.method).bold()
                            Text(Format.price(estimate.value)).monospacedDigit()
                            ChangeText(value: (estimate.value / evaluation.price - 1) * 100)
                            Text(estimate.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let fair = evaluation.fairValue, let upside = evaluation.upsideToFairValue {
                    Text(entryAdvice(fair: fair, upside: upside))
                        .font(.callout)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func entryAdvice(fair: Double, upside: Double) -> String {
        let midpoint = "Middle estimate: \(Format.price(fair))."
        switch upside {
        case 25...:
            return "\(midpoint) The price is well below the estimates, a meaningful margin of safety if the numbers hold up."
        case 5..<25:
            return "\(midpoint) The price is somewhat below the estimates."
        case -10..<5:
            return "\(midpoint) The price is close to fair value, so returns will mostly depend on future growth."
        default:
            return "\(midpoint) The price is above the estimates. Consider waiting for a pullback or starting with a smaller position."
        }
    }
}
