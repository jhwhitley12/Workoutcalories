import Foundation

public enum YahooError: LocalizedError {
    case badStatus(Int)
    case notFound
    case noData
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .badStatus(let code): "Yahoo Finance returned HTTP \(code)."
        case .notFound: "Symbol not found."
        case .noData: "No price history."
        case .message(let text): text
        }
    }
}

/// Talks to Yahoo Finance's public (unofficial) JSON endpoints. No API key needed.
///
/// - Price history comes from the chart endpoint, which needs no login.
/// - Market cap, P/E and dividend yield come from the quote endpoint, which needs a
///   cookie + "crumb". That part is best effort: if it fails the screener still runs
///   and fundamental columns show "—".
public actor YahooFinanceClient {
    public static let shared = YahooFinanceClient()

    private let session: URLSession
    private var crumb: String?

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Accept": "application/json,text/plain,*/*",
        ]
        session = URLSession(configuration: config)
    }

    // MARK: Price history

    public func snapshot(for symbol: String) async throws -> StockSnapshot {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)")!
        components.queryItems = [
            URLQueryItem(name: "range", value: "1y"),
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "includePrePost", value: "false"),
        ]
        let data = try await get(components.url!, retries: 1)
        let response = try JSONDecoder().decode(ChartResponse.self, from: data)
        if let error = response.chart.error {
            if error.code == "Not Found" { throw YahooError.notFound }
            throw YahooError.message(error.description ?? "Unknown error")
        }
        guard let result = response.chart.result?.first else { throw YahooError.noData }

        let quote = result.indicators.quote.first
        var bars: [PriceBar] = []
        for (i, timestamp) in (result.timestamp ?? []).enumerated() {
            guard let close = quote?.close?.at(i) else { continue }
            bars.append(PriceBar(
                date: Date(timeIntervalSince1970: timestamp),
                open: quote?.open?.at(i) ?? close,
                high: quote?.high?.at(i) ?? close,
                low: quote?.low?.at(i) ?? close,
                close: close,
                volume: quote?.volume?.at(i) ?? 0
            ))
        }
        guard !bars.isEmpty else { throw YahooError.noData }

        let meta = result.meta
        return StockSnapshot(
            symbol: symbol,
            name: meta.longName ?? meta.shortName ?? symbol,
            currency: meta.currency ?? "USD",
            exchange: meta.fullExchangeName ?? meta.exchangeName ?? "",
            price: meta.regularMarketPrice,
            high52: meta.fiftyTwoWeekHigh,
            low52: meta.fiftyTwoWeekLow,
            bars: bars
        )
    }

    // MARK: Fundamentals

    /// Returns fundamentals keyed by symbol. Returns an empty dictionary if Yahoo refuses.
    public func fundamentals(for symbols: [String]) async -> [String: Fundamentals] {
        var result: [String: Fundamentals] = [:]
        for start in stride(from: 0, to: symbols.count, by: 50) {
            let batch = Array(symbols[start..<min(start + 50, symbols.count)])
            guard let quotes = await quoteBatch(batch) else { break }
            for q in quotes {
                result[q.symbol] = Fundamentals(
                    name: q.longName ?? q.shortName,
                    marketCap: q.marketCap,
                    trailingPE: q.trailingPE,
                    forwardPE: q.forwardPE,
                    dividendYield: q.trailingAnnualDividendYield.map { $0 * 100 },
                    quoteType: q.quoteType
                )
            }
        }
        return result
    }

    /// Company profile, financial ratios and analyst data. Needs the same cookie + crumb as `fundamentals`.
    public func summary(for symbol: String) async throws -> CompanySummary {
        do {
            return try await loadSummary(symbol, modules: Self.summaryModules, isRetry: false)
        } catch YahooError.notFound {
            // Funds have no financialData module, and Yahoo rejects the whole request when one is missing.
            return try await loadSummary(symbol, modules: Self.fundSummaryModules, isRetry: false)
        }
    }

    private static let summaryModules = "price,summaryProfile,summaryDetail,financialData,defaultKeyStatistics"
    private static let fundSummaryModules = "price,summaryDetail,defaultKeyStatistics"

    private func loadSummary(_ symbol: String, modules: String, isRetry: Bool) async throws -> CompanySummary {
        guard let crumb = await currentCrumb() else {
            throw YahooError.message("Yahoo Finance didn't allow access to company financials right now.")
        }
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var components = URLComponents(string: "https://query2.finance.yahoo.com/v10/finance/quoteSummary/\(encoded)")!
        components.queryItems = [
            URLQueryItem(name: "modules", value: modules),
            URLQueryItem(name: "crumb", value: crumb),
        ]
        let data: Data
        do {
            data = try await get(components.url!, retries: 1)
        } catch YahooError.badStatus(let code) where (code == 401 || code == 403) && !isRetry {
            // The crumb expired; get a new one and try once more.
            self.crumb = nil
            return try await loadSummary(symbol, modules: modules, isRetry: true)
        }
        let response = try JSONDecoder().decode(QuoteSummaryResponse.self, from: data)
        guard let result = response.quoteSummary.result?.first else {
            throw YahooError.message(response.quoteSummary.error?.description ?? "No company data.")
        }
        return result.companySummary
    }

    private func quoteBatch(_ symbols: [String], isRetry: Bool = false) async -> [QuoteResponse.Quote]? {
        guard let crumb = await currentCrumb() else { return nil }
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v7/finance/quote")!
        components.queryItems = [
            URLQueryItem(name: "symbols", value: symbols.joined(separator: ",")),
            URLQueryItem(name: "crumb", value: crumb),
        ]
        do {
            let data = try await get(components.url!, retries: 0)
            return try JSONDecoder().decode(QuoteResponse.self, from: data).quoteResponse.result ?? []
        } catch YahooError.badStatus(let code) where (code == 401 || code == 403) && !isRetry {
            // The crumb expired; get a new one and try once more.
            self.crumb = nil
            return await quoteBatch(symbols, isRetry: true)
        } catch {
            return nil
        }
    }

    private func currentCrumb() async -> String? {
        if let crumb { return crumb }
        // Visiting these pages sets the cookies the crumb is tied to.
        for cookiePage in ["https://fc.yahoo.com", "https://finance.yahoo.com/quote/AAPL"] {
            _ = try? await session.data(from: URL(string: cookiePage)!)
            if let crumb = await fetchCrumb() {
                self.crumb = crumb
                return crumb
            }
        }
        return nil
    }

    private func fetchCrumb() async -> String? {
        guard let url = URL(string: "https://query2.finance.yahoo.com/v1/test/getcrumb"),
              let reply = try? await session.data(from: url),
              (reply.1 as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: reply.0, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, !text.contains("<"), !text.contains("{")
        else { return nil }
        return text
    }

    // MARK: HTTP

    private func get(_ url: URL, retries: Int) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        switch status {
        case 200..<300:
            return data
        case 404:
            throw YahooError.notFound
        case 429 where retries > 0, 500..<600 where retries > 0:
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return try await get(url, retries: retries - 1)
        default:
            throw YahooError.badStatus(status)
        }
    }
}

// MARK: - Response types

private struct ChartResponse: Decodable {
    let chart: Chart

    struct Chart: Decodable {
        let result: [Result]?
        let error: APIError?
    }

    struct APIError: Decodable {
        let code: String?
        let description: String?
    }

    struct Result: Decodable {
        let meta: Meta
        let timestamp: [Double]?
        let indicators: Indicators
    }

    struct Meta: Decodable {
        let currency: String?
        let exchangeName: String?
        let fullExchangeName: String?
        let longName: String?
        let shortName: String?
        let regularMarketPrice: Double?
        let fiftyTwoWeekHigh: Double?
        let fiftyTwoWeekLow: Double?
    }

    struct Indicators: Decodable {
        let quote: [Quote]
    }

    struct Quote: Decodable {
        let open: [Double?]?
        let high: [Double?]?
        let low: [Double?]?
        let close: [Double?]?
        let volume: [Double?]?
    }
}

private struct QuoteResponse: Decodable {
    let quoteResponse: Body

    struct Body: Decodable {
        let result: [Quote]?
    }

    struct Quote: Decodable {
        let symbol: String
        let longName: String?
        let shortName: String?
        let quoteType: String?
        let marketCap: Double?
        let trailingPE: Double?
        let forwardPE: Double?
        let trailingAnnualDividendYield: Double?
    }
}

private struct QuoteSummaryResponse: Decodable {
    let quoteSummary: Body

    struct Body: Decodable {
        let result: [Modules]?
        let error: ChartResponse.APIError?
    }

    struct Modules: Decodable {
        let price: Price?
        let summaryProfile: Profile?
        let summaryDetail: Detail?
        let financialData: Financial?
        let defaultKeyStatistics: KeyStatistics?

        var companySummary: CompanySummary {
            var s = CompanySummary()
            s.name = price?.longName ?? price?.shortName
            s.quoteType = price?.quoteType
            s.marketCap = price?.marketCap?.raw ?? detail?.marketCap?.raw

            s.sector = summaryProfile?.sector
            s.industry = summaryProfile?.industry
            s.country = summaryProfile?.country
            s.website = summaryProfile?.website
            s.businessSummary = summaryProfile?.longBusinessSummary
            s.employees = summaryProfile?.fullTimeEmployees

            s.trailingPE = detail?.trailingPE?.raw
            s.forwardPE = detail?.forwardPE?.raw ?? defaultKeyStatistics?.forwardPE?.raw
            s.priceToSales = detail?.priceToSalesTrailing12Months?.raw
            s.dividendYield = detail?.dividendYield?.raw
            s.payoutRatio = detail?.payoutRatio?.raw
            s.beta = detail?.beta?.raw ?? defaultKeyStatistics?.beta?.raw

            s.pegRatio = defaultKeyStatistics?.pegRatio?.raw
            s.priceToBook = defaultKeyStatistics?.priceToBook?.raw
            s.enterpriseToEbitda = defaultKeyStatistics?.enterpriseToEbitda?.raw
            s.trailingEps = defaultKeyStatistics?.trailingEps?.raw
            s.forwardEps = defaultKeyStatistics?.forwardEps?.raw
            s.bookValuePerShare = defaultKeyStatistics?.bookValue?.raw
            s.shortPercentOfFloat = defaultKeyStatistics?.shortPercentOfFloat?.raw

            let f = financialData
            s.revenueGrowth = f?.revenueGrowth?.raw
            s.earningsGrowth = f?.earningsGrowth?.raw
            s.grossMargins = f?.grossMargins?.raw
            s.operatingMargins = f?.operatingMargins?.raw
            s.profitMargins = f?.profitMargins?.raw ?? defaultKeyStatistics?.profitMargins?.raw
            s.returnOnEquity = f?.returnOnEquity?.raw
            s.returnOnAssets = f?.returnOnAssets?.raw
            s.totalCash = f?.totalCash?.raw
            s.totalDebt = f?.totalDebt?.raw
            // Yahoo reports debt/equity as a percentage (150 = 1.5×).
            s.debtToEquity = f?.debtToEquity?.raw.map { $0 / 100 }
            s.currentRatio = f?.currentRatio?.raw
            s.freeCashflow = f?.freeCashflow?.raw
            s.operatingCashflow = f?.operatingCashflow?.raw
            s.totalRevenue = f?.totalRevenue?.raw
            s.targetMeanPrice = f?.targetMeanPrice?.raw
            s.targetHighPrice = f?.targetHighPrice?.raw
            s.targetLowPrice = f?.targetLowPrice?.raw
            s.recommendationMean = f?.recommendationMean?.raw
            s.recommendationKey = f?.recommendationKey
            s.analystCount = f?.numberOfAnalystOpinions?.raw
            return s
        }

        private var detail: Detail? { summaryDetail }
    }

    struct Price: Decodable {
        let longName: String?
        let shortName: String?
        let quoteType: String?
        let marketCap: YNumber?
    }

    struct Profile: Decodable {
        let sector: String?
        let industry: String?
        let country: String?
        let website: String?
        let longBusinessSummary: String?
        let fullTimeEmployees: Double?
    }

    struct Detail: Decodable {
        let marketCap: YNumber?
        let trailingPE: YNumber?
        let forwardPE: YNumber?
        let priceToSalesTrailing12Months: YNumber?
        let dividendYield: YNumber?
        let payoutRatio: YNumber?
        let beta: YNumber?
    }

    struct KeyStatistics: Decodable {
        let forwardPE: YNumber?
        let pegRatio: YNumber?
        let priceToBook: YNumber?
        let enterpriseToEbitda: YNumber?
        let trailingEps: YNumber?
        let forwardEps: YNumber?
        let bookValue: YNumber?
        let beta: YNumber?
        let shortPercentOfFloat: YNumber?
        let profitMargins: YNumber?
    }

    struct Financial: Decodable {
        let revenueGrowth: YNumber?
        let earningsGrowth: YNumber?
        let grossMargins: YNumber?
        let operatingMargins: YNumber?
        let profitMargins: YNumber?
        let returnOnEquity: YNumber?
        let returnOnAssets: YNumber?
        let totalCash: YNumber?
        let totalDebt: YNumber?
        let debtToEquity: YNumber?
        let currentRatio: YNumber?
        let freeCashflow: YNumber?
        let operatingCashflow: YNumber?
        let totalRevenue: YNumber?
        let targetMeanPrice: YNumber?
        let targetHighPrice: YNumber?
        let targetLowPrice: YNumber?
        let recommendationMean: YNumber?
        let recommendationKey: String?
        let numberOfAnalystOpinions: YNumber?
    }
}

/// Yahoo wraps numbers as {"raw": 1.23, "fmt": "1.23"}, or {} when missing. Plain numbers are accepted too.
private struct YNumber: Decodable {
    let raw: Double?

    private enum CodingKeys: String, CodingKey {
        case raw
    }

    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
            raw = try? keyed.decode(Double.self, forKey: .raw)
        } else if let single = try? decoder.singleValueContainer(), let value = try? single.decode(Double.self) {
            raw = value
        } else {
            raw = nil
        }
    }
}

private extension Array where Element == Double? {
    /// The value at `index`, or nil if out of range or missing.
    func at(_ index: Int) -> Double? {
        indices.contains(index) ? self[index] : nil
    }
}
