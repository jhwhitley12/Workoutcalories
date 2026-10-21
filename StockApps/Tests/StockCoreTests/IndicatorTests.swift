import XCTest
@testable import StockCore

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

    func testMaxDrawdown() {
        XCTAssertEqual(Indicators.maxDrawdown([100, 120, 90, 130, 117])!, -25, accuracy: 1e-9)
        XCTAssertEqual(Indicators.maxDrawdown([1, 2, 3]), 0)
    }

    func testAverageExcludesLastValue() {
        XCTAssertEqual(Indicators.averageExcludingLast([10, 20, 30, 1000], period: 3), 20)
    }
}
