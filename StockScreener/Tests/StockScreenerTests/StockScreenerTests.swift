import XCTest
@testable import StockScreener

final class IndicatorTests: XCTestCase {
    func testSMA() {
        XCTAssertEqual(Indicators.sma([1, 2, 3, 4, 5], period: 2), 4.5)
        XCTAssertNil(Indicators.sma([1, 2], period: 3))
    }

    func testSMASeries() {
        let series = Indicators.smaSeries([1, 2, 3, 4], period: 2)
        XCTAssertNil(series[0])
        XCTAssertEqual(series[1], 1.5)
        XCTAssertEqual(series[3], 3.5)
    }

    func testRSIExtremes() {
        let rising = (1...30).map(Double.init)
        XCTAssertEqual(Indicators.rsi(rising), 100)
        XCTAssertEqual(Indicators.rsi(Array(rising.reversed()))!, 0, accuracy: 0.0001)
        XCTAssertEqual(Indicators.rsi([Double](repeating: 10, count: 30)), 50)
        XCTAssertNil(Indicators.rsi([1, 2, 3]))
    }

    func testRSIKnownValue() {
        // Alternating +2 / -1 moves: average gain ≈ 1, average loss ≈ 0.5 → RS ≈ 2 → RSI ≈ 66.7
        var closes = [100.0]
        for i in 0..<60 { closes.append(closes.last! + (i.isMultiple(of: 2) ? 2 : -1)) }
        XCTAssertEqual(Indicators.rsi(closes)!, 66.67, accuracy: 3)
    }

    func testPercentChange() {
        XCTAssertEqual(Indicators.percentChange([100, 110], current: 110, lookback: 1)!, 10, accuracy: 1e-9)
        XCTAssertNil(Indicators.percentChange([100], current: 110, lookback: 1))
    }

    func testVolatilityOfFlatSeriesIsZero() {
        XCTAssertEqual(Indicators.annualizedVolatility([Double](repeating: 50, count: 100))!, 0, accuracy: 1e-9)
    }

    func testAverageExcludesLastValue() {
        XCTAssertEqual(Indicators.averageExcludingLast([10, 20, 30, 1000], period: 3), 20)
    }
}

final class ScreenTests: XCTestCase {
    private func makeStock(closes: [Double]) -> StockSnapshot {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let bars = closes.enumerated().map { i, close in
            PriceBar(date: start.addingTimeInterval(Double(i) * 86_400),
                     open: close, high: close, low: close, close: close, volume: 1_000)
        }
        return StockSnapshot(symbol: "TEST", name: "Test", currency: "USD", exchange: "",
                             price: nil, high52: nil, low52: nil, bars: bars)
    }

    func testUptrendPassesTrendChecks() {
        let stock = makeStock(closes: (1...260).map(Double.init))
        XCTAssertTrue(TrendCheck.aboveSMA50.matches(stock))
        XCTAssertTrue(TrendCheck.aboveSMA200.matches(stock))
        XCTAssertTrue(TrendCheck.goldenCross.matches(stock))
        XCTAssertFalse(TrendCheck.belowSMA200.matches(stock))
        XCTAssertEqual(stock.fromHigh52!, 0, accuracy: 1e-9)
    }

    func testRangeFilters() {
        let stock = makeStock(closes: (1...260).map(Double.init))
        var criteria = ScreenCriteria()
        criteria[.price] = RangeFilter(enabled: true, min: 100, max: 300)
        XCTAssertTrue(criteria.matches(stock))
        criteria[.price] = RangeFilter(enabled: true, min: 300, max: nil)
        XCTAssertFalse(criteria.matches(stock))
        // Missing data never matches an enabled filter.
        criteria = ScreenCriteria()
        criteria[.pe] = RangeFilter(enabled: true, min: nil, max: 20)
        XCTAssertFalse(criteria.matches(stock))
    }

    func testCriteriaRoundTripsThroughJSON() throws {
        let criteria = ScreenCriteria.presets[0].criteria
        let data = try JSONEncoder().encode(criteria)
        XCTAssertEqual(try JSONDecoder().decode(ScreenCriteria.self, from: data), criteria)
    }

    func testSymbolList() {
        XCTAssertEqual("aapl, msft  nvda;AAPL\nbrk-b".symbolList, ["AAPL", "MSFT", "NVDA", "BRK-B"])
    }

    func testBuiltInUniverses() {
        for universe in Universe.allCases where universe != .custom {
            XCTAssertFalse(universe.builtInSymbols.isEmpty, universe.title)
        }
        XCTAssertEqual(Universe.dow30.builtInSymbols.count, 30)
    }
}
