# Stock Screener (Mac)

A native SwiftUI Mac app that screens US stocks and ETFs on price performance,
technical indicators and basic fundamentals. Prices come from Yahoo Finance's
public data, so there's no account or API key to set up.

## Features
- **Universes**: Dow Jones 30, Nasdaq-100, US Large Caps (~100), Index & Sector
  ETFs, or **My Watchlist** (any symbols you type, saved between launches).
- **Filters** (turn any on and set a min and/or max):
  - Price & performance: price, change today, 1 week, 1 month, 3 months, YTD, 1 year
  - Technical: RSI (14), distance from 52-week high, % vs 50/200-day SMA,
    relative volume, 1-year volatility
  - Fundamentals: market cap, P/E (TTM), dividend yield
  - Trend checks: price above 50/200-day SMA, 50-day above 200-day (golden cross),
    price below 200-day SMA
- **Preset screens**: Momentum Leaders, Near 52-Week High, Golden Cross Uptrend,
  Oversold (RSI < 30), Pullback in Uptrend, Unusual Volume, Big Gainers/Losers
  Today, Value, Dividend Income, Low Volatility.
- Sortable results table (click any column header) with search by symbol or name.
- Details panel with a 1M/3M/6M/1Y price chart plus 50- and 200-day moving
  averages, and all the stats.
- Export the matching stocks to CSV (⌘E). Refresh prices with ⌘R.
- Your universe, watchlist and filters are remembered.

## Requirements
- macOS 14 Sonoma or newer
- Xcode 15 or newer (or just the Command Line Tools: `xcode-select --install`)

## Run it
**Option A: Xcode.** Open `StockScreener/Package.swift` in Xcode, pick the
**StockScreener** scheme and **My Mac**, and press **Run** (⌘R).

**Option B: Terminal.**
```bash
cd StockScreener
swift run -c release
```

**Option C: make a real app you can keep in /Applications.**
```bash
cd StockScreener
./build-app.sh
open "build/Stock Screener.app"
```
Then drag `build/Stock Screener.app` to your Applications folder.

Run the tests with `swift test` (or ⌘U in Xcode).

## Notes on the data
- Prices come from Yahoo Finance and may be delayed about 15 minutes. This app
  is for research, not trading advice.
- Yahoo's endpoints are unofficial. Price history needs no login. Market cap,
  P/E and dividend yield use Yahoo's quote endpoint, which needs a cookie; if
  Yahoo refuses it, the app still works but those columns show "—" and the
  sidebar tells you the fundamental filters can't match.
- A stock with no value for a filter you turned on (for example an ETF with a
  P/E filter) is left out of the results.
- Relative volume compares today's volume to the 50-day average, so during
  market hours it reads low until the day is over.
- Index memberships change. Edit the lists in
  `Sources/StockScreener/Models/Universe.swift`, or use My Watchlist.
- Symbols use Yahoo's spelling: `BRK-B`, `SHOP.TO` (Toronto), `VOD.L` (London), `^GSPC` (S&P 500 index).

## Code layout
| File | Purpose |
|---|---|
| `StockScreenerApp.swift` | App entry point, menu commands |
| `ScreenerModel.swift` | App state, loading data, applying the screen, CSV export, saved settings |
| `Services/YahooFinanceClient.swift` | Price history (chart endpoint) and fundamentals (quote endpoint) |
| `Services/Indicators.swift` | SMA, RSI, percent change, volatility |
| `Models/Stock.swift` | A symbol's price bars and computed indicators |
| `Models/ScreenCriteria.swift` | Filter metrics, trend checks and preset screens |
| `Models/Universe.swift` | Built-in symbol lists |
| `Views/` | Sidebar filters, results table, details panel |
