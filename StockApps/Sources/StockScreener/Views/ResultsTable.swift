import AppKit
import StockCore
import SwiftUI

private typealias Sort = KeyPathComparator<StockSnapshot>

struct ResultsTable: View {
    @Environment(ScreenerModel.self) private var model

    var body: some View {
        @Bindable var model = model

        // Columns are split into small typed groups so the compiler can type-check them quickly.
        Table(model.results, selection: $model.selection, sortOrder: $model.sortOrder) {
            nameColumns
            changeColumns
            statColumns
        }
        .contextMenu(forSelectionType: StockSnapshot.ID.self) { ids in
            if let symbol = ids.first, let url = model.snapshots[symbol]?.yahooURL {
                Link("Open \(symbol) in Yahoo Finance", destination: url)
                Button("Copy Symbol") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(symbol, forType: .string)
                }
            }
        }
    }

    @TableColumnBuilder<StockSnapshot, Sort>
    private var nameColumns: some TableColumnContent<StockSnapshot, Sort> {
        TableColumn("Symbol", value: \StockSnapshot.symbol) { (stock: StockSnapshot) in
            Text(stock.symbol).fontWeight(.semibold)
        }
        .width(min: 56, ideal: 70)

        TableColumn("Name", value: \StockSnapshot.name) { (stock: StockSnapshot) in
            Text(stock.name).lineLimit(1).help(stock.name)
        }
        .width(min: 100, ideal: 180)

        TableColumn("Price", value: \StockSnapshot.price) { (stock: StockSnapshot) in
            Text(Format.price(stock.price)).monospacedDigit()
        }
        .width(min: 60, ideal: 75)
    }

    @TableColumnBuilder<StockSnapshot, Sort>
    private var changeColumns: some TableColumnContent<StockSnapshot, Sort> {
        changeColumn("Today", \StockSnapshot.sortChangeDay) { $0.changeDay }
        changeColumn("1W", \StockSnapshot.sortChange1W) { $0.change1W }
        changeColumn("1M", \StockSnapshot.sortChange1M) { $0.change1M }
        changeColumn("3M", \StockSnapshot.sortChange3M) { $0.change3M }
        changeColumn("YTD", \StockSnapshot.sortChangeYTD) { $0.changeYTD }
        changeColumn("1Y", \StockSnapshot.sortChange1Y) { $0.change1Y }
    }

    @TableColumnBuilder<StockSnapshot, Sort>
    private var statColumns: some TableColumnContent<StockSnapshot, Sort> {
        TableColumn("RSI", value: \StockSnapshot.sortRSI) { (stock: StockSnapshot) in
            RSIText(value: stock.rsi14)
        }
        .width(min: 36, ideal: 44)

        textColumn("From High", \StockSnapshot.sortFromHigh) { Format.percent($0.fromHigh52, signed: false) }
        textColumn("Rel Vol", \StockSnapshot.sortRelVolume) { Format.number($0.relativeVolume, digits: 2) }
        textColumn("Mkt Cap", \StockSnapshot.sortMarketCap) { Format.compact($0.marketCap) }
        textColumn("P/E", \StockSnapshot.sortPE) { Format.number($0.pe) }
        textColumn("Yield", \StockSnapshot.sortYield) { Format.percent($0.dividendYield, signed: false) }
    }

    /// A green/red percentage column.
    private func changeColumn(
        _ title: String,
        _ sortKey: KeyPath<StockSnapshot, Double>,
        _ value: @escaping (StockSnapshot) -> Double?
    ) -> some TableColumnContent<StockSnapshot, Sort> {
        TableColumn(title, value: sortKey) { (stock: StockSnapshot) in
            ChangeText(value: value(stock))
        }
        .width(min: 55, ideal: 65)
    }

    /// A plain numeric column.
    private func textColumn(
        _ title: String,
        _ sortKey: KeyPath<StockSnapshot, Double>,
        _ text: @escaping (StockSnapshot) -> String
    ) -> some TableColumnContent<StockSnapshot, Sort> {
        TableColumn(title, value: sortKey) { (stock: StockSnapshot) in
            Text(text(stock)).monospacedDigit()
        }
        .width(min: 44, ideal: 64)
    }
}
