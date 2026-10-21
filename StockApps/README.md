# Stock Apps (Mac)

Two native SwiftUI Mac apps that share one Yahoo Finance data layer. No
account or API key needed.

- **Stock Evaluator**: type a symbol and get a buy / watch / avoid verdict,
  with a 0–100 score, the reasons behind it, red flags and fair value estimates.
- **Stock Screener**: filter whole lists of stocks (Dow 30, Nasdaq-100, …) on
  performance, technical and fundamental measures.

## Requirements
- macOS 14 Sonoma or newer
- Xcode 15 or newer (or just the Command Line Tools: `xcode-select --install`)

## Run them
**Xcode:** open `StockApps/Package.swift`, pick the **StockEvaluator** or
**StockScreener** scheme and **My Mac**, then press **Run** (⌘R).

**Terminal:**
```bash
cd StockApps
swift run -c release StockEvaluator
swift run -c release StockScreener
```

**Real apps for /Applications:**
```bash
cd StockApps
./build-app.sh                  # both apps, or: ./build-app.sh StockEvaluator
open "build/Stock Evaluator.app"
```
Then drag the apps from `build/` to your Applications folder.

Run the tests with `swift test` (or ⌘U in Xcode).

---

## Stock Evaluator

Type a symbol (AAPL, KO, BRK-B, …) and press Evaluate. The app downloads a year
of prices plus the company's financials and analyst data, then scores it.

### What it checks
| Area | Measures | Question |
|---|---|---|
| Valuation | P/E (trailing and forward), PEG, EV/EBITDA, price/sales, price/book | Is the price reasonable? |
| Growth | Revenue growth, earnings growth, expected EPS growth | Is the business growing? |
| Profitability | Net, operating and gross margin, return on equity | Does it make good money? |
| Financial health | Debt/equity, current ratio, free cash flow yield, net cash | Can it pay its debts? |
| Trend & momentum | Vs 200-day average, golden/death cross, 3-month and 1-year return, distance from high, RSI | Is it in an uptrend? |
| Analyst view | Consensus rating, upside to average price target | What does Wall Street expect? |
| Risk | Volatility, max drawdown, beta, short interest | How bumpy is the ride? |
| Dividend income | Yield, payout ratio | Is the dividend sustainable? |

Each measure is scored 0–100 against plain-English thresholds, which are shown
in the app. Click a scorecard row to see every measure and what good and bad
look like.

### Investor style
The style picker in the toolbar changes how much each area counts:

| | Valuation | Growth | Profitability | Health | Trend | Analysts | Risk | Income |
|---|---|---|---|---|---|---|---|---|
| Balanced | 20 | 15 | 15 | 15 | 15 | 10 | 10 | 0 |
| Value | 35 | 5 | 15 | 20 | 5 | 10 | 10 | 0 |
| Growth | 10 | 35 | 15 | 10 | 15 | 10 | 5 | 0 |
| Income | 15 | 5 | 15 | 25 | 5 | 5 | 10 | 20 |
| Momentum | 5 | 15 | 5 | 5 | 45 | 15 | 10 | 0 |

### Verdict
| Score | Verdict |
|---|---|
| 72+ | Strong Buy Candidate |
| 60–71 | Buy Candidate |
| 45–59 | Hold Off / Watch |
| under 45 | Avoid for Now |

- **Red flags** (losing money, burning cash, heavy debt, shrinking revenue, a
  P/E over 60, a downtrend, overbought, trading above the analyst target, very
  volatile, unsustainable dividend) are listed separately. Three or more lower
  the verdict one level.
- If less than 40% of the data the style needs is available, the verdict is
  **Not Enough Data**. Funds (ETFs) have no company financials, so they
  usually only get a verdict under the Momentum style.

### Fair value
Up to three estimates, compared with today's price:
- **Analyst target**: the average 12-month target, with its range.
- **Earnings power**: EPS × (8.5 + 2 × expected growth %), Benjamin Graham's
  growth formula, with growth capped at 15%.
- **Graham number**: √(22.5 × EPS × book value per share), a strict value test.

### Limits
This is a rules-based checklist, not financial advice. It can't know your
goals, taxes or the rest of your portfolio, it doesn't compare a company with
its industry (a P/E of 30 is normal for software and expensive for a bank), and
Yahoo's data can be delayed, missing or wrong. Use it as a starting point for
your own research.

---

## Stock Screener
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
- Sortable results table with search, a details panel with a price chart and
  moving averages, CSV export (⌘E) and refresh (⌘R).

Notes:
- A stock with no value for a filter you turned on (for example an ETF with a
  P/E filter) is left out of the results.
- Relative volume compares today's volume to the 50-day average, so during
  market hours it reads low until the day is over.
- Index memberships change. Edit the lists in
  `Sources/StockScreener/Models/Universe.swift`, or use My Watchlist.

---

## Data notes (both apps)
- Prices come from Yahoo Finance and may be delayed about 15 minutes.
- Yahoo's endpoints are unofficial. Price history needs no login. Company
  financials need a cookie and "crumb" that the app fetches automatically; if
  Yahoo refuses, the apps still work with price data only and say so.
- Symbols use Yahoo's spelling: `BRK-B`, `SHOP.TO` (Toronto), `VOD.L` (London),
  `^GSPC` (S&P 500 index).

## Code layout
| Path | Purpose |
|---|---|
| `Sources/StockCore/` | Shared: Yahoo Finance client, indicators (SMA, RSI, volatility, drawdown), price snapshot and company summary models, price chart and formatting views |
| `Sources/StockEvaluator/Evaluation.swift` | Categories, investor styles, scoring rules, red flags, verdict and fair value |
| `Sources/StockEvaluator/EvaluatorModel.swift` | Loading data, recent symbols, saved style |
| `Sources/StockEvaluator/Views/` | Sidebar and the evaluation report |
| `Sources/StockScreener/` | Screener app: filters, universes, results table |
| `Tests/` | Unit tests for indicators, screening and the evaluator |
