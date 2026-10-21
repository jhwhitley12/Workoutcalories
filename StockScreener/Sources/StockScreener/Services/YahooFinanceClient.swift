import Foundation

enum YahooError: LocalizedError {
    case badStatus(Int)
    case notFound
    case noData
    case message(String)

    var errorDescription: String? {
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
actor YahooFinanceClient {
    static let shared = YahooFinanceClient()

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

    func snapshot(for symbol: String) async throws -> StockSnapshot {
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
    func fundamentals(for symbols: [String]) async -> [String: Fundamentals] {
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

private extension Array where Element == Double? {
    /// The value at `index`, or nil if out of range or missing.
    func at(_ index: Int) -> Double? {
        indices.contains(index) ? self[index] : nil
    }
}
