import XCTest
@testable import StockCore
@testable import StockScreener

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
