import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class ScreenerModel {
    var universe: Universe {
        didSet { save(universe.rawValue, forKey: Keys.universe) }
    }
    var watchlistText: String {
        didSet { save(watchlistText, forKey: Keys.watchlist) }
    }
    var criteria: ScreenCriteria {
        didSet {
            if let data = try? JSONEncoder().encode(criteria) {
                save(data, forKey: Keys.criteria)
            }
        }
    }

    var searchText = ""
    var selection: StockSnapshot.ID?
    var sortOrder = [KeyPathComparator(\StockSnapshot.sortChangeDay, order: .reverse)]

    private(set) var snapshots: [String: StockSnapshot] = [:]
    private(set) var failures: [String: String] = [:]
    private(set) var isLoading = false
    private(set) var progress = 0.0
    private(set) var lastUpdated: Date?
    /// False when Yahoo refused the quote endpoint, so market cap / P/E / yield are missing.
    private(set) var fundamentalsAvailable = true

    private let client = YahooFinanceClient.shared
    private var loadTask: Task<Void, Never>?
    private var loadingSymbols: Set<String> = []

    init() {
        let defaults = UserDefaults.standard
        universe = defaults.string(forKey: Keys.universe).flatMap(Universe.init(rawValue:)) ?? .dow30
        watchlistText = defaults.string(forKey: Keys.watchlist) ?? "AAPL, MSFT, NVDA, GOOGL, AMZN, META, TSLA"
        if let data = defaults.data(forKey: Keys.criteria),
           let saved = try? JSONDecoder().decode(ScreenCriteria.self, from: data) {
            criteria = saved
        } else {
            criteria = ScreenCriteria()
        }
    }

    // MARK: Derived state

    var symbols: [String] {
        universe == .custom ? watchlistText.symbolList : universe.builtInSymbols
    }

    /// Stocks in the current universe that have loaded data.
    var loaded: [StockSnapshot] {
        symbols.compactMap { snapshots[$0] }
    }

    var results: [StockSnapshot] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return loaded
            .filter { criteria.matches($0) }
            .filter { query.isEmpty || $0.symbol.lowercased().contains(query) || $0.name.lowercased().contains(query) }
            .sorted(using: sortOrder)
    }

    var selectedStock: StockSnapshot? {
        selection.flatMap { snapshots[$0] }
    }

    var currentFailures: [LoadFailure] {
        symbols.compactMap { symbol in failures[symbol].map { LoadFailure(symbol: symbol, reason: $0) } }
    }

    // MARK: Loading

    /// Loads every symbol in the universe. With `force` false, only symbols not yet loaded are fetched.
    /// Starting a new refresh cancels the one in progress.
    func refresh(force: Bool = true) {
        if !force && isLoading && symbols.allSatisfy({ snapshots[$0] != nil || loadingSymbols.contains($0) }) {
            return // The load in progress already covers everything missing.
        }
        let previous = loadTask
        previous?.cancel()
        loadTask = Task {
            await previous?.value
            await load(force: force)
        }
    }

    private func load(force: Bool) async {
        let wanted = force ? symbols : symbols.filter { snapshots[$0] == nil }
        guard !wanted.isEmpty, !Task.isCancelled else { return }

        isLoading = true
        loadingSymbols = Set(wanted)
        progress = 0
        defer {
            isLoading = false
            loadingSymbols = []
        }

        let client = client
        var completed = 0
        var loadedSymbols: [String] = []
        await withTaskGroup(of: LoadResult.self) { group in
            var pending = wanted.makeIterator()
            // Keep a handful of requests in flight to stay polite to Yahoo.
            for _ in 0..<8 {
                if let symbol = pending.next() {
                    group.addTask { await Self.load(symbol, using: client) }
                }
            }
            while let item = await group.next() {
                if var snapshot = item.snapshot {
                    snapshot.fundamentals = snapshots[item.symbol]?.fundamentals
                    snapshots[item.symbol] = snapshot
                    failures[item.symbol] = nil
                    loadedSymbols.append(item.symbol)
                } else if !Task.isCancelled {
                    failures[item.symbol] = item.error ?? "Unknown error"
                }
                completed += 1
                // Leave the last 10% for fundamentals.
                progress = 0.9 * Double(completed) / Double(wanted.count)
                if !Task.isCancelled, let symbol = pending.next() {
                    group.addTask { await Self.load(symbol, using: client) }
                }
            }
        }

        if !loadedSymbols.isEmpty && !Task.isCancelled {
            let fundamentals = await client.fundamentals(for: loadedSymbols)
            fundamentalsAvailable = !fundamentals.isEmpty
            for (symbol, data) in fundamentals {
                snapshots[symbol]?.fundamentals = data
                if let name = data.name, snapshots[symbol]?.name == symbol {
                    snapshots[symbol]?.name = name
                }
            }
        }
        progress = 1
        if !Task.isCancelled { lastUpdated = Date() }
    }

    private struct LoadResult {
        let symbol: String
        let snapshot: StockSnapshot?
        let error: String?
    }

    nonisolated private static func load(_ symbol: String, using client: YahooFinanceClient) async -> LoadResult {
        do {
            return LoadResult(symbol: symbol, snapshot: try await client.snapshot(for: symbol), error: nil)
        } catch {
            return LoadResult(symbol: symbol, snapshot: nil, error: error.localizedDescription)
        }
    }

    // MARK: Criteria

    func apply(preset criteria: ScreenCriteria) {
        self.criteria = criteria
    }

    func clearFilters() {
        criteria = ScreenCriteria()
    }

    // MARK: Export

    func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "Stock Screen \(Date().formatted(.iso8601.year().month().day())).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try csv(for: results).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func csv(for stocks: [StockSnapshot]) -> String {
        let metrics = Metric.allCases
        var lines = [(["Symbol", "Name"] + metrics.map(\.title)).map(csvField).joined(separator: ",")]
        for stock in stocks {
            let values = metrics.map { metric in
                metric.value(for: stock).map { String(format: "%.4f", $0) } ?? ""
            }
            lines.append(([stock.symbol, stock.name] + values).map(csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func csvField(_ text: String) -> String {
        guard text.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: Persistence

    private enum Keys {
        static let universe = "universe"
        static let watchlist = "watchlist"
        static let criteria = "criteria"
    }

    private func save(_ value: Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

struct LoadFailure: Identifiable {
    var id: String { symbol }
    let symbol: String
    let reason: String
}
