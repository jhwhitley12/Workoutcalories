import AppKit
import SwiftUI

struct ResultsTable: View {
    @Environment(ScreenerModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Table(model.results, selection: $model.selection, sortOrder: $model.sortOrder) {
            Group {
                TableColumn("Symbol", value: \.symbol) { stock in
                    Text(stock.symbol).fontWeight(.semibold)
                }
                .width(min: 56, ideal: 70)

                TableColumn("Name", value: \.name) { stock in
                    Text(stock.name).lineLimit(1).help(stock.name)
                }
                .width(min: 100, ideal: 180)

                TableColumn("Price", value: \.price) { stock in
                    Text(Format.price(stock.price)).monospacedDigit()
                }
                .width(min: 60, ideal: 75)

                TableColumn("Today", value: \.sortChangeDay) { stock in
                    ChangeText(value: stock.changeDay)
                }
                .width(min: 55, ideal: 65)

                TableColumn("1W", value: \.sortChange1W) { stock in
                    ChangeText(value: stock.change1W)
                }
                .width(min: 55, ideal: 65)

                TableColumn("1M", value: \.sortChange1M) { stock in
                    ChangeText(value: stock.change1M)
                }
                .width(min: 55, ideal: 65)

                TableColumn("3M", value: \.sortChange3M) { stock in
                    ChangeText(value: stock.change3M)
                }
                .width(min: 55, ideal: 65)

                TableColumn("YTD", value: \.sortChangeYTD) { stock in
                    ChangeText(value: stock.changeYTD)
                }
                .width(min: 55, ideal: 65)
            }

            Group {
                TableColumn("1Y", value: \.sortChange1Y) { stock in
                    ChangeText(value: stock.change1Y)
                }
                .width(min: 55, ideal: 65)

                TableColumn("RSI", value: \.sortRSI) { stock in
                    RSIText(value: stock.rsi14)
                }
                .width(min: 36, ideal: 44)

                TableColumn("From High", value: \.sortFromHigh) { stock in
                    Text(Format.percent(stock.fromHigh52, signed: false)).monospacedDigit()
                }
                .width(min: 60, ideal: 72)

                TableColumn("Rel Vol", value: \.sortRelVolume) { stock in
                    Text(Format.number(stock.relativeVolume, digits: 2)).monospacedDigit()
                }
                .width(min: 50, ideal: 58)

                TableColumn("Mkt Cap", value: \.sortMarketCap) { stock in
                    Text(Format.compact(stock.marketCap)).monospacedDigit()
                }
                .width(min: 60, ideal: 70)

                TableColumn("P/E", value: \.sortPE) { stock in
                    Text(Format.number(stock.pe)).monospacedDigit()
                }
                .width(min: 44, ideal: 54)

                TableColumn("Yield", value: \.sortYield) { stock in
                    Text(Format.percent(stock.dividendYield, signed: false)).monospacedDigit()
                }
                .width(min: 44, ideal: 54)
            }
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
}
