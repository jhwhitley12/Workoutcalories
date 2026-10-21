import Foundation

/// Company profile, financial ratios and analyst data from Yahoo's quoteSummary endpoint.
/// Every field is optional: Yahoo leaves many out, especially for ETFs and small companies.
/// Ratios such as margins, growth and yields are fractions (0.12 means 12%).
public struct CompanySummary {
    // Profile
    public var name: String?
    public var quoteType: String?
    public var sector: String?
    public var industry: String?
    public var country: String?
    public var website: String?
    public var businessSummary: String?
    public var employees: Double?

    // Valuation
    public var marketCap: Double?
    public var trailingPE: Double?
    public var forwardPE: Double?
    public var pegRatio: Double?
    public var priceToBook: Double?
    public var priceToSales: Double?
    public var enterpriseToEbitda: Double?
    public var trailingEps: Double?
    public var forwardEps: Double?
    public var bookValuePerShare: Double?

    // Growth and profitability
    public var revenueGrowth: Double?
    public var earningsGrowth: Double?
    public var grossMargins: Double?
    public var operatingMargins: Double?
    public var profitMargins: Double?
    public var returnOnEquity: Double?
    public var returnOnAssets: Double?

    // Balance sheet and cash flow
    public var totalCash: Double?
    public var totalDebt: Double?
    /// Debt divided by equity, as a ratio (1.5 means debt is 1.5× equity).
    public var debtToEquity: Double?
    public var currentRatio: Double?
    public var freeCashflow: Double?
    public var operatingCashflow: Double?
    public var totalRevenue: Double?

    // Income and risk
    public var dividendYield: Double?
    public var payoutRatio: Double?
    public var beta: Double?
    public var shortPercentOfFloat: Double?

    // Analysts
    public var targetMeanPrice: Double?
    public var targetHighPrice: Double?
    public var targetLowPrice: Double?
    /// 1 = Strong Buy … 5 = Sell.
    public var recommendationMean: Double?
    public var recommendationKey: String?
    public var analystCount: Double?

    public init() {}

    public var isFund: Bool {
        guard let quoteType else { return false }
        return ["ETF", "MUTUALFUND", "INDEX"].contains(quoteType.uppercased())
    }
}
