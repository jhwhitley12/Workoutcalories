import Foundation

struct PriceBar: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

/// Valuation data from Yahoo's quote endpoint. Optional: the screener still works without it.
struct Fundamentals {
    var name: String?
    var marketCap: Double?
    var trailingPE: Double?
    var forwardPE: Double?
    /// Trailing annual dividend yield, in percent.
    var dividendYield: Double?
    var quoteType: String?
}

/// Everything the screener knows about one symbol.
struct StockSnapshot: Identifiable {
    var id: String { symbol }
    let symbol: String
    var name: String
    let currency: String
    let exchange: String
    let price: Double
    let bars: [PriceBar]

    let changeDay: Double?
    let change1W: Double?
    let change1M: Double?
    let change3M: Double?
    let changeYTD: Double?
    let change1Y: Double?
    let rsi14: Double?
    let sma50: Double?
    let sma200: Double?
    let high52: Double
    let low52: Double
    let volume: Double?
    let avgVolume50: Double?
    let volatility: Double?

    var fundamentals: Fundamentals?

    /// Percent below the 52-week high (0 means at the high).
    var fromHigh52: Double? { high52 > 0 ? (price / high52 - 1) * 100 : nil }
    var aboveSMA50Pct: Double? { sma50.map { (price / $0 - 1) * 100 } }
    var aboveSMA200Pct: Double? { sma200.map { (price / $0 - 1) * 100 } }
    var relativeVolume: Double? {
        guard let volume, let avgVolume50, avgVolume50 > 0 else { return nil }
        return volume / avgVolume50
    }
    var marketCap: Double? { fundamentals?.marketCap }
    var pe: Double? { fundamentals?.trailingPE }
    var dividendYield: Double? { fundamentals?.dividendYield }

    var yahooURL: URL? { URL(string: "https://finance.yahoo.com/quote/\(symbol)") }
}

// Non-optional keys for Table sorting. Missing values sort as lowest.
extension StockSnapshot {
    var sortChangeDay: Double { changeDay ?? -.infinity }
    var sortChange1W: Double { change1W ?? -.infinity }
    var sortChange1M: Double { change1M ?? -.infinity }
    var sortChange3M: Double { change3M ?? -.infinity }
    var sortChangeYTD: Double { changeYTD ?? -.infinity }
    var sortChange1Y: Double { change1Y ?? -.infinity }
    var sortRSI: Double { rsi14 ?? -.infinity }
    var sortFromHigh: Double { fromHigh52 ?? -.infinity }
    var sortRelVolume: Double { relativeVolume ?? -.infinity }
    var sortMarketCap: Double { marketCap ?? -.infinity }
    var sortPE: Double { pe ?? -.infinity }
    var sortYield: Double { dividendYield ?? -.infinity }
}

extension StockSnapshot {
    /// Builds a snapshot and its indicators from daily bars (oldest first).
    init(symbol: String, name: String, currency: String, exchange: String,
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
        fundamentals = nil
    }
}
