import Foundation

public struct PriceBar: Identifiable, Hashable {
    public var id: Date { date }
    public let date: Date
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double

    public init(date: Date, open: Double, high: Double, low: Double, close: Double, volume: Double) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}

/// Valuation data from Yahoo's quote endpoint. Optional: the screener still works without it.
public struct Fundamentals {
    public var name: String?
    public var marketCap: Double?
    public var trailingPE: Double?
    public var forwardPE: Double?
    /// Trailing annual dividend yield, in percent.
    public var dividendYield: Double?
    public var quoteType: String?
}

/// Everything known about one symbol's price history.
public struct StockSnapshot: Identifiable {
    public var id: String { symbol }
    public let symbol: String
    public var name: String
    public let currency: String
    public let exchange: String
    public let price: Double
    public let bars: [PriceBar]

    public let changeDay: Double?
    public let change1W: Double?
    public let change1M: Double?
    public let change3M: Double?
    public let changeYTD: Double?
    public let change1Y: Double?
    public let rsi14: Double?
    public let sma50: Double?
    public let sma200: Double?
    public let high52: Double
    public let low52: Double
    public let volume: Double?
    public let avgVolume50: Double?
    public let volatility: Double?
    public let maxDrawdown: Double?

    public var fundamentals: Fundamentals?

    /// Percent below the 52-week high (0 means at the high).
    public var fromHigh52: Double? { high52 > 0 ? (price / high52 - 1) * 100 : nil }
    public var aboveSMA50Pct: Double? { sma50.map { (price / $0 - 1) * 100 } }
    public var aboveSMA200Pct: Double? { sma200.map { (price / $0 - 1) * 100 } }
    public var relativeVolume: Double? {
        guard let volume, let avgVolume50, avgVolume50 > 0 else { return nil }
        return volume / avgVolume50
    }
    public var marketCap: Double? { fundamentals?.marketCap }
    public var pe: Double? { fundamentals?.trailingPE }
    public var dividendYield: Double? { fundamentals?.dividendYield }

    public var yahooURL: URL? { URL(string: "https://finance.yahoo.com/quote/\(symbol)") }
}

// Non-optional keys for Table sorting. Missing values sort as lowest.
extension StockSnapshot {
    public var sortChangeDay: Double { changeDay ?? -.infinity }
    public var sortChange1W: Double { change1W ?? -.infinity }
    public var sortChange1M: Double { change1M ?? -.infinity }
    public var sortChange3M: Double { change3M ?? -.infinity }
    public var sortChangeYTD: Double { changeYTD ?? -.infinity }
    public var sortChange1Y: Double { change1Y ?? -.infinity }
    public var sortRSI: Double { rsi14 ?? -.infinity }
    public var sortFromHigh: Double { fromHigh52 ?? -.infinity }
    public var sortRelVolume: Double { relativeVolume ?? -.infinity }
    public var sortMarketCap: Double { marketCap ?? -.infinity }
    public var sortPE: Double { pe ?? -.infinity }
    public var sortYield: Double { dividendYield ?? -.infinity }
}

extension StockSnapshot {
    /// Builds a snapshot and its indicators from daily bars (oldest first).
    public init(symbol: String, name: String, currency: String, exchange: String,
                price: Double?, high52: Double?, low52: Double?, bars: [PriceBar]) {
        let closes = bars.map(\.close)
        let price = price ?? closes.last ?? 0
        self.symbol = symbol
        self.name = name
        self.currency = currency
        self.exchange = exchange
        self.price = price
        self.bars = bars

        changeDay = Indicators.percentChange(closes, current: price, lookback: 1)
        change1W = Indicators.percentChange(closes, current: price, lookback: 5)
        change1M = Indicators.percentChange(closes, current: price, lookback: 21)
        change3M = Indicators.percentChange(closes, current: price, lookback: 63)
        if closes.count > 240 {
            change1Y = Indicators.percentChange(closes, current: price, lookback: closes.count - 1)
        } else {
            change1Y = nil
        }

        let calendar = Calendar.current
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: Date())) ?? Date()
        if let base = bars.last(where: { $0.date < startOfYear })?.close, base > 0 {
            changeYTD = (price / base - 1) * 100
        } else {
            changeYTD = nil
        }

        rsi14 = Indicators.rsi(closes, period: 14)
        sma50 = Indicators.sma(closes, period: 50)
        sma200 = Indicators.sma(closes, period: 200)

        let barHigh = bars.map(\.high).max() ?? price
        let barLow = bars.map(\.low).filter { $0 > 0 }.min() ?? price
        self.high52 = max(high52 ?? barHigh, price)
        self.low52 = min(low52 ?? barLow, price)

        let volumes = bars.map(\.volume)
        volume = volumes.last
        avgVolume50 = Indicators.averageExcludingLast(volumes, period: 50)
        volatility = Indicators.annualizedVolatility(closes)
        maxDrawdown = Indicators.maxDrawdown(closes)
        fundamentals = nil
    }
}
