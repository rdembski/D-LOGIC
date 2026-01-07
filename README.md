# D-LOGIC QUANT DASHBOARD v4.00

## Statistical Arbitrage Engine for MetaTrader 5

Professional, institutional-grade Pairs Trading system implementing Mean Reversion strategy with Z-Score analysis and Dollar Neutral execution.

---

## Overview

D-LOGIC is a quantitative trading dashboard designed for Statistical Arbitrage (Pairs Trading). It identifies cointegrated currency pairs and generates trading signals based on Z-Score deviation from the mean.

### Key Features

- **OLS Regression** - Dynamic Beta (Hedge Ratio) calculation
- **Z-Score Analysis** - Normalized spread deviation signals
- **Cointegration Testing** - ADF test + Zero-crossing validation
- **Dollar Neutrality** - Balanced position sizing using Hedge Ratio
- **Dark/Neon UI** - Professional institutional-grade interface

---

## Architecture

```
D-LOGIC/
├── D-LOGIC_Quant.mq5       # Main Expert Advisor
├── DLogic_Engine.mqh       # Statistical Engine (CPairsEngine)
├── DLogic_TradeManager.mqh # Execution Module (CTradeManager)
├── DLogic_Dashboard.mqh    # UI Controller (CDashboard)
└── README.md               # Documentation
```

### Class Structure

| Class | Responsibility |
|-------|---------------|
| `CPairsEngine` | OLS Regression, Z-Score, ADF Test, Cointegration |
| `CTradeManager` | Dollar Neutral sizing, Position management |
| `CDashboard` | Scanner heatmap, Spread chart, Z-Score histogram |

---

## Mathematical Foundation

### 1. Hedge Ratio (β) - OLS Regression

```
β = Cov(X,Y) / Var(X)
α = Mean(Y) - β × Mean(X)
R² = [Cov(X,Y)]² / [Var(X) × Var(Y)]
```

### 2. Spread Calculation

```
Spread = log(PriceA) - β × log(PriceB)
```

### 3. Z-Score Normalization

```
Z = (Spread - μ) / σ

Where:
  μ = Rolling mean of spread
  σ = Rolling standard deviation
```

### 4. Cointegration Criteria

- ADF t-statistic < -2.86 (5% significance)
- Zero-crossings ≥ 10 in lookback period
- R² ≥ 60%
- Half-life < 50 bars

---

## Trading Logic

### Entry Signals

| Condition | Action | Rationale |
|-----------|--------|-----------|
| Z > +2.0 | SHORT Spread | Spread too high, expect reversion |
| Z < -2.0 | LONG Spread | Spread too low, expect reversion |

### Execution

| Signal | Asset A | Asset B |
|--------|---------|---------|
| SHORT Spread | SELL | BUY |
| LONG Spread | BUY | SELL |

### Exit Conditions

| Condition | Action |
|-----------|--------|
| Z → 0.0 | Take Profit |
| Z > ±3.5 | Stop Loss (correlation break) |

### Position Sizing (Dollar Neutrality)

```
ValueA × LotsA ≈ β × ValueB × LotsB
```

---

## Installation

1. Copy all files to `MQL5/Experts/D-LOGIC/`
2. Compile `D-LOGIC_Quant.mq5` in MetaEditor
3. Attach EA to any chart (recommended: M15 or H1)
4. Configure input parameters

---

## Input Parameters

### Statistical Engine

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Inp_Lookback` | 200 | Rolling window (bars) |
| `Inp_ZScoreEntry` | 2.0 | Entry threshold |
| `Inp_ZScoreExit` | 0.5 | Exit threshold |
| `Inp_ZScoreStop` | 3.5 | Stop-loss threshold |
| `Inp_MinRSquared` | 0.60 | Minimum R² |
| `Inp_MinZeroCross` | 10 | Min zero crossings |

### Timeframes

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Inp_AnalysisTF` | H4 | Analysis timeframe |
| `Inp_ExecutionTF` | M15 | Execution timeframe |

### Risk Management

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Inp_RiskPercent` | 1.0 | Risk per trade (%) |
| `Inp_MaxPositionValue` | 10000 | Max position ($) |

---

## User Interface

### Scanner Panel
- Dynamic heatmap of 20 forex pairs
- Sorted by absolute Z-Score (best opportunities first)
- Cointegration indicator (green/red dot)
- Click to select pair for analysis

### Spread Chart
- Synthetic spread line (white)
- Bollinger Bands (±2σ)
- Current β and spread values

### Z-Score Histogram
- Real-time Z-Score bar
- Entry levels (±2.0)
- Stop levels (±3.5)

### Control Panel
- `[SCAN MARKET]` - Manual scan trigger
- `[EXECUTE HEDGE]` - Open position on selected pair
- `[CLOSE ALL]` - Emergency close all positions

---

## Keyboard Shortcuts

| Key | Function |
|-----|----------|
| `Q` | Toggle dashboard visibility |
| `R` | Refresh/rescan pairs |
| `X` | Close all positions |

---

## Pairs Scanned

```
EURUSD, GBPUSD, USDJPY, USDCHF,
AUDUSD, USDCAD, NZDUSD, EURGBP,
EURJPY, GBPJPY, AUDJPY, EURAUD,
EURCHF, GBPCHF, AUDNZD, CADJPY
```

---

## Risk Warning

⚠️ **Statistical Arbitrage involves significant risk.**

- Past cointegration does not guarantee future cointegration
- Spreads can diverge beyond stop-loss levels
- Correlation breakdown can result in substantial losses
- Not suitable for all investors

**Always use proper risk management and position sizing.**

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 4.00 | 2024-01 | Complete rewrite - Statistical Arbitrage Engine |
| 3.00 | 2024-01 | Added ICT Analysis (deprecated) |
| 2.00 | 2024-01 | Added Position Calculator |
| 1.00 | 2024-01 | Initial Pairs Dashboard |

---

## Author

**Rafał Dembski**

---

## License

Proprietary - All rights reserved.
