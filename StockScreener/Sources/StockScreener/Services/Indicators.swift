import Foundation

/// Technical indicators computed from a series of daily closes (oldest first).
enum Indicators {
    /// Simple moving average of the last `period` values.
    static func sma(_ values: [Double], period: Int) -> Double? {
        guard period > 0, values.count >= period else { return nil }
        return values.suffix(period).reduce(0, +) / Double(period)
    }

    /// SMA at every index (nil until enough values exist). Used for the chart overlay.
    static func smaSeries(_ values: [Double], period: Int) -> [Double?] {
        guard period > 0 else { return values.map { _ in nil } }
        var result = [Double?](repeating: nil, count: values.count)
        var sum = 0.0
        for i in values.indices {
            sum += values[i]
            if i >= period { sum -= values[i - period] }
            if i >= period - 1 { result[i] = sum / Double(period) }
        }
        return result
    }

    /// Wilder's Relative Strength Index.
    static func rsi(_ closes: [Double], period: Int = 14) -> Double? {
        guard period > 0, closes.count > period else { return nil }
        let p = Double(period)
        var avgGain = 0.0
        var avgLoss = 0.0
        for i in 1...period {
            let change = closes[i] - closes[i - 1]
            if change > 0 { avgGain += change } else { avgLoss -= change }
        }
        avgGain /= p
        avgLoss /= p
        if closes.count > period + 1 {
            for i in (period + 1)..<closes.count {
                let change = closes[i] - closes[i - 1]
                avgGain = (avgGain * (p - 1) + max(change, 0)) / p
                avgLoss = (avgLoss * (p - 1) + max(-change, 0)) / p
            }
        }
        if avgLoss == 0 { return avgGain == 0 ? 50 : 100 }
        let rs = avgGain / avgLoss
        return 100 - 100 / (1 + rs)
    }

    /// Percent change from the close `lookback` bars before the last bar to `current`.
    static func percentChange(_ closes: [Double], current: Double, lookback: Int) -> Double? {
        guard lookback > 0, closes.count > lookback else { return nil }
        let base = closes[closes.count - 1 - lookback]
        guard base > 0 else { return nil }
        return (current / base - 1) * 100
    }

    /// Annualized standard deviation of daily log returns, in percent.
    static func annualizedVolatility(_ closes: [Double], days: Int = 252) -> Double? {
        let window = Array(closes.suffix(days + 1))
        guard window.count >= 21 else { return nil }
        var returns: [Double] = []
        for i in 1..<window.count where window[i - 1] > 0 && window[i] > 0 {
            returns.append(log(window[i] / window[i - 1]))
        }
        guard returns.count >= 20 else { return nil }
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(returns.count - 1)
        return variance.squareRoot() * Double(252).squareRoot() * 100
    }

    /// Average of the `period` values before the last one (so today's partial volume isn't included).
    static func averageExcludingLast(_ values: [Double], period: Int) -> Double? {
        guard values.count > period else { return nil }
        let window = values.dropLast().suffix(period)
        return window.reduce(0, +) / Double(window.count)
    }
}
