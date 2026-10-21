import Foundation
import Observation
import StockCore

@MainActor
@Observable
final class EvaluatorModel {
    var style: InvestorStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: Keys.style) }
    }
    private(set) var recentSymbols: [String] {
        didSet { UserDefaults.standard.set(recentSymbols, forKey: Keys.recent) }
    }

    var symbolInput = ""
    var selectedSymbol: String?

    private(set) var stocks: [String: StockSnapshot] = [:]
    private(set) var summaries: [String: CompanySummary] = [:]
    /// Why company financials couldn't be loaded, keyed by symbol.
    private(set) var summaryErrors: [String: String] = [:]
    private(set) var loadingSymbol: String?
    private(set) var errorMessage: String?

    private let client = YahooFinanceClient.shared
    private var loadTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        style = defaults.string(forKey: Keys.style).flatMap(InvestorStyle.init(rawValue:)) ?? .balanced
        recentSymbols = defaults.stringArray(forKey: Keys.recent) ?? []
    }

    // MARK: Derived state

    var stock: StockSnapshot? { selectedSymbol.flatMap { stocks[$0] } }
    var summary: CompanySummary? { selectedSymbol.flatMap { summaries[$0] } }
    var summaryError: String? { selectedSymbol.flatMap { summaryErrors[$0] } }
    var isLoading: Bool { loadingSymbol != nil }

    /// Recomputed whenever the data or the investor style changes.
    var evaluation: Evaluation? {
        guard let stock else { return nil }
        return Evaluator.evaluate(stock: stock, summary: summary, style: style)
    }

    /// Overall score for a recent symbol that's already been loaded, for the sidebar.
    func evaluation(for symbol: String) -> Evaluation? {
        guard let stock = stocks[symbol] else { return nil }
        return Evaluator.evaluate(stock: stock, summary: summaries[symbol], style: style)
    }

    // MARK: Actions

    /// Evaluates whatever is typed in the search box.
    func evaluateInput() {
        guard let symbol = symbolInput.symbolList.first else { return }
        symbolInput = ""
        select(symbol)
    }

    func select(_ symbol: String) {
        selectedSymbol = symbol
        if stocks[symbol] == nil {
            load(symbol)
        } else {
            errorMessage = nil
            remember(symbol)
        }
    }

    func reload() {
        guard let selectedSymbol else { return }
        load(selectedSymbol)
    }

    func removeRecent(_ symbol: String) {
        recentSymbols.removeAll { $0 == symbol }
        if selectedSymbol == symbol { selectedSymbol = nil }
    }

    func clearRecents() {
        recentSymbols = []
        selectedSymbol = nil
    }

    private func load(_ symbol: String) {
        loadTask?.cancel()
        errorMessage = nil
        loadingSymbol = symbol
        let client = client
        loadTask = Task {
            async let stockResult = Self.fetchStock(symbol, client: client)
            async let summaryResult = Self.fetchSummary(symbol, client: client)
            let (stock, summary) = await (stockResult, summaryResult)
            guard !Task.isCancelled else { return }

            switch stock {
            case .success(let snapshot):
                stocks[symbol] = snapshot
                remember(symbol)
            case .failure(let error):
                if selectedSymbol == symbol {
                    errorMessage = "Couldn't load \(symbol): \(error.localizedDescription)"
                }
            }
            switch summary {
            case .success(let data):
                summaries[symbol] = data
                summaryErrors[symbol] = nil
                if let name = data.name { stocks[symbol]?.name = name }
            case .failure(let error):
                summaryErrors[symbol] = error.localizedDescription
            }
            loadingSymbol = nil
        }
    }

    private func remember(_ symbol: String) {
        recentSymbols.removeAll { $0 == symbol }
        recentSymbols.insert(symbol, at: 0)
        if recentSymbols.count > 25 { recentSymbols.removeLast(recentSymbols.count - 25) }
    }

    nonisolated private static func fetchStock(_ symbol: String, client: YahooFinanceClient) async -> Result<StockSnapshot, Error> {
        do {
            return .success(try await client.snapshot(for: symbol))
        } catch {
            return .failure(error)
        }
    }

    nonisolated private static func fetchSummary(_ symbol: String, client: YahooFinanceClient) async -> Result<CompanySummary, Error> {
        do {
            return .success(try await client.summary(for: symbol))
        } catch {
            return .failure(error)
        }
    }

    private enum Keys {
        static let style = "investorStyle"
        static let recent = "recentSymbols"
    }
}
