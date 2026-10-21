import SwiftUI

struct ContentView: View {
    @Environment(ScreenerModel.self) private var model
    @State private var showInspector = true
    @State private var showFailures = false

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            FilterSidebar()
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 400)
        } detail: {
            VStack(spacing: 0) {
                if model.loaded.isEmpty {
                    emptyState
                } else if model.results.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("No stocks in \(model.universe.title) pass all \(model.criteria.activeCount) filters. Loosen a filter or pick another universe.")
                    )
                } else {
                    ResultsTable()
                }
                Divider()
                statusBar
            }
            .navigationTitle(model.universe.title)
            .navigationSubtitle("\(model.results.count) of \(model.loaded.count) match")
            .searchable(text: $model.searchText, placement: .toolbar, prompt: "Filter by symbol or name")
            .toolbar { toolbar }
            .inspector(isPresented: $showInspector) {
                Group {
                    if let stock = model.selectedStock {
                        StockDetailView(stock: stock)
                    } else {
                        ContentUnavailableView(
                            "No Stock Selected",
                            systemImage: "chart.xyaxis.line",
                            description: Text("Select a row to see its chart and details.")
                        )
                    }
                }
                .inspectorColumnWidth(min: 300, ideal: 360, max: 520)
            }
        }
        .onChange(of: model.universe, initial: true) {
            model.refresh(force: false)
        }
        .task(id: model.watchlistText) {
            // Load symbols added to the watchlist after a short pause in typing.
            guard model.universe == .custom,
                  (try? await Task.sleep(nanoseconds: 800_000_000)) != nil
            else { return }
            model.refresh(force: false)
        }
        .sheet(isPresented: $showFailures) {
            FailuresSheet(failures: model.currentFailures)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if model.isLoading {
                ProgressView(value: model.progress)
                    .frame(width: 80)
            } else {
                Button {
                    model.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Reload prices for every symbol (⌘R)")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                model.exportCSV()
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(model.results.isEmpty)
            .help("Save the matching stocks as a CSV file")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                showInspector.toggle()
            } label: {
                Label("Details", systemImage: "sidebar.trailing")
            }
            .help("Show or hide the details panel")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.isLoading {
            ProgressView("Loading \(model.symbols.count) symbols…", value: model.progress)
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.symbols.isEmpty {
            ContentUnavailableView(
                "Your Watchlist Is Empty",
                systemImage: "star",
                description: Text("Type some symbols in the sidebar.")
            )
        } else {
            ContentUnavailableView {
                Label("No Data", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Couldn't load prices from Yahoo Finance. Check your internet connection.")
            } actions: {
                Button("Try Again") { model.refresh() }
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            if let lastUpdated = model.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
            }
            if model.criteria.activeCount > 0 {
                Text("\(model.criteria.activeCount) filters active")
            }
            Spacer()
            let failures = model.currentFailures
            if !failures.isEmpty {
                Button("\(failures.count) symbols failed to load") { showFailures = true }
                    .buttonStyle(.link)
            }
            Text("Data: Yahoo Finance, may be delayed")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

private struct FailuresSheet: View {
    let failures: [LoadFailure]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Symbols That Failed to Load")
                .font(.headline)
            List(failures) { failure in
                HStack {
                    Text(failure.symbol).fontWeight(.semibold)
                    Spacer()
                    Text(failure.reason).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 200)
            Text("Check the symbol is spelled the way Yahoo Finance spells it, then press Refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
