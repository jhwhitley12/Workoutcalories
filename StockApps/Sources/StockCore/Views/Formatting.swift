import SwiftUI

public enum Format {
    public static func price(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    public static func percent(_ value: Double?, signed: Bool = true) -> String {
        guard let value else { return "—" }
        let text = value.formatted(.number.precision(.fractionLength(1)))
        return (signed && value > 0 ? "+" : "") + text + "%"
    }

    /// Formats a fraction (0.123) as a percentage (12.3%).
    public static func fraction(_ value: Double?, signed: Bool = false) -> String {
        percent(value.map { $0 * 100 }, signed: signed)
    }

    public static func number(_ value: Double?, digits: Int = 1) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(digits)))
    }

    /// 2.31T, 512.4B, 830.0M
    public static func compact(_ value: Double?) -> String {
        guard let value else { return "—" }
        let units: [(Double, String)] = [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]
        for (size, suffix) in units where abs(value) >= size {
            return (value / size).formatted(.number.precision(.fractionLength(1))) + suffix
        }
        return value.formatted(.number.precision(.fractionLength(0)))
    }
}

/// A percentage colored green when positive and red when negative.
public struct ChangeText: View {
    public let value: Double?

    public init(value: Double?) {
        self.value = value
    }

    public var body: some View {
        Text(Format.percent(value))
            .monospacedDigit()
            .foregroundStyle(color)
    }

    private var color: Color {
        guard let value else { return .secondary }
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .primary
    }
}

/// RSI tinted at the usual oversold (30) and overbought (70) levels.
public struct RSIText: View {
    public let value: Double?

    public init(value: Double?) {
        self.value = value
    }

    public var body: some View {
        Text(Format.number(value, digits: 0))
            .monospacedDigit()
            .foregroundStyle(color)
    }

    private var color: Color {
        guard let value else { return .secondary }
        if value <= 30 { return .green }
        if value >= 70 { return .orange }
        return .primary
    }
}
