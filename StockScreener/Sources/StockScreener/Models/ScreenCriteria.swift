import Foundation

/// A numeric value a screen can filter on.
enum Metric: String, CaseIterable, Identifiable, Codable {
    case price
    case changeDay
    case change1W
    case change1M
    case change3M
    case changeYTD
    case change1Y
    case rsi14
    case fromHigh52
    case aboveSMA50
    case aboveSMA200
    case relativeVolume
    case volatility
    case marketCap
    case pe
    case dividendYield

    var id: String { rawValue }

    enum Group: String, CaseIterable {
        case performance = "Price & Performance"
        case technical = "Technical"
        case fundamental = "Fundamentals"
    }

    var group: Group {
        switch self {
        case .price, .changeDay, .change1W, .change1M, .change3M, .changeYTD, .change1Y:
            .performance
        case .rsi14, .fromHigh52, .aboveSMA50, .aboveSMA200, .relativeVolume, .volatility:
            .technical
        case .marketCap, .pe, .dividendYield:
            .fundamental
        }
    }

    var title: String {
        switch self {
        case .price: "Price"
        case .changeDay: "Change Today"
        case .change1W: "Change 1 Week"
        case .change1M: "Change 1 Month"
        case .change3M: "Change 3 Months"
        case .changeYTD: "Change YTD"
        case .change1Y: "Change 1 Year"
        case .rsi14: "RSI (14)"
        case .fromHigh52: "From 52-Week High"
        case .aboveSMA50: "Vs 50-Day SMA"
        case .aboveSMA200: "Vs 200-Day SMA"
        case .relativeVolume: "Relative Volume"
        case .volatility: "Volatility (1Y)"
        case .marketCap: "Market Cap"
        case .pe: "P/E (TTM)"
        case .dividendYield: "Dividend Yield"
        }
    }

    var unit: String {
        switch self {
        case .price: "$"
        case .rsi14: ""
        case .relativeVolume: "×"
        case .marketCap: "B"
        case .pe: "×"
        default: "%"
        }
    }

    var help: String {
        switch self {
        case .price: "Last price."
        case .changeDay: "Percent change from the previous close."
        case .change1W, .change1M, .change3M: "Percent change over 5, 21 or 63 trading days."
        case .changeYTD: "Percent change since the last close of the previous year."
        case .change1Y: "Percent change over the past year."
        case .rsi14: "14-day Relative Strength Index (0–100). Below 30 is often called oversold, above 70 overbought."
        case .fromHigh52: "Percent below the 52-week high. 0 means at the high, −10 means 10% below it."
        case .aboveSMA50: "Percent above (+) or below (−) the 50-day simple moving average."
        case .aboveSMA200: "Percent above (+) or below (−) the 200-day simple moving average."
        case .relativeVolume: "Today's volume divided by the 50-day average. During trading hours today's volume is still partial."
        case .volatility: "Annualized standard deviation of daily returns over the past year."
        case .marketCap: "Market capitalization in billions."
        case .pe: "Trailing twelve-month price/earnings ratio."
        case .dividendYield: "Trailing annual dividend yield."
        }
    }

    func value(for stock: StockSnapshot) -> Double? {
        switch self {
        case .price: stock.price
        case .changeDay: stock.changeDay
        case .change1W: stock.change1W
        case .change1M: stock.change1M
        case .change3M: stock.change3M
        case .changeYTD: stock.changeYTD
        case .change1Y: stock.change1Y
        case .rsi14: stock.rsi14
        case .fromHigh52: stock.fromHigh52
        case .aboveSMA50: stock.aboveSMA50Pct
        case .aboveSMA200: stock.aboveSMA200Pct
        case .relativeVolume: stock.relativeVolume
        case .volatility: stock.volatility
        case .marketCap: stock.marketCap.map { $0 / 1_000_000_000 }
        case .pe: stock.pe
        case .dividendYield: stock.dividendYield
        }
    }
}

struct RangeFilter: Codable, Equatable {
    var enabled = false
    var min: Double?
    var max: Double?

    /// A stock with no value for an enabled filter does not match.
    func matches(_ value: Double?) -> Bool {
        guard enabled else { return true }
        guard let value else { return false }
        if let min, value < min { return false }
        if let max, value > max { return false }
        return true
    }
}

enum TrendCheck: String, CaseIterable, Identifiable, Codable {
    case aboveSMA50
    case aboveSMA200
    case goldenCross
    case belowSMA200

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aboveSMA50: "Price above 50-day SMA"
        case .aboveSMA200: "Price above 200-day SMA"
        case .goldenCross: "50-day SMA above 200-day"
        case .belowSMA200: "Price below 200-day SMA"
        }
    }

    func matches(_ stock: StockSnapshot) -> Bool {
        switch self {
        case .aboveSMA50: stock.sma50.map { stock.price > $0 } ?? false
        case .aboveSMA200: stock.sma200.map { stock.price > $0 } ?? false
        case .belowSMA200: stock.sma200.map { stock.price < $0 } ?? false
        case .goldenCross:
            if let s50 = stock.sma50, let s200 = stock.sma200 { s50 > s200 } else { false }
        }
    }
}

struct ScreenCriteria: Codable, Equatable {
    var ranges: [Metric: RangeFilter] = [:]
    var trends: Set<TrendCheck> = []

    var activeCount: Int {
        ranges.values.filter(\.enabled).count + trends.count
    }

    var usesFundamentals: Bool {
        ranges.contains { $0.key.group == .fundamental && $0.value.enabled }
    }

    func matches(_ stock: StockSnapshot) -> Bool {
        for (metric, filter) in ranges where !filter.matches(metric.value(for: stock)) {
            return false
        }
        return trends.allSatisfy { $0.matches(stock) }
    }

    subscript(metric: Metric) -> RangeFilter {
        get { ranges[metric] ?? RangeFilter() }
        set { ranges[metric] = newValue }
    }

    private static func make(_ ranges: [Metric: (Double?, Double?)], trends: Set<TrendCheck> = []) -> ScreenCriteria {
        var criteria = ScreenCriteria(trends: trends)
        for (metric, bounds) in ranges {
            criteria.ranges[metric] = RangeFilter(enabled: true, min: bounds.0, max: bounds.1)
        }
        return criteria
    }

    static let presets: [ScreenPreset] = [
        ScreenPreset(name: "Momentum Leaders", criteria: make([.change3M: (10, nil), .rsi14: (50, 75)], trends: [.aboveSMA50, .aboveSMA200])),
        ScreenPreset(name: "Near 52-Week High", criteria: make([.fromHigh52: (-3, nil)])),
        ScreenPreset(name: "Golden Cross Uptrend", criteria: make([:], trends: [.goldenCross, .aboveSMA200])),
        ScreenPreset(name: "Oversold (RSI < 30)", criteria: make([.rsi14: (nil, 30)])),
        ScreenPreset(name: "Pullback in Uptrend", criteria: make([.rsi14: (nil, 40)], trends: [.aboveSMA200])),
        ScreenPreset(name: "Unusual Volume", criteria: make([.relativeVolume: (2, nil)])),
        ScreenPreset(name: "Big Gainers Today", criteria: make([.changeDay: (3, nil)])),
        ScreenPreset(name: "Big Losers Today", criteria: make([.changeDay: (nil, -3)])),
        ScreenPreset(name: "Value (P/E under 15)", criteria: make([.pe: (0, 15), .marketCap: (10, nil)])),
        ScreenPreset(name: "Dividend Income", criteria: make([.dividendYield: (3, nil), .pe: (0, 25)])),
        ScreenPreset(name: "Low Volatility", criteria: make([.volatility: (nil, 20)], trends: [.aboveSMA200])),
    ]
}

struct ScreenPreset: Identifiable {
    var id: String { name }
    let name: String
    let criteria: ScreenCriteria
}
