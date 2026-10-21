import Charts
import SwiftUI

struct StockDetailView: View {
    let stock: StockSnapshot

    @State private var range: ChartRange = .year

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
        let closes = stock.bars.map(\.close)
        let sma50 = Indicators.smaSeries(closes, period: 50)
        let sma200 = Indicators.smaSeries(closes, period: 200)
        let start = max(0, stock.bars.count - range.bars)
        var result: [ChartPoint] = []
        for i in start..<stock.bars.count {
            let date = stock.bars[i].date
            result.append(ChartPoint(date: date, value: closes[i], series: "Price"))
            if let value = sma50[i] { result.append(ChartPoint(date: date, value: value, series: "SMA 50")) }
            if let value = sma200[i] { result.append(ChartPoint(date: date, value: value, series: "SMA 200")) }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                chart
                stats
                if let url = stock.yahooURL {
                    Link(destination: url) {
                        Label("Open in Yahoo Finance", systemImage: "safari")
                    }
                }
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stock.symbol)
                .font(.title.bold())
            Text(stock.name)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Format.price(stock.price))
                    .font(.title2.monospacedDigit())
                Text(stock.currency)
                    .foregroundStyle(.secondary)
                ChangeText(value: stock.changeDay)
                    .font(.title3)
            }
            if !stock.exchange.isEmpty {
                Text(stock.exchange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var chart: some View {
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
            .frame(height: 240)
        }
    }

    private var stats: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            statRow("1 Week", ChangeText(value: stock.change1W))
            statRow("1 Month", ChangeText(value: stock.change1M))
            statRow("3 Months", ChangeText(value: stock.change3M))
            statRow("Year to Date", ChangeText(value: stock.changeYTD))
            statRow("1 Year", ChangeText(value: stock.change1Y))
            Divider().gridCellColumns(2)
            statRow("52-Week Range", Text("\(Format.price(stock.low52)) – \(Format.price(stock.high52))"))
            statRow("From 52-Week High", Text(Format.percent(stock.fromHigh52, signed: false)))
            statRow("50-Day SMA", Text("\(Format.price(stock.sma50))  (\(Format.percent(stock.aboveSMA50Pct)))"))
            statRow("200-Day SMA", Text("\(Format.price(stock.sma200))  (\(Format.percent(stock.aboveSMA200Pct)))"))
            statRow("RSI (14)", RSIText(value: stock.rsi14))
            statRow("Volatility (1Y)", Text(Format.percent(stock.volatility, signed: false)))
            statRow("Volume", Text(Format.compact(stock.volume)))
            statRow("Avg Volume (50D)", Text(Format.compact(stock.avgVolume50)))
            statRow("Relative Volume", Text(Format.number(stock.relativeVolume, digits: 2)))
            Divider().gridCellColumns(2)
            statRow("Market Cap", Text(Format.compact(stock.marketCap)))
            statRow("P/E (TTM)", Text(Format.number(stock.pe)))
            statRow("Forward P/E", Text(Format.number(stock.fundamentals?.forwardPE)))
            statRow("Dividend Yield", Text(Format.percent(stock.dividendYield, signed: false)))
        }
        .font(.callout)
    }

    private func statRow(_ title: String, _ value: some View) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            value
                .monospacedDigit()
                .gridColumnAlignment(.trailing)
        }
    }
}
