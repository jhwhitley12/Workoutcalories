import XCTest
@testable import StockCore
@testable import StockEvaluator

final class EvaluatorTests: XCTestCase {
    // Gentle uptrend with daily wiggles: above both averages, RSI ~64, volatility ~17%.
    private let uptrend: [Double] = (0..<260).map { (i: Int) -> Double in
        let x = Double(i)
        return 100 + 0.2 * x + 2 * sin(x)
    }
    // Steady decline: below both averages with a death cross.
    private let downtrend: [Double] = (0..<260).map { (i: Int) -> Double in
        let x = Double(i)
        return 200 - 0.4 * x + 2 * sin(x)
    }

    private func makeStock(_ closes: [Double]) -> StockSnapshot {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let bars: [PriceBar] = closes.enumerated().map { (i: Int, close: Double) -> PriceBar in
            PriceBar(date: start.addingTimeInterval(Double(i) * 86_400),
                     open: close, high: close, low: close, close: close, volume: 1_000_000)
        }
        return StockSnapshot(symbol: "TEST", name: "Test Co", currency: "USD", exchange: "",
                             price: nil, high52: nil, low52: nil, bars: bars)
    }

    private func strongCompany(price: Double) -> CompanySummary {
        var s = CompanySummary()
        s.trailingPE = 14
        s.forwardPE = 12
        s.pegRatio = 1
        s.enterpriseToEbitda = 9
        s.priceToSales = 2
        s.priceToBook = 2
        s.trailingEps = 5
        s.forwardEps = 5.8
        s.bookValuePerShare = 25
        s.revenueGrowth = 0.18
        s.earningsGrowth = 0.20
        s.profitMargins = 0.20
        s.operatingMargins = 0.25
        s.returnOnEquity = 0.22
        s.grossMargins = 0.55
        s.debtToEquity = 0.3
        s.currentRatio = 2
        s.marketCap = 100e9
        s.freeCashflow = 6e9
        s.totalCash = 20e9
        s.totalDebt = 10e9
        s.beta = 0.9
        s.shortPercentOfFloat = 0.02
        s.targetMeanPrice = price * 1.25
        s.recommendationMean = 1.8
        s.analystCount = 20
        return s
    }

    private func weakCompany(price: Double) -> CompanySummary {
        var s = CompanySummary()
        s.trailingEps = -1
        s.forwardEps = -0.5
        s.priceToSales = 12
        s.revenueGrowth = -0.10
        s.earningsGrowth = -0.30
        s.profitMargins = -0.15
        s.operatingMargins = -0.10
        s.returnOnEquity = -0.20
        s.grossMargins = 0.20
        s.debtToEquity = 3
        s.currentRatio = 0.8
        s.marketCap = 5e9
        s.freeCashflow = -1e9
        s.totalCash = 1e8
        s.totalDebt = 3e9
        s.beta = 2.2
        s.shortPercentOfFloat = 0.25
        s.targetMeanPrice = price * 0.8
        s.recommendationMean = 3.6
        s.analystCount = 8
        return s
    }

    func testScale() {
        XCTAssertEqual(Evaluator.scale(12, bad: 45, good: 12), 100)
        XCTAssertEqual(Evaluator.scale(45, bad: 45, good: 12), 0)
        XCTAssertEqual(Evaluator.scale(0.1, bad: 0, good: 0.2), 50, accuracy: 1e-9)
        XCTAssertEqual(Evaluator.scale(100, bad: 0, good: 1), 100)
        XCTAssertEqual(Evaluator.scale(-5, bad: 0, good: 1), 0)
    }

    func testStyleWeightsAddUpTo100() {
        for style in InvestorStyle.allCases {
            let total = ScoreCategory.allCases.reduce(0) { $0 + style.weight($1) }
            XCTAssertEqual(total, 100, style.title)
        }
    }

    func testStrongCompanyIsABuyCandidate() {
        let stock = makeStock(uptrend)
        let evaluation = Evaluator.evaluate(stock: stock, summary: strongCompany(price: stock.price), style: .balanced)
        XCTAssertGreaterThanOrEqual(evaluation.verdict, Verdict.buy)
        XCTAssertGreaterThan(evaluation.overall!, 65)
        XCTAssertTrue(evaluation.redFlags.isEmpty, "\(evaluation.redFlags)")
        XCTAssertFalse(evaluation.strengths.isEmpty)
        XCTAssertEqual(evaluation.coverage, 1, accuracy: 1e-9)
    }

    func testWeakCompanyIsAvoided() {
        let stock = makeStock(downtrend)
        let evaluation = Evaluator.evaluate(stock: stock, summary: weakCompany(price: stock.price), style: .balanced)
        XCTAssertEqual(evaluation.verdict, Verdict.avoid)
        XCTAssertLessThan(evaluation.overall!, 40)
        XCTAssertGreaterThanOrEqual(evaluation.redFlags.count, 3)
    }

    func testPriceOnlyDataIsInsufficientForBalancedButNotMomentum() {
        let stock = makeStock(uptrend)
        let balanced = Evaluator.evaluate(stock: stock, summary: nil, style: .balanced)
        XCTAssertEqual(balanced.verdict, Verdict.insufficientData)
        XCTAssertEqual(balanced.coverage, 0.25, accuracy: 1e-9)

        let momentum = Evaluator.evaluate(stock: stock, summary: nil, style: .momentum)
        XCTAssertNotEqual(momentum.verdict, Verdict.insufficientData)
    }

    func testRedFlagsDowngradeVerdict() {
        // Great trend and analysts, but losing money with heavy debt and burning cash.
        let stock = makeStock(uptrend)
        var s = strongCompany(price: stock.price)
        s.trailingEps = -0.5
        s.trailingPE = nil
        s.freeCashflow = -2e9
        s.debtToEquity = 3
        let evaluation = Evaluator.evaluate(stock: stock, summary: s, style: .momentum)
        XCTAssertGreaterThanOrEqual(evaluation.redFlags.count, 3)
        XCTAssertTrue(evaluation.downgradedForRedFlags)
        XCTAssertEqual(evaluation.verdict, Verdict(score: evaluation.overall!).downgraded)
    }

    func testFairValues() {
        var s = CompanySummary()
        s.trailingEps = 5
        s.forwardEps = 5.5
        s.bookValuePerShare = 20
        s.earningsGrowth = 0.10
        s.targetMeanPrice = 120
        s.analystCount = 10
        let estimates = Evaluator.fairValues(s)
        XCTAssertEqual(estimates.first { $0.method == "Graham number" }!.value, (22.5 * 5 * 20).squareRoot(), accuracy: 1e-9)
        // 8.5 + 2 × 10% growth = 28.5× forward EPS
        XCTAssertEqual(estimates.first { $0.method == "Earnings power" }!.value, 5.5 * 28.5, accuracy: 1e-9)
        XCTAssertEqual(estimates.first { $0.method == "Analyst target" }!.value, 120)
    }

    func testCategoryScoreIsWeightedAverage() {
        let category = CategoryScore(category: .valuation, factors: [
            Factor(name: "A", value: "", score: 100, weight: 1, guide: ""),
            Factor(name: "B", value: "", score: 0, weight: 3, guide: ""),
        ])
        XCTAssertEqual(category.score!, 25, accuracy: 1e-9)
        XCTAssertNil(CategoryScore(category: .growth, factors: []).score)
    }
}
