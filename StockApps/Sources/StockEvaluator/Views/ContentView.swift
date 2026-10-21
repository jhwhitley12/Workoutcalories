import StockCore
import SwiftUI

struct ContentView: View {
    @Environment(EvaluatorModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            detail
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Investor Style", selection: $model.style) {
                            ForEach(InvestorStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                        .help(model.style.summary)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            model.reload()
                        } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }
                        .disabled(model.selectedSymbol == nil || model.isLoading)
                        .help("Reload data for this stock (⌘R)")
                    }
                }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let symbol = model.selectedSymbol, model.loadingSymbol == symbol, model.stock == nil {
            ProgressView("Analyzing \(symbol)…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let message = model.errorMessage, model.stock == nil {
            ContentUnavailableView {
                Label("Couldn't Evaluate", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { model.reload() }
            }
        } else if let stock = model.stock, let evaluation = model.evaluation {
            EvaluationView(stock: stock, summary: model.summary, summaryError: model.summaryError, evaluation: evaluation)
                .id(stock.symbol)
        } else {
            WelcomeView()
        }
    }
}

private struct WelcomeView: View {
    @Environment(EvaluatorModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("Should You Buy It?", systemImage: "magnifyingglass.circle")
        } description: {
            Text("Type a stock symbol in the sidebar, such as AAPL or KO. The app scores the company's valuation, growth, profitability, financial health, trend, analyst outlook and risk, then weighs them for your investing style.")
        } actions: {
            HStack {
                ForEach(["AAPL", "MSFT", "KO", "JPM", "TSLA"], id: \.self) { symbol in
                    Button(symbol) { model.select(symbol) }
                }
            }
        }
    }
}

private struct Sidebar: View {
    @Environment(EvaluatorModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            HStack {
                TextField("Symbol", text: $model.symbolInput, prompt: Text("Symbol, e.g. NVDA"))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.evaluateInput() }
                Button("Evaluate") { model.evaluateInput() }
                    .disabled(model.symbolInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)

            List(selection: Binding(
                get: { model.selectedSymbol },
                set: { symbol in if let symbol { model.select(symbol) } }
            )) {
                Section("Recent") {
                    ForEach(model.recentSymbols, id: \.self) { symbol in
                        RecentRow(symbol: symbol)
                            .tag(symbol)
                            .contextMenu {
                                Button("Remove from Recent") { model.removeRecent(symbol) }
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            .overlay {
                if model.recentSymbols.isEmpty {
                    Text("Stocks you evaluate appear here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }

            if !model.recentSymbols.isEmpty {
                Divider()
                Button("Clear Recent") { model.clearRecents() }
                    .buttonStyle(.link)
                    .font(.caption)
                    .padding(8)
            }
        }
    }
}

private struct RecentRow: View {
    @Environment(EvaluatorModel.self) private var model
    let symbol: String

    var body: some View {
        let evaluation = model.evaluation(for: symbol)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol).fontWeight(.semibold)
                if let name = model.stocks[symbol]?.name, name != symbol {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if model.loadingSymbol == symbol {
                ProgressView().controlSize(.small)
            } else if let evaluation, let score = evaluation.overall, evaluation.verdict != .insufficientData {
                Text(Format.number(score, digits: 0))
                    .font(.callout.monospacedDigit().bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(evaluation.verdict.color, in: Capsule())
                    .help(evaluation.verdict.title)
            }
        }
    }
}
