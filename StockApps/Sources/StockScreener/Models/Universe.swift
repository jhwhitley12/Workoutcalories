import Foundation
import StockCore

/// The list of symbols a screen runs over.
enum Universe: String, CaseIterable, Identifiable, Codable {
    case dow30
    case nasdaq100
    case largeCaps
    case etfs
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dow30: "Dow Jones 30"
        case .nasdaq100: "Nasdaq-100"
        case .largeCaps: "US Large Caps"
        case .etfs: "Index & Sector ETFs"
        case .custom: "My Watchlist"
        }
    }

    var systemImage: String {
        switch self {
        case .dow30: "building.columns"
        case .nasdaq100: "cpu"
        case .largeCaps: "chart.bar"
        case .etfs: "square.stack.3d.up"
        case .custom: "star"
        }
    }

    /// Built-in member lists. Index memberships change over time; edit these as needed.
    var builtInSymbols: [String] {
        switch self {
        case .dow30:
            return """
            AAPL AMGN AMZN AXP BA CAT CRM CSCO CVX DIS GS HD HON IBM JNJ JPM KO MCD MMM MRK \
            MSFT NKE NVDA PG SHW TRV UNH V VZ WMT
            """.symbolList
        case .nasdaq100:
            return """
            AAPL MSFT NVDA AMZN META GOOGL GOOG AVGO TSLA COST NFLX AMD PEP ADBE CSCO TMUS LIN QCOM \
            INTU TXN AMGN ISRG CMCSA BKNG AMAT HON VRTX PANW ADP GILD MU ADI LRCX SBUX MELI REGN KLAC \
            INTC PDD MDLZ CTAS SNPS CDNS PYPL CRWD MAR ASML ORLY MRVL CEG FTNT CSX ADSK DASH ROP ABNB \
            WDAY NXPI PCAR CPRT MNST TTD AEP CHTR PAYX FANG ODFL KDP ROST FAST EA DDOG BKR VRSK AZN \
            XEL CTSH EXC KHC GEHC CCEP LULU IDXX TTWO CSGP ZS DXCM ON TEAM BIIB CDW GFS WBD MDB ARM \
            PLTR APP AXON MSTR SHOP
            """.symbolList
        case .largeCaps:
            return """
            AAPL MSFT NVDA AMZN GOOGL META BRK-B AVGO TSLA LLY JPM V UNH XOM MA COST HD PG JNJ WMT \
            NFLX ABBV BAC CRM ORCL KO CVX MRK AMD PEP TMO LIN ADBE ACN MCD CSCO ABT WFC IBM GE PM DHR \
            TXN QCOM INTU CAT VZ AMGN DIS ISRG NOW PFE GS AXP NEE CMCSA SPGI UBER RTX T LOW BKNG MS \
            UNP HON PGR AMAT BLK SYK ETN ELV TJX BSX C VRTX SCHW LMT COP PLD ADP MDT PANW MU NKE BMY \
            CB DE ADI SBUX MMC GILD LRCX UPS KLAC BA SO INTC MO ICE CI AMT DUK
            """.symbolList
        case .etfs:
            return """
            SPY QQQ DIA IWM VTI EFA EEM XLK XLF XLE XLV XLY XLP XLI XLB XLU XLRE XLC SMH ARKK GLD \
            SLV TLT HYG VNQ
            """.symbolList
        case .custom:
            return []
        }
    }
}
