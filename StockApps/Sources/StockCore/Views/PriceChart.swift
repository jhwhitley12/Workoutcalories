import Charts
import SwiftUI

/// Line chart of closing prices with 50- and 200-day moving averages and a range picker.
public struct PriceChart: View {
    let bars: [PriceBar]
    var height: CGFloat

    @State private var range: ChartRange = .year

    public init(bars: [PriceBar], height: CGFloat = 240) {
        self.bars = bars
        self.height = height
    }

    enum ChartRange: String, CaseIterable, Identifiable {
        case month = "1M"
        case quarter = "3M"
        case half = "6M"
        case year = "1Y"

        var id: String { rawValue }

        var bars: Int {
            switch self {
            case .month: 21
            case .quarter: 63
            case .half: 126
            case .year: 260
            }
        }
    }

    private struct ChartPoint: Identifiable {
        var id: String { "\(series)-\(date.timeIntervalSince1970)" }
        let date: Date
        let value: Double
        let series: String
    }

    /// Price plus the 50/200-day SMAs, trimmed to the chosen range.
    private var points: [ChartPoint] {
        let closes = bars.map(\.close)
        let sma50 = Indicators.smaSeries(closes, period: 50)
        let sma200 = Indicators.smaSeries(closes, period: 200)
        let start = max(0, bars.count - range.bars)
        var result: [ChartPoint] = []
        for i in start..<bars.count {
            let date = bars[i].date
            result.append(ChartPoint(date: date, value: closes[i], series: "Price"))
            if let value = sma50[i] { result.append(ChartPoint(date: date, value: value, series: "SMA 50")) }
            if let value = sma200[i] { result.append(ChartPoint(date: date, value: value, series: "SMA 200")) }
        }
        return result
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Range", selection: $range) {
                ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Series", point.series))
                .lineStyle(StrokeStyle(lineWidth: point.series == "Price" ? 2 : 1.2))
            }
            .chartForegroundStyleScale([
                "Price": Color.accentColor,
                "SMA 50": Color.orange,
                "SMA 200": Color.purple,
            ])
            .chartYScale(domain: .automatic(includesZero: false))
            .chartLegend(position: .bottom)
            .frame(height: height)
        }
    }
}
