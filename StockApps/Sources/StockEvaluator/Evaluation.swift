import Foundation
import StockCore

/// One area of the evaluation, scored 0–100.
enum ScoreCategory: String, CaseIterable, Identifiable, Codable {
    case valuation
    case growth
    case profitability
    case health
    case momentum
    case analysts
    case risk
    case income

    var id: String { rawValue }

    var title: String {
        switch self {
        case .valuation: "Valuation"
        case .growth: "Growth"
        case .profitability: "Profitability"
        case .health: "Financial Health"
        case .momentum: "Trend & Momentum"
        case .analysts: "Analyst View"
        case .risk: "Risk"
        case .income: "Dividend Income"
        }
    }

    var systemImage: String {
        switch self {
        case .valuation: "tag"
        case .growth: "chart.line.uptrend.xyaxis"
        case .profitability: "dollarsign.circle"
        case .health: "cross.case"
        case .momentum: "arrow.up.right"
        case .analysts: "person.3"
        case .risk: "exclamationmark.triangle"
        case .income: "banknote"
        }
    }

    var question: String {
        switch self {
        case .valuation: "Is the price reasonable for what you get?"
        case .growth: "Are sales and earnings growing?"
        case .profitability: "Does the business make good money?"
        case .health: "Can it pay its bills and debts?"
        case .momentum: "Is the stock in an uptrend?"
        case .analysts: "What do Wall Street analysts expect?"
        case .risk: "How bumpy is the ride? (Higher score = calmer)"
        case .income: "Does it pay a sustainable dividend?"
        }
    }
}

/// How much each category counts depends on what kind of investor you are.
enum InvestorStyle: String, CaseIterable, Identifiable, Codable {
    case balanced
    case value
    case growth
    case income
    case momentum

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: "Balanced"
        case .value: "Value"
        case .growth: "Growth"
        case .income: "Income"
        case .momentum: "Momentum"
        }
    }

    var summary: String {
        switch self {
        case .balanced: "Long-term investor weighing price, quality, growth and trend evenly."
        case .value: "Wants good companies at cheap prices and a margin of safety."
        case .growth: "Pays up for fast-growing sales and earnings."
        case .income: "Wants reliable dividends and a strong balance sheet."
        case .momentum: "Shorter-term; buys strength and follows the trend."
        }
    }

    func weight(_ category: ScoreCategory) -> Double {
        switch (self, category) {
        case (.balanced, .valuation): 20
        case (.balanced, .growth): 15
        case (.balanced, .profitability): 15
        case (.balanced, .health): 15
        case (.balanced, .momentum): 15
        case (.balanced, .analysts): 10
        case (.balanced, .risk): 10
        case (.balanced, .income): 0

        case (.value, .valuation): 35
        case (.value, .growth): 5
        case (.value, .profitability): 15
        case (.value, .health): 20
        case (.value, .momentum): 5
        case (.value, .analysts): 10
        case (.value, .risk): 10
        case (.value, .income): 0

        case (.growth, .valuation): 10
        case (.growth, .growth): 35
        case (.growth, .profitability): 15
        case (.growth, .health): 10
        case (.growth, .momentum): 15
        case (.growth, .analysts): 10
        case (.growth, .risk): 5
        case (.growth, .income): 0

        case (.income, .valuation): 15
        case (.income, .growth): 5
        case (.income, .profitability): 15
        case (.income, .health): 25
        case (.income, .momentum): 5
        case (.income, .analysts): 5
        case (.income, .risk): 10
        case (.income, .income): 20

        case (.momentum, .valuation): 5
        case (.momentum, .growth): 15
        case (.momentum, .profitability): 5
        case (.momentum, .health): 5
        case (.momentum, .momentum): 45
        case (.momentum, .analysts): 15
        case (.momentum, .risk): 10
        case (.momentum, .income): 0
        }
    }
}

/// A single measured item, such as "Forward P/E", and how it scored.
struct Factor: Identifiable {
    var id: String { name }
    let name: String
    let value: String
    /// 0 (bad) … 100 (good)
    let score: Double
    let weight: Double
    /// What good and bad look like for this measure.
    let guide: String
}

struct CategoryScore: Identifiable {
    var id: ScoreCategory { category }
    let category: ScoreCategory
    let factors: [Factor]

    /// Weighted average of the factor scores, or nil when there's no data.
    var score: Double? {
        let totalWeight = factors.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }
        return factors.reduce(0) { $0 + $1.score * $1.weight } / totalWeight
    }
}

enum Verdict: Int, Comparable {
    case insufficientData = -1
    case avoid = 0
    case watch = 1
    case buy = 2
    case strongBuy = 3

    static func < (lhs: Verdict, rhs: Verdict) -> Bool { lhs.rawValue < rhs.rawValue }

    init(score: Double) {
        switch score {
        case 72...: self = .strongBuy
        case 60..<72: self = .buy
        case 45..<60: self = .watch
        default: self = .avoid
        }
    }

    var title: String {
        switch self {
        case .strongBuy: "Strong Buy Candidate"
        case .buy: "Buy Candidate"
        case .watch: "Hold Off / Watch"
        case .avoid: "Avoid for Now"
        case .insufficientData: "Not Enough Data"
        }
    }

    var systemImage: String {
        switch self {
        case .strongBuy: "checkmark.seal.fill"
        case .buy: "hand.thumbsup.fill"
        case .watch: "eye.fill"
        case .avoid: "xmark.octagon.fill"
        case .insufficientData: "questionmark.circle.fill"
        }
    }

    var explanation: String {
        switch self {
        case .strongBuy: "Scores well across most areas for your style. Still do your own research and size the position sensibly."
        case .buy: "More positives than negatives. Worth buying if the concerns below don't bother you."
        case .watch: "A mixed picture. Consider waiting for a better price, a stronger trend or better results."
        case .avoid: "Too many weak spots right now for your style."
        case .insufficientData: "Yahoo Finance didn't return enough data to judge this one."
        }
    }

    /// One level lower, used when there are several red flags.
    var downgraded: Verdict {
        switch self {
        case .strongBuy: .buy
        case .buy: .watch
        case .watch, .avoid: .avoid
        case .insufficientData: .insufficientData
        }
    }
}

struct FairValueEstimate: Identifiable {
    var id: String { method }
    let method: String
    let value: Double
    let note: String
}

struct Evaluation {
    let style: InvestorStyle
    let price: Double
    let categories: [CategoryScore]
    /// 0–100, nil when there's no data at all.
    let overall: Double?
    let verdict: Verdict
    /// True when red flags pulled the verdict down a level.
    let downgradedForRedFlags: Bool
    /// Share (0–1) of this style's category weight that had data.
    let coverage: Double
    let redFlags: [String]
    let strengths: [String]
    let fairValues: [FairValueEstimate]

    /// Median of the fair value estimates.
    var fairValue: Double? {
        let values = fairValues.map(\.value).sorted()
        guard !values.isEmpty else { return nil }
        let mid = values.count / 2
        return values.count.isMultiple(of: 2) ? (values[mid - 1] + values[mid]) / 2 : values[mid]
    }

    var upsideToFairValue: Double? {
        fairValue.map { ($0 / price - 1) * 100 }
    }

    func score(for category: ScoreCategory) -> Double? {
        categories.first { $0.category == category }?.score
    }
}

// MARK: - Engine

enum Evaluator {
    static func evaluate(stock: StockSnapshot, summary: CompanySummary?, style: InvestorStyle) -> Evaluation {
        let s = summary ?? CompanySummary()
        let price = stock.price

        let categories: [CategoryScore] = [
            CategoryScore(category: .valuation, factors: valuationFactors(s, price: price)),
            CategoryScore(category: .growth, factors: growthFactors(s)),
            CategoryScore(category: .profitability, factors: profitabilityFactors(s)),
            CategoryScore(category: .health, factors: healthFactors(s)),
            CategoryScore(category: .momentum, factors: momentumFactors(stock)),
            CategoryScore(category: .analysts, factors: analystFactors(s, price: price)),
            CategoryScore(category: .risk, factors: riskFactors(stock, s)),
            CategoryScore(category: .income, factors: incomeFactors(s)),
        ]

        var weighted = 0.0
        var usedWeight = 0.0
        var totalWeight = 0.0
        for category in categories {
            let weight = style.weight(category.category)
            totalWeight += weight
            if let score = category.score, weight > 0 {
                weighted += score * weight
                usedWeight += weight
            }
        }
        let overall = usedWeight > 0 ? weighted / usedWeight : nil
        let coverage = totalWeight > 0 ? usedWeight / totalWeight : 0

        let flags = redFlags(stock: stock, summary: s)
        var verdict: Verdict = .insufficientData
        var downgraded = false
        if let overall, coverage >= 0.4 {
            verdict = Verdict(score: overall)
            if flags.count >= 3 && verdict > .avoid {
                verdict = verdict.downgraded
                downgraded = true
            }
        }

        return Evaluation(
            style: style,
            price: price,
            categories: categories,
            overall: overall,
            verdict: verdict,
            downgradedForRedFlags: downgraded,
            coverage: coverage,
            redFlags: flags,
            strengths: strengths(categories, style: style),
            fairValues: fairValues(s)
        )
    }

    /// Maps `value` linearly so `bad` scores 0 and `good` scores 100 (works in either direction).
    static func scale(_ value: Double, bad: Double, good: Double) -> Double {
        guard bad != good else { return 50 }
        let t = (value - bad) / (good - bad)
        return min(max(t, 0), 1) * 100
    }

    private static func factor(_ name: String, _ value: Double?, display: (Double) -> String,
                               bad: Double, good: Double, weight: Double = 1, guide: String) -> Factor? {
        guard let value, value.isFinite else { return nil }
        return Factor(name: name, value: display(value), score: scale(value, bad: bad, good: good), weight: weight, guide: guide)
    }

    private static func ratio(_ v: Double) -> String { Format.number(v, digits: 1) + "×" }
    private static func pct(_ v: Double) -> String { Format.fraction(v, signed: true) }
    private static func pctPlain(_ v: Double) -> String { Format.fraction(v) }

    // MARK: Categories

    static func valuationFactors(_ s: CompanySummary, price: Double) -> [Factor] {
        var factors: [Factor] = []
        if let eps = s.trailingEps, eps <= 0 {
            factors.append(Factor(name: "P/E (trailing)", value: "Losing money", score: 10, weight: 1,
                                  guide: "No earnings over the last 12 months, so the price isn't backed by profits yet."))
        } else {
            factors += [factor("P/E (trailing)", s.trailingPE, display: ratio, bad: 45, good: 12,
                               guide: "Price ÷ last year's earnings. Under ~15 is cheap, over ~40 is expensive.")].compactMap { $0 }
        }
        factors += [
            factor("P/E (forward)", s.forwardPE.flatMap { $0 > 0 ? $0 : nil }, display: ratio, bad: 40, good: 12,
                   guide: "Price ÷ next year's expected earnings. Under ~15 is cheap, over ~35 is expensive."),
            factor("PEG ratio", s.pegRatio.flatMap { $0 > 0 ? $0 : nil }, display: ratio, bad: 3, good: 1,
                   guide: "P/E divided by growth rate. Around 1 or below means you're not overpaying for growth."),
            factor("EV / EBITDA", s.enterpriseToEbitda.flatMap { $0 > 0 ? $0 : nil }, display: ratio, bad: 30, good: 8,
                   guide: "Whole-company value vs operating earnings, including debt. Under ~10 is cheap, over ~25 is rich."),
            factor("Price / Sales", s.priceToSales, display: ratio, bad: 15, good: 2, weight: 0.5,
                   guide: "Price vs revenue. Useful for unprofitable firms. Under ~2 is cheap, over ~10 is expensive."),
            factor("Price / Book", s.priceToBook.flatMap { $0 > 0 ? $0 : nil }, display: ratio, bad: 10, good: 1.5, weight: 0.5,
                   guide: "Price vs net assets. Matters most for banks and industrials; tech is usually high."),
        ].compactMap { $0 }
        return factors
    }

    static func growthFactors(_ s: CompanySummary) -> [Factor] {
        var epsGrowth: Double?
        if let trailing = s.trailingEps, let forward = s.forwardEps, trailing > 0 {
            epsGrowth = forward / trailing - 1
        }
        return [
            factor("Revenue growth (YoY)", s.revenueGrowth, display: pct, bad: -0.05, good: 0.20,
                   guide: "Latest quarter vs a year ago. Above 10% is solid, above 20% is fast, below 0 is shrinking."),
            factor("Earnings growth (YoY)", s.earningsGrowth, display: pct, bad: -0.10, good: 0.25,
                   guide: "Latest quarter's earnings vs a year ago. Above 15% is strong."),
            factor("Expected EPS growth", epsGrowth, display: pct, bad: -0.05, good: 0.20,
                   guide: "Next year's expected earnings per share vs the last 12 months."),
        ].compactMap { $0 }
    }

    static func profitabilityFactors(_ s: CompanySummary) -> [Factor] {
        [
            factor("Net profit margin", s.profitMargins, display: pctPlain, bad: 0, good: 0.20,
                   guide: "Profit kept from each dollar of sales. Above 15% is strong; negative means losses."),
            factor("Operating margin", s.operatingMargins, display: pctPlain, bad: 0, good: 0.25,
                   guide: "Profit from core operations. Above 20% suggests pricing power."),
            factor("Return on equity", s.returnOnEquity, display: pctPlain, bad: 0, good: 0.20,
                   guide: "Profit made on shareholders' money. Above 15% is good. Very high values can come from heavy debt or buybacks."),
            factor("Gross margin", s.grossMargins, display: pctPlain, bad: 0.15, good: 0.60, weight: 0.5,
                   guide: "Sales minus direct costs. High gross margins (50%+) are typical of strong brands and software."),
        ].compactMap { $0 }
    }

    static func healthFactors(_ s: CompanySummary) -> [Factor] {
        var factors: [Factor] = []
        if let de = s.debtToEquity {
            factors += [factor("Debt / Equity", de, display: ratio, bad: 2.5, good: 0.3,
                               guide: "Debt compared to shareholders' equity. Under 0.5 is conservative, over 2 is heavy.")].compactMap { $0 }
        } else if s.totalDebt == 0 {
            factors.append(Factor(name: "Debt / Equity", value: "No debt", score: 100, weight: 1,
                                  guide: "The company has no debt."))
        }
        factors += [factor("Current ratio", s.currentRatio, display: ratio, bad: 0.8, good: 2.0,
                           guide: "Short-term assets ÷ short-term bills. Above 1.5 is comfortable, below 1 can be tight.")].compactMap { $0 }
        if let fcf = s.freeCashflow, let cap = s.marketCap, cap > 0 {
            factors += [factor("Free cash flow yield", fcf / cap, display: pctPlain, bad: -0.02, good: 0.06,
                               guide: "Cash left after investment, as a % of market value. Above 5% is attractive; negative means burning cash.")].compactMap { $0 }
        }
        if let cash = s.totalCash, let debt = s.totalDebt, let cap = s.marketCap, cap > 0 {
            factors += [factor("Net cash / market cap", (cash - debt) / cap, display: pct, bad: -0.3, good: 0.1, weight: 0.5,
                               guide: "Cash minus debt, as a % of market value. Positive means more cash than debt.")].compactMap { $0 }
        }
        return factors
    }

    static func momentumFactors(_ stock: StockSnapshot) -> [Factor] {
        var factors: [Factor] = [
            factor("Vs 200-day average", stock.aboveSMA200Pct, display: { Format.percent($0) }, bad: -15, good: 10,
                   guide: "Above the 200-day moving average is the classic sign of a long-term uptrend."),
            factor("1-year return", stock.change1Y, display: { Format.percent($0) }, bad: -20, good: 30,
                   guide: "Stocks that have been strong for a year tend to stay strong for a while."),
            factor("3-month return", stock.change3M, display: { Format.percent($0) }, bad: -10, good: 15, weight: 0.75,
                   guide: "Recent strength or weakness."),
            factor("From 52-week high", stock.fromHigh52, display: { Format.percent($0) }, bad: -35, good: -3, weight: 0.5,
                   guide: "Leaders tend to trade near their highs. Far below the high often means a downtrend."),
        ].compactMap { $0 }
        if let s50 = stock.sma50, let s200 = stock.sma200 {
            let golden = s50 > s200
            factors.append(Factor(name: "50-day vs 200-day", value: golden ? "Golden cross" : "Death cross",
                                  score: golden ? 85 : 20, weight: 0.75,
                                  guide: "50-day average above the 200-day (golden cross) signals an uptrend; below it (death cross) a downtrend."))
        }
        if let rsi = stock.rsi14 {
            let score: Double = switch rsi {
            case ..<30: 55
            case 30..<45: 65
            case 45..<65: 85
            case 65..<75: 60
            default: 30
            }
            factors.append(Factor(name: "RSI (14)", value: Format.number(rsi, digits: 0), score: score, weight: 0.5,
                                  guide: "45–65 is healthy. Above 75 is overbought (often a poor entry); below 30 is oversold."))
        }
        return factors
    }

    static func analystFactors(_ s: CompanySummary, price: Double) -> [Factor] {
        let analysts = s.analystCount ?? 0
        guard analysts > 0 else { return [] }
        let weight = analysts >= 5 ? 1.0 : 0.5
        let key = s.recommendationKey.map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
        return [
            factor("Consensus rating", s.recommendationMean, display: { Format.number($0, digits: 1) + (key.map { " (\($0))" } ?? "") },
                   bad: 3.5, good: 1.5, weight: weight,
                   guide: "Average of \(Int(analysts)) analysts: 1 = Strong Buy, 3 = Hold, 5 = Sell."),
            factor("Upside to price target", s.targetMeanPrice.map { $0 / price - 1 }, display: pct, bad: -0.05, good: 0.25, weight: weight,
                   guide: "Average 12-month analyst target vs today's price."),
        ].compactMap { $0 }
    }

    static func riskFactors(_ stock: StockSnapshot, _ s: CompanySummary) -> [Factor] {
        [
            factor("Volatility (1Y)", stock.volatility, display: { Format.percent($0, signed: false) }, bad: 60, good: 15,
                   guide: "How much the price swings in a year. Under 20% is calm, over 50% is wild."),
            factor("Max drawdown (1Y)", stock.maxDrawdown, display: { Format.percent($0) }, bad: -50, good: -10,
                   guide: "Biggest fall from a peak in the past year. Shows what holding it can feel like."),
            factor("Beta", s.beta, display: { Format.number($0, digits: 2) }, bad: 2.0, good: 0.8, weight: 0.75,
                   guide: "Sensitivity to the overall market. 1 moves with the market; 2 moves twice as much."),
            factor("Short interest", s.shortPercentOfFloat, display: pctPlain, bad: 0.20, good: 0.02, weight: 0.5,
                   guide: "Share of tradable stock sold short. Above 10% means many investors are betting against it."),
        ].compactMap { $0 }
    }

    static func incomeFactors(_ s: CompanySummary) -> [Factor] {
        // Yahoo often omits the yield for profitable companies that pay no dividend.
        guard let dividendYield = s.dividendYield ?? (s.trailingPE != nil ? 0 : nil) else { return [] }
        var factors = [factor("Dividend yield", dividendYield, display: pctPlain, bad: 0, good: 0.04,
                              guide: "Annual dividend as a % of price. 2–5% is typical for income stocks.")].compactMap { $0 }
        if dividendYield > 0, let payout = s.payoutRatio, payout > 0 {
            let score: Double = switch payout {
            case ..<0.2: 70
            case 0.2..<0.65: 90
            case 0.65..<0.9: 55
            default: 15
            }
            factors.append(Factor(name: "Payout ratio", value: pctPlain(payout), score: score, weight: 1,
                                  guide: "Share of earnings paid out. 20–65% is sustainable; above 90% risks a dividend cut."))
        }
        return factors
    }

    // MARK: Flags and highlights

    static func redFlags(stock: StockSnapshot, summary s: CompanySummary) -> [String] {
        var flags: [String] = []
        if let eps = s.trailingEps, eps <= 0 {
            flags.append("Not profitable over the last 12 months.")
        }
        if let fcf = s.freeCashflow, fcf < 0 {
            flags.append("Negative free cash flow: the business is burning cash.")
        }
        if let de = s.debtToEquity, de > 2.5 {
            flags.append("Heavy debt: \(Format.number(de, digits: 1))× equity.")
        }
        if let current = s.currentRatio, current < 1 {
            flags.append("Short-term bills exceed short-term assets (current ratio \(Format.number(current, digits: 2))).")
        }
        if let growth = s.revenueGrowth, growth < -0.05 {
            flags.append("Revenue is shrinking (\(Format.fraction(growth, signed: true)) year over year).")
        }
        if let pe = s.trailingPE, pe > 60 {
            flags.append("Very high P/E of \(Format.number(pe, digits: 0)): a lot of future growth is already priced in.")
        }
        if let s50 = stock.sma50, let s200 = stock.sma200, stock.price < s200, s50 < s200 {
            flags.append("In a downtrend: below the 200-day average with a death cross.")
        }
        if let rsi = stock.rsi14, rsi > 78 {
            flags.append("Overbought (RSI \(Format.number(rsi, digits: 0))): buying right after a sharp run-up raises short-term risk.")
        }
        if let target = s.targetMeanPrice, (s.analystCount ?? 0) >= 3, target < stock.price {
            flags.append("Trading above the average analyst target of \(Format.price(target)).")
        }
        if let vol = stock.volatility, vol > 60 {
            flags.append("Very volatile: \(Format.percent(vol, signed: false)) annualized swings.")
        }
        if let payout = s.payoutRatio, (s.dividendYield ?? 0) > 0, payout > 1 {
            flags.append("Pays out more in dividends than it earns (\(Format.fraction(payout)) payout).")
        }
        return flags
    }

    static func strengths(_ categories: [CategoryScore], style: InvestorStyle) -> [String] {
        categories
            .filter { style.weight($0.category) > 0 }
            .flatMap { category in category.factors.map { (category: category.category, factor: $0) } }
            .filter { $0.factor.score >= 85 }
            .sorted { $0.factor.score * $0.factor.weight > $1.factor.score * $1.factor.weight }
            .prefix(6)
            .map { "\($0.factor.name): \($0.factor.value)" }
    }

    static func fairValues(_ s: CompanySummary) -> [FairValueEstimate] {
        var estimates: [FairValueEstimate] = []

        if let target = s.targetMeanPrice, let count = s.analystCount, count > 0 {
            var note = "Average 12-month target of \(Int(count)) analysts"
            if let low = s.targetLowPrice, let high = s.targetHighPrice {
                note += " (range \(Format.price(low))–\(Format.price(high)))"
            }
            estimates.append(FairValueEstimate(method: "Analyst target", value: target, note: note + "."))
        }

        let eps = s.forwardEps.flatMap { $0 > 0 ? $0 : nil } ?? s.trailingEps.flatMap { $0 > 0 ? $0 : nil }
        if let eps {
            // Benjamin Graham's growth formula: value = EPS × (8.5 + 2g), g = expected growth in percent.
            var growth = 5.0
            if let earningsGrowth = s.earningsGrowth {
                growth = earningsGrowth * 100
            } else if let forward = s.forwardEps, let trailing = s.trailingEps, trailing > 0 {
                growth = (forward / trailing - 1) * 100
            }
            growth = min(max(growth, 0), 15)
            let multiple = 8.5 + 2 * growth
            estimates.append(FairValueEstimate(
                method: "Earnings power",
                value: eps * multiple,
                note: "EPS \(Format.price(eps)) × \(Format.number(multiple, digits: 1)) P/E (Graham's 8.5 + 2 × growth, growth capped at 15%)."
            ))
        }

        if let trailing = s.trailingEps, let book = s.bookValuePerShare, trailing > 0, book > 0 {
            estimates.append(FairValueEstimate(
                method: "Graham number",
                value: (22.5 * trailing * book).squareRoot(),
                note: "√(22.5 × EPS × book value per share). A strict value test; growth companies rarely pass it."
            ))
        }
        return estimates
    }
}
