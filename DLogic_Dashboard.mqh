//+------------------------------------------------------------------+
//|                                           DLogic_Dashboard.mqh   |
//|              D-LOGIC Professional Pairs Trading Dashboard         |
//|                                        Author: Rafał Dembski     |
//|                                                                   |
//|  Original Layout Design v5.11                                     |
//|  - Pairs Trading Dashboard (with TF, Spearman, Type columns)      |
//|  - Symbols Panel (currency pair buttons)                          |
//|  - Spread Panel (with LE levels notation)                         |
//|  - ICT Analysis Panel (Sessions + ICT Patterns)                   |
//|  - Position Calculator Panel (full calculator)                    |
//|  - Performance Metrics Panel (GS Quant / ffn style)               |
//|    * Risk-Adjusted: Sharpe, Sortino, Calmar Ratios                |
//|    * Drawdown: Max DD, Current DD, Ulcer Index                    |
//|    * Volatility: Ann. Vol, Regime Detection, ATR                  |
//|    * Statistics: Win Rate, Profit Factor, Recovery Factor         |
//+------------------------------------------------------------------+
#property copyright "Rafał Dembski"
#property strict

#include "DLogic_Engine.mqh"

// ============================================================
// COLOR SCHEME - CLASSIC TERMINAL
// ============================================================
#define CLR_PANEL_BG       C'20,22,28'      // Dark panel background
#define CLR_PANEL_BORDER   C'50,55,70'      // Panel border
#define CLR_TITLE_BG       C'30,80,120'     // Title bar background (blue)
#define CLR_TITLE_TEXT     C'220,230,255'   // Title text

#define CLR_NEON_GREEN     C'0,255,100'     // Positive/Long/Oversold
#define CLR_NEON_RED       C'255,80,80'     // Negative/Short/Overbought
#define CLR_NEON_CYAN      C'0,200,255'     // Accent
#define CLR_NEON_YELLOW    C'255,220,0'     // Warning/Mean
#define CLR_NEON_ORANGE    C'255,150,50'    // Alert
#define CLR_NEON_PURPLE    C'180,100,255'   // Special
#define CLR_NEON_BLUE      C'0,150,255'     // Active session

#define CLR_TEXT_WHITE     C'255,255,255'   // Primary text
#define CLR_TEXT_LIGHT     C'180,190,210'   // Secondary text
#define CLR_TEXT_DIM       C'120,130,150'   // Dim text
#define CLR_TEXT_DARK      C'80,90,110'     // Very dim

#define CLR_ROW_EVEN       C'25,28,35'      // Even row
#define CLR_ROW_ODD        C'30,33,42'      // Odd row
#define CLR_ROW_SELECTED   C'40,60,90'      // Selected row

#define CLR_CHART_BG       C'15,18,25'      // Chart background
#define CLR_CHART_GRID     C'35,40,50'      // Chart grid

#define CLR_BTN_GREEN      C'40,100,60'     // Green button
#define CLR_BTN_RED        C'120,40,40'     // Red button
#define CLR_BTN_BLUE       C'30,80,120'     // Blue button
#define CLR_BTN_GRAY       C'50,55,70'      // Gray button

// ============================================================
// LAYOUT DIMENSIONS
// ============================================================
#define PANEL_X            10              // Left panel X position
#define PANEL_Y            25              // Panel Y position
#define DASHBOARD_WIDTH    370             // Dashboard panel width
#define SYMBOLS_WIDTH      70              // Symbols panel width
#define SPREAD_HEIGHT      120             // Spread panel height
#define ICT_HEIGHT         140             // ICT panel height
#define CALC_WIDTH         200             // Position calculator width
#define TITLE_HEIGHT       22              // Title bar height
#define ROW_HEIGHT         16              // Table row height
#define FONT_SIZE          8               // Main font size
#define FONT_SIZE_TITLE    9               // Title font size
#define FONT_SIZE_SMALL    7               // Small font
#define FONT_SIZE_LARGE    10              // Large font
#define PANEL_GAP          5               // Gap between panels

// ============================================================
// STRUCTURES
// ============================================================
enum ENUM_REGIME {
   REGIME_MEAN_REVERT,
   REGIME_TRENDING,
   REGIME_VOLATILE,
   REGIME_CONSOLIDATION
};

enum ENUM_SESSION {
   SESSION_ASIA,
   SESSION_LONDON,
   SESSION_NEW_YORK
};

struct SSignalHistory {
   datetime   time;
   string     pairName;
   int        signal;
   double     zScore;
   double     strength;
   bool       executed;
   double     entryPL;
};

struct SPerformanceStats {
   // Basic counts
   int        totalSignals;
   int        executedTrades;
   int        winningTrades;
   int        losingTrades;

   // P&L metrics
   double     totalPL;
   double     grossProfit;
   double     grossLoss;
   double     winRate;
   double     profitFactor;
   double     avgWin;
   double     avgLoss;
   double     expectancy;

   // Risk-Adjusted Returns (Goldman Sachs / ffn style)
   double     sharpeRatio;      // Risk-adjusted return vs risk-free rate
   double     sortinoRatio;     // Like Sharpe but only considers downside volatility
   double     calmarRatio;      // Return / Max Drawdown

   // Drawdown Analysis
   double     maxDrawdown;      // Maximum peak-to-trough decline
   double     currentDrawdown;  // Current drawdown from peak
   double     avgDrawdown;      // Average drawdown
   double     ulcerIndex;       // RMS of drawdowns (pain index)
   double     drawdownDuration; // Days in drawdown

   // Volatility Metrics
   double     annualizedReturn; // Annualized return %
   double     annualizedVol;    // Annualized volatility
   double     downsideVol;      // Downside deviation
   double     volPercentile;    // Current vol vs historical (0-100)

   // Trade Statistics
   double     avgTradeDuration; // Average trade duration in hours
   double     maxConsecWins;    // Maximum consecutive wins
   double     maxConsecLosses;  // Maximum consecutive losses
   double     recoveryFactor;   // Total profit / Max Drawdown

   // Equity curve data
   double     peakEquity;       // Historical peak equity
   double     currentEquity;    // Current equity
};

// Volatility analysis structure
struct SVolatilityMetrics {
   double     atr14;            // 14-period ATR
   double     atr50;            // 50-period ATR
   double     rollingVol20;     // 20-day rolling volatility
   double     rollingVol60;     // 60-day rolling volatility
   double     volRatio;         // Short/Long vol ratio
   double     volRegime;        // 0=Low, 1=Normal, 2=High, 3=Extreme
   double     volPercentile;    // Historical percentile (0-100)
   double     impliedMove;      // Expected daily move based on vol
};

struct SPositionCalcResult {
   double     positionSize;     // Lots
   double     riskAmount;       // Account currency
   double     entryPrice;
   double     stopLoss;
   double     takeProfit;
   double     potentialLoss;
   double     potentialProfit;
   double     riskReward;
   double     marginRequired;
   double     pipValue;
   bool       insufficientMargin;
};

struct SICTPattern {
   int        fairValueGaps;
   int        orderBlocks;
   bool       bullishOB;
   bool       bearishOB;
};

//+------------------------------------------------------------------+
//| CDashboard - Original Layout Design                               |
//+------------------------------------------------------------------+
class CDashboard {
private:
   string         m_prefix;
   int            m_startX;
   int            m_startY;
   bool           m_isVisible;

   // Data
   SPairResult    m_scanResults[];
   int            m_resultCount;
   int            m_selectedRow;
   int            m_scrollOffset;

   // Spread history
   double         m_spreadHistory[];
   double         m_zScoreHistory[];
   int            m_historySize;

   // Selected pair for spread display
   string         m_spreadPairA;
   string         m_spreadPairB;

   // Position Calculator state
   string         m_calcSymbol;
   double         m_calcRiskPercent;
   double         m_calcStopLossPips;
   double         m_calcTakeProfitPips;
   bool           m_calcIsBuy;
   SPositionCalcResult m_calcResult;

   // ICT Analysis
   SICTPattern    m_ictPattern;
   string         m_ictSymbol;

   // Analytics
   ENUM_REGIME    m_currentRegime;
   double         m_signalStrength;

   // Signal History
   SSignalHistory m_signalHistory[];
   int            m_historyCount;
   int            m_maxHistory;

   // Performance
   SPerformanceStats m_perfStats;

   // Volatility metrics
   SVolatilityMetrics m_volMetrics;

   // Equity history for calculations
   double         m_equityHistory[];
   double         m_returnHistory[];
   int            m_equityHistorySize;
   int            m_equityHistoryCount;
   datetime       m_lastEquityUpdate;
   double         m_initialEquity;

   // Alert system
   bool           m_alertsEnabled;
   double         m_alertZThreshold;
   double         m_alertStrengthThreshold;

   // Symbol buttons
   string         m_symbolButtons[8];
   int            m_symbolButtonCount;

   //+------------------------------------------------------------------+
   //| Create Label                                                      |
   //+------------------------------------------------------------------+
   void CreateLabel(string name, string text, int x, int y, color clr,
                    int fontSize = FONT_SIZE, string font = "Consolas") {
      string objName = m_prefix + name;

      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
         // Static properties - set only once
         ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      }

      // Dynamic properties - update each frame
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, objName, OBJPROP_FONT, font);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
   }

   //+------------------------------------------------------------------+
   //| Create Rectangle Panel - SOLID FILL (no transparency)             |
   //+------------------------------------------------------------------+
   void CreatePanel(string name, int x, int y, int w, int h,
                    color bgClr, color borderClr = clrNONE, bool isBackground = false) {
      string objName = m_prefix + name;

      // Only create if doesn't exist (prevents flickering)
      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

         // These properties only need to be set once
         ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      }

      // Update position and size (may change)
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);

      // Update colors (may change)
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, isBackground ? 0 : 10);

      // Border color
      if(borderClr != clrNONE) {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, borderClr);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      } else {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, bgClr);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 0);
      }
   }

   //+------------------------------------------------------------------+
   //| Create Button                                                     |
   //+------------------------------------------------------------------+
   void CreateButton(string name, string text, int x, int y, int w, int h,
                     color bgClr, color txtClr, int fontSize = FONT_SIZE) {
      string objName = m_prefix + name;

      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
         // Static properties
         ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
         ObjectSetString(0, objName, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, CLR_PANEL_BORDER);
      }

      // Dynamic properties
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, txtClr);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   }

   //+------------------------------------------------------------------+
   //| Create Edit Box                                                   |
   //+------------------------------------------------------------------+
   void CreateEdit(string name, string text, int x, int y, int w, int h,
                   color bgClr, color txtClr, int fontSize = FONT_SIZE) {
      string objName = m_prefix + name;

      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_EDIT, 0, 0, 0);
         // Static properties
         ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, objName, OBJPROP_ALIGN, ALIGN_RIGHT);
         ObjectSetInteger(0, objName, OBJPROP_READONLY, false);
         ObjectSetString(0, objName, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, CLR_PANEL_BORDER);
      }

      // Dynamic properties
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, txtClr);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   }

   //+------------------------------------------------------------------+
   //| Delete all objects                                                |
   //+------------------------------------------------------------------+
   void DeleteAll() {
      ObjectsDeleteAll(0, m_prefix);
   }

   //+------------------------------------------------------------------+
   //| Get Z-Score color                                                 |
   //+------------------------------------------------------------------+
   color GetZScoreColor(double z) {
      double absZ = MathAbs(z);
      if(absZ >= 2.5) return CLR_NEON_RED;
      if(absZ >= 2.0) return CLR_NEON_ORANGE;
      if(absZ >= 1.5) return CLR_NEON_YELLOW;
      if(absZ <= 0.5) return CLR_NEON_GREEN;
      return CLR_TEXT_LIGHT;
   }

   //+------------------------------------------------------------------+
   //| Get Spearman color (for correlation)                              |
   //+------------------------------------------------------------------+
   color GetSpearmanColor(double corr) {
      if(corr >= 0) return CLR_NEON_GREEN;
      return CLR_NEON_RED;
   }

   //+------------------------------------------------------------------+
   //| Get signal text                                                   |
   //+------------------------------------------------------------------+
   string GetSignalText(int signal) {
      switch(signal) {
         case 2:  return "Long";
         case 1:  return "Long";
         case -1: return "Short";
         case -2: return "Short";
         default: return "None";
      }
   }

   //+------------------------------------------------------------------+
   //| Get timeframe string                                              |
   //+------------------------------------------------------------------+
   string GetTFString(ENUM_TIMEFRAMES tf) {
      switch(tf) {
         case PERIOD_M1:  return "M1";
         case PERIOD_M5:  return "M5";
         case PERIOD_M15: return "M15";
         case PERIOD_M30: return "M30";
         case PERIOD_H1:  return "H1";
         case PERIOD_H4:  return "H4";
         case PERIOD_D1:  return "D1";
         case PERIOD_W1:  return "W1";
         case PERIOD_MN1: return "MN";
         default: return "??";
      }
   }

   //+------------------------------------------------------------------+
   //| Check if session is active                                        |
   //+------------------------------------------------------------------+
   bool IsSessionActive(ENUM_SESSION session) {
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);
      int hour = dt.hour;

      switch(session) {
         case SESSION_ASIA:     return (hour >= 0 && hour < 9);    // 00:00-09:00 UTC
         case SESSION_LONDON:   return (hour >= 8 && hour < 17);   // 08:00-17:00 UTC
         case SESSION_NEW_YORK: return (hour >= 13 && hour < 22);  // 13:00-22:00 UTC
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Detect market regime                                              |
   //+------------------------------------------------------------------+
   ENUM_REGIME DetectRegime(SPairResult &result) {
      if(result.hurstExponent < 0.45 && result.varianceRatio < 0.95)
         return REGIME_MEAN_REVERT;
      if(result.hurstExponent > 0.55 || result.varianceRatio > 1.1)
         return REGIME_TRENDING;
      if(result.volatilityRatio > 1.5)
         return REGIME_VOLATILE;
      return REGIME_CONSOLIDATION;
   }

   //+------------------------------------------------------------------+
   //| Calculate signal strength (0-100)                                 |
   //+------------------------------------------------------------------+
   double CalculateSignalStrength(SPairResult &result) {
      double strength = 0;
      double zComponent = MathMin(40, MathAbs(result.zScore) * 15);
      strength += zComponent;
      if(result.isCointegrated) strength += 25;
      if(result.hurstExponent < 0.5) {
         strength += (0.5 - result.hurstExponent) * 40;
      }
      strength += result.spreadStability * 0.15;
      return MathMin(100, strength);
   }

   //+------------------------------------------------------------------+
   //| Calculate position size                                           |
   //+------------------------------------------------------------------+
   void CalculatePosition() {
      if(m_calcSymbol == "") return;

      double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskAmount = accountEquity * m_calcRiskPercent / 100.0;

      double tickValue = SymbolInfoDouble(m_calcSymbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(m_calcSymbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(m_calcSymbol, SYMBOL_POINT);
      double lotStep = SymbolInfoDouble(m_calcSymbol, SYMBOL_VOLUME_STEP);
      double minLot = SymbolInfoDouble(m_calcSymbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_calcSymbol, SYMBOL_VOLUME_MAX);
      int digits = (int)SymbolInfoInteger(m_calcSymbol, SYMBOL_DIGITS);

      double bid = SymbolInfoDouble(m_calcSymbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_calcSymbol, SYMBOL_ASK);

      // Calculate pip value (for 5-digit brokers)
      double pipSize = (digits == 3 || digits == 5) ? point * 10 : point;
      double pipsValue = tickValue * (pipSize / tickSize);

      // Entry price
      m_calcResult.entryPrice = m_calcIsBuy ? ask : bid;

      // Stop Loss and Take Profit
      if(m_calcIsBuy) {
         m_calcResult.stopLoss = m_calcResult.entryPrice - m_calcStopLossPips * pipSize;
         m_calcResult.takeProfit = m_calcResult.entryPrice + m_calcTakeProfitPips * pipSize;
      } else {
         m_calcResult.stopLoss = m_calcResult.entryPrice + m_calcStopLossPips * pipSize;
         m_calcResult.takeProfit = m_calcResult.entryPrice - m_calcTakeProfitPips * pipSize;
      }

      // Position size calculation
      double slValuePerLot = m_calcStopLossPips * pipsValue;
      if(slValuePerLot > 0) {
         m_calcResult.positionSize = riskAmount / slValuePerLot;
      } else {
         m_calcResult.positionSize = minLot;
      }

      // Normalize to lot step
      m_calcResult.positionSize = MathFloor(m_calcResult.positionSize / lotStep) * lotStep;
      m_calcResult.positionSize = MathMax(minLot, MathMin(maxLot, m_calcResult.positionSize));

      // Risk amount (actual)
      m_calcResult.riskAmount = m_calcResult.positionSize * slValuePerLot;

      // Potential Loss/Profit
      m_calcResult.potentialLoss = -m_calcResult.riskAmount;
      m_calcResult.potentialProfit = m_calcResult.positionSize * m_calcTakeProfitPips * pipsValue;

      // Risk/Reward ratio
      if(m_calcStopLossPips > 0) {
         m_calcResult.riskReward = m_calcTakeProfitPips / m_calcStopLossPips;
      } else {
         m_calcResult.riskReward = 0;
      }

      // Margin required
      double marginRequired = 0;
      ENUM_ORDER_TYPE orderType = m_calcIsBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double price = m_calcIsBuy ? ask : bid;
      if(!OrderCalcMargin(orderType, m_calcSymbol, m_calcResult.positionSize, price, marginRequired)) {
         marginRequired = 0;  // Fallback if calculation fails
      }
      m_calcResult.marginRequired = marginRequired;

      // Pip value
      m_calcResult.pipValue = pipsValue;

      // Check margin
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      m_calcResult.insufficientMargin = (marginRequired > freeMargin * 0.9);
   }

   //+------------------------------------------------------------------+
   //| Update Equity History - call periodically (e.g., daily)           |
   //+------------------------------------------------------------------+
   void UpdateEquityHistory() {
      datetime now = TimeCurrent();

      // Update daily (or more frequently for intraday)
      if(now - m_lastEquityUpdate < 3600) return;  // Update hourly minimum
      m_lastEquityUpdate = now;

      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_perfStats.currentEquity = currentEquity;

      // Track peak equity for drawdown
      if(currentEquity > m_perfStats.peakEquity) {
         m_perfStats.peakEquity = currentEquity;
      }

      // Calculate current drawdown
      if(m_perfStats.peakEquity > 0) {
         m_perfStats.currentDrawdown = (m_perfStats.peakEquity - currentEquity) / m_perfStats.peakEquity * 100.0;
         if(m_perfStats.currentDrawdown > m_perfStats.maxDrawdown) {
            m_perfStats.maxDrawdown = m_perfStats.currentDrawdown;
         }
      }

      // Shift history
      for(int i = m_equityHistorySize - 1; i > 0; i--) {
         m_equityHistory[i] = m_equityHistory[i-1];
         m_returnHistory[i] = m_returnHistory[i-1];
      }

      // Add new equity
      m_equityHistory[0] = currentEquity;
      m_equityHistoryCount = MathMin(m_equityHistoryCount + 1, m_equityHistorySize);

      // Calculate return if we have previous equity
      if(m_equityHistory[1] > 0) {
         m_returnHistory[0] = (currentEquity - m_equityHistory[1]) / m_equityHistory[1];
      } else {
         m_returnHistory[0] = 0;
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Risk-Adjusted Metrics (Sharpe, Sortino, Calmar)         |
   //+------------------------------------------------------------------+
   void CalculateRiskMetrics() {
      if(m_equityHistoryCount < 10) return;  // Need minimum data

      double riskFreeRate = 0.05 / 252.0;  // ~5% annual, daily rate
      int n = MathMin(m_equityHistoryCount, m_equityHistorySize);

      // Calculate mean return
      double sumReturns = 0;
      for(int i = 0; i < n; i++) {
         sumReturns += m_returnHistory[i];
      }
      double meanReturn = sumReturns / n;

      // Calculate standard deviation (total volatility)
      double sumSqDev = 0;
      double sumDownsideSqDev = 0;
      int downsideCount = 0;

      for(int i = 0; i < n; i++) {
         double dev = m_returnHistory[i] - meanReturn;
         sumSqDev += dev * dev;

         // Downside deviation (only negative returns)
         if(m_returnHistory[i] < 0) {
            sumDownsideSqDev += m_returnHistory[i] * m_returnHistory[i];
            downsideCount++;
         }
      }

      double stdDev = MathSqrt(sumSqDev / n);
      double downsideStdDev = downsideCount > 0 ? MathSqrt(sumDownsideSqDev / downsideCount) : stdDev;

      // Annualize metrics (assuming hourly updates, ~6240 hours/year trading)
      double annualizeFactor = MathSqrt(6240);  // For volatility
      double annualizeReturn = 6240;            // For returns

      m_perfStats.annualizedReturn = meanReturn * annualizeReturn * 100.0;
      m_perfStats.annualizedVol = stdDev * annualizeFactor * 100.0;
      m_perfStats.downsideVol = downsideStdDev * annualizeFactor * 100.0;

      // SHARPE RATIO = (Return - RiskFree) / StdDev
      if(stdDev > 1e-10) {
         m_perfStats.sharpeRatio = (meanReturn - riskFreeRate) / stdDev * MathSqrt(252);
      } else {
         m_perfStats.sharpeRatio = 0;
      }

      // SORTINO RATIO = (Return - RiskFree) / DownsideStdDev
      if(downsideStdDev > 1e-10) {
         m_perfStats.sortinoRatio = (meanReturn - riskFreeRate) / downsideStdDev * MathSqrt(252);
      } else {
         m_perfStats.sortinoRatio = 0;
      }

      // CALMAR RATIO = AnnualizedReturn / MaxDrawdown
      if(m_perfStats.maxDrawdown > 0.1) {
         m_perfStats.calmarRatio = m_perfStats.annualizedReturn / m_perfStats.maxDrawdown;
      } else {
         m_perfStats.calmarRatio = 0;
      }

      // ULCER INDEX (RMS of drawdowns)
      double sumDrawdownSq = 0;
      double peak = m_equityHistory[n-1];  // Start from oldest
      int ddCount = 0;

      for(int i = n - 1; i >= 0; i--) {
         if(m_equityHistory[i] > peak) peak = m_equityHistory[i];
         if(peak > 0) {
            double dd = (peak - m_equityHistory[i]) / peak * 100.0;
            sumDrawdownSq += dd * dd;
            ddCount++;
         }
      }
      m_perfStats.ulcerIndex = ddCount > 0 ? MathSqrt(sumDrawdownSq / ddCount) : 0;

      // Recovery Factor = Total Profit / Max Drawdown
      if(m_perfStats.maxDrawdown > 0.1 && m_initialEquity > 0) {
         double totalReturn = (m_perfStats.currentEquity - m_initialEquity) / m_initialEquity * 100.0;
         m_perfStats.recoveryFactor = totalReturn / m_perfStats.maxDrawdown;
      }

      // Expectancy = (WinRate * AvgWin) - (LoseRate * AvgLoss)
      if(m_perfStats.executedTrades > 0) {
         double loseRate = 100.0 - m_perfStats.winRate;
         m_perfStats.expectancy = (m_perfStats.winRate / 100.0 * m_perfStats.avgWin) -
                                   (loseRate / 100.0 * m_perfStats.avgLoss);
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Volatility Metrics                                      |
   //+------------------------------------------------------------------+
   void CalculateVolatilityMetrics(string symbol) {
      if(symbol == "") symbol = Symbol();

      // Calculate ATR(14) and ATR(50)
      int atr14Handle = iATR(symbol, PERIOD_H1, 14);
      int atr50Handle = iATR(symbol, PERIOD_H1, 50);

      double atr14[], atr50[];
      ArraySetAsSeries(atr14, true);
      ArraySetAsSeries(atr50, true);

      if(atr14Handle != INVALID_HANDLE && atr50Handle != INVALID_HANDLE) {
         CopyBuffer(atr14Handle, 0, 0, 1, atr14);
         CopyBuffer(atr50Handle, 0, 0, 1, atr50);

         if(ArraySize(atr14) > 0) m_volMetrics.atr14 = atr14[0];
         if(ArraySize(atr50) > 0) m_volMetrics.atr50 = atr50[0];

         IndicatorRelease(atr14Handle);
         IndicatorRelease(atr50Handle);
      }

      // Calculate rolling volatility from close prices
      double close[];
      ArraySetAsSeries(close, true);
      if(CopyClose(symbol, PERIOD_H1, 0, 60, close) >= 60) {
         // 20-period volatility
         double returns20[];
         ArrayResize(returns20, 20);
         for(int i = 0; i < 20; i++) {
            if(close[i+1] > 0) {
               returns20[i] = MathLog(close[i] / close[i+1]);
            }
         }
         m_volMetrics.rollingVol20 = CalculateStdDev(returns20, 20) * MathSqrt(252 * 24) * 100.0;

         // 60-period volatility
         double returns60[];
         ArrayResize(returns60, 59);
         for(int i = 0; i < 59; i++) {
            if(close[i+1] > 0) {
               returns60[i] = MathLog(close[i] / close[i+1]);
            }
         }
         m_volMetrics.rollingVol60 = CalculateStdDev(returns60, 59) * MathSqrt(252 * 24) * 100.0;
      }

      // Volatility ratio (short/long term)
      if(m_volMetrics.rollingVol60 > 0) {
         m_volMetrics.volRatio = m_volMetrics.rollingVol20 / m_volMetrics.rollingVol60;
      }

      // Volatility regime classification
      if(m_volMetrics.volRatio < 0.7) {
         m_volMetrics.volRegime = 0;  // Low volatility
      } else if(m_volMetrics.volRatio < 1.0) {
         m_volMetrics.volRegime = 1;  // Normal
      } else if(m_volMetrics.volRatio < 1.5) {
         m_volMetrics.volRegime = 2;  // High
      } else {
         m_volMetrics.volRegime = 3;  // Extreme
      }

      // Implied daily move (using 20-day vol)
      double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
      m_volMetrics.impliedMove = currentPrice * (m_volMetrics.rollingVol20 / 100.0) / MathSqrt(252);
   }

   //+------------------------------------------------------------------+
   //| Helper: Calculate Standard Deviation                              |
   //+------------------------------------------------------------------+
   double CalculateStdDev(double &arr[], int size) {
      if(size < 2) return 0;

      double sum = 0;
      for(int i = 0; i < size; i++) {
         sum += arr[i];
      }
      double mean = sum / size;

      double sumSq = 0;
      for(int i = 0; i < size; i++) {
         double dev = arr[i] - mean;
         sumSq += dev * dev;
      }

      return MathSqrt(sumSq / (size - 1));
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CDashboard() {
      m_prefix = "DL_";
      m_startX = PANEL_X;
      m_startY = PANEL_Y;
      m_isVisible = true;
      m_resultCount = 0;
      m_selectedRow = 0;
      m_scrollOffset = 0;
      m_historySize = 100;
      m_historyCount = 0;
      m_maxHistory = 50;
      m_alertsEnabled = true;
      m_alertZThreshold = 2.0;
      m_alertStrengthThreshold = 60;
      m_currentRegime = REGIME_CONSOLIDATION;
      m_signalStrength = 0;

      m_spreadPairA = "";
      m_spreadPairB = "";

      // Position calculator defaults
      m_calcSymbol = "";
      m_calcRiskPercent = 1.0;
      m_calcStopLossPips = 50.0;
      m_calcTakeProfitPips = 100.0;
      m_calcIsBuy = true;
      ZeroMemory(m_calcResult);

      // ICT
      m_ictSymbol = "";
      ZeroMemory(m_ictPattern);

      // Symbol buttons
      m_symbolButtons[0] = "EURUSD";
      m_symbolButtons[1] = "GBPUSD";
      m_symbolButtons[2] = "USDJPY";
      m_symbolButtons[3] = "USDCAD";
      m_symbolButtons[4] = "USDCHF";
      m_symbolButtons[5] = "AUDUSD";
      m_symbolButtons[6] = "NZDUSD";
      m_symbolButtonCount = 7;

      ArrayResize(m_spreadHistory, m_historySize);
      ArrayResize(m_zScoreHistory, m_historySize);
      ArrayResize(m_signalHistory, m_maxHistory);
      ArrayInitialize(m_spreadHistory, 0);
      ArrayInitialize(m_zScoreHistory, 0);
      ZeroMemory(m_perfStats);
      ZeroMemory(m_volMetrics);

      // Initialize equity tracking for Sharpe/Sortino calculations
      m_equityHistorySize = 252;  // ~1 year of daily data
      m_equityHistoryCount = 0;
      ArrayResize(m_equityHistory, m_equityHistorySize);
      ArrayResize(m_returnHistory, m_equityHistorySize);
      ArrayInitialize(m_equityHistory, 0);
      ArrayInitialize(m_returnHistory, 0);
      m_lastEquityUpdate = 0;
      m_initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);

      // Initialize performance stats
      m_perfStats.peakEquity = m_initialEquity;
      m_perfStats.currentEquity = m_initialEquity;
   }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   void Init() {
      DeleteAll();
      m_isVisible = true;

      // Set default calculator symbol
      string chartSymbol = Symbol();
      m_calcSymbol = chartSymbol;
      m_ictSymbol = chartSymbol;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   void Deinit() {
      DeleteAll();
   }

   //+------------------------------------------------------------------+
   //| Set Position                                                      |
   //+------------------------------------------------------------------+
   void SetPosition(int x, int y) {
      m_startX = x;
      m_startY = y;
   }

   //+------------------------------------------------------------------+
   //| Update results                                                    |
   //+------------------------------------------------------------------+
   void UpdateResults(SPairResult &results[], int count) {
      m_resultCount = count;
      ArrayResize(m_scanResults, count);

      for(int i = 0; i < count; i++) {
         m_scanResults[i] = results[i];
      }

      if(m_selectedRow >= count) m_selectedRow = MathMax(0, count - 1);

      if(count > 0 && m_selectedRow < count) {
         m_currentRegime = DetectRegime(m_scanResults[m_selectedRow]);
         m_signalStrength = CalculateSignalStrength(m_scanResults[m_selectedRow]);

         // Update spread pair
         if(m_spreadPairA == "" || m_spreadPairB == "") {
            m_spreadPairA = m_scanResults[m_selectedRow].symbolA;
            m_spreadPairB = m_scanResults[m_selectedRow].symbolB;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Update spread history (2 params - single values)                  |
   //+------------------------------------------------------------------+
   void UpdateSpreadHistory(double spread, double zScore) {
      for(int i = m_historySize - 1; i > 0; i--) {
         m_spreadHistory[i] = m_spreadHistory[i-1];
         m_zScoreHistory[i] = m_zScoreHistory[i-1];
      }
      m_spreadHistory[0] = spread;
      m_zScoreHistory[0] = zScore;
   }

   //+------------------------------------------------------------------+
   //| Update spread history (3 params - arrays)                         |
   //+------------------------------------------------------------------+
   void UpdateSpreadHistory(double &spread[], double &zScore[], int size) {
      int copySize = MathMin(size, m_historySize);
      for(int i = 0; i < copySize; i++) {
         m_spreadHistory[i] = spread[i];
         m_zScoreHistory[i] = zScore[i];
      }
   }

   //+------------------------------------------------------------------+
   //| Main Draw function                                                |
   //+------------------------------------------------------------------+
   void Draw() {
      if(!m_isVisible) return;

      int x = m_startX;
      int y = m_startY;

      // Get selected pair data
      SPairResult result;
      if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
         result = m_scanResults[m_selectedRow];
      } else if(m_resultCount > 0) {
         result = m_scanResults[0];
      } else {
         ZeroMemory(result);
         result.pairName = "NO DATA";
         result.hurstExponent = 0.5;
         result.varianceRatio = 1.0;
         result.qualityScore = 0;
      }

      // ================ LEFT COLUMN ================

      // PANEL 1: Pairs Trading Dashboard
      int dashboardH = TITLE_HEIGHT + ROW_HEIGHT * 16 + 25;
      DrawDashboardPanel(x, y, DASHBOARD_WIDTH, dashboardH);

      // PANEL 2: Symbols (next to dashboard)
      int symbolsX = x + DASHBOARD_WIDTH + PANEL_GAP;
      int symbolsH = dashboardH;
      DrawSymbolsPanel(symbolsX, y, SYMBOLS_WIDTH, symbolsH);

      // PANEL 3: Spread Panel (below dashboard)
      int spreadY = y + dashboardH + PANEL_GAP;
      DrawSpreadPanel(x, spreadY, DASHBOARD_WIDTH + PANEL_GAP + SYMBOLS_WIDTH, SPREAD_HEIGHT, result);

      // PANEL 4: ICT Analysis Panel (below spread)
      int ictY = spreadY + SPREAD_HEIGHT + PANEL_GAP;
      DrawICTPanel(x, ictY, DASHBOARD_WIDTH + PANEL_GAP + SYMBOLS_WIDTH, ICT_HEIGHT);

      // ================ RIGHT COLUMN ================

      // PANEL 5: Position Calculator
      int calcX = symbolsX + SYMBOLS_WIDTH + PANEL_GAP + 50;
      int calcPartH = 280;  // Reduced height for calculator
      DrawPositionCalculator(calcX, y, CALC_WIDTH, calcPartH);

      // PANEL 6: Performance Metrics (below Position Calculator)
      int perfY = y + calcPartH + PANEL_GAP;
      int perfH = dashboardH + SPREAD_HEIGHT + ICT_HEIGHT + 2 * PANEL_GAP - calcPartH - PANEL_GAP;
      DrawPerformancePanel(calcX, perfY, CALC_WIDTH, perfH);

      // Update metrics periodically
      UpdateEquityHistory();
      CalculateRiskMetrics();
      CalculateVolatilityMetrics(m_calcSymbol);

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Draw Dashboard Panel (Pairs Trading Dashboard)                    |
   //+------------------------------------------------------------------+
   void DrawDashboardPanel(int x, int y, int w, int h) {
      // Panel background (isBackground=true for base layer)
      CreatePanel("DASH_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER, true);

      // Title bar (on top of background)
      CreatePanel("DASH_TITLE_BG", x, y, w, TITLE_HEIGHT, CLR_TITLE_BG, clrNONE, false);
      CreateLabel("DASH_TITLE", "Pairs Trading Dashboard - D-LOGIC 5.00",
                  x + 8, y + 4, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      // SCAN button
      CreateButton("BTN_SCAN", "SCAN", x + w - 50, y + 2, 45, 18,
                   CLR_BTN_GREEN, CLR_NEON_GREEN, FONT_SIZE_SMALL);

      // Column headers
      int headerY = y + TITLE_HEIGHT + 4;
      int cols[] = {5, 130, 155, 205, 260, 310};

      CreateLabel("H_PAIR", "Pair", x + cols[0], headerY, CLR_NEON_CYAN, FONT_SIZE_SMALL);
      CreateLabel("H_TF", "TF", x + cols[1], headerY, CLR_NEON_CYAN, FONT_SIZE_SMALL);
      CreateLabel("H_SPEARMAN", "Spearman", x + cols[2], headerY, CLR_NEON_CYAN, FONT_SIZE_SMALL);
      CreateLabel("H_ZSCORE", "Z-Score", x + cols[3], headerY, CLR_NEON_CYAN, FONT_SIZE_SMALL);
      CreateLabel("H_TYPE", "Type", x + cols[4], headerY, CLR_NEON_CYAN, FONT_SIZE_SMALL);
      CreateLabel("H_SIGNAL", "Signal", x + cols[5], headerY, CLR_NEON_CYAN, FONT_SIZE_SMALL);

      // Data rows
      int rowY = headerY + ROW_HEIGHT + 2;
      int maxRows = MathMin(15, m_resultCount);
      int posCount = 0, negCount = 0;

      for(int i = 0; i < maxRows; i++) {
         int idx = i + m_scrollOffset;
         if(idx >= m_resultCount) break;

         SPairResult r = m_scanResults[idx];
         string rowPfx = "R" + IntegerToString(i) + "_";
         bool isSelected = (idx == m_selectedRow);

         // Count positive/negative
         if(r.priceCorrelation >= 0) posCount++;
         else negCount++;

         // Row background
         color rowBg = isSelected ? CLR_ROW_SELECTED : (i % 2 == 0 ? CLR_ROW_EVEN : CLR_ROW_ODD);
         CreatePanel(rowPfx + "BG", x + 2, rowY - 1, w - 4, ROW_HEIGHT, rowBg);

         // Pair name (format: EURUSD-GBPUSD|H4)
         string pairDisplay = StringSubstr(r.symbolA, 0, 6) + "-" + StringSubstr(r.symbolB, 0, 6) + "|" + GetTFString(r.timeframe);
         color pairClr = isSelected ? CLR_NEON_CYAN : CLR_TEXT_WHITE;
         CreateLabel(rowPfx + "PAIR", pairDisplay, x + cols[0], rowY, pairClr, FONT_SIZE);

         // TF
         CreateLabel(rowPfx + "TF", GetTFString(r.timeframe), x + cols[1], rowY, CLR_TEXT_LIGHT, FONT_SIZE);

         // Spearman (price correlation)
         color spearClr = GetSpearmanColor(r.priceCorrelation);
         string spearStr = DoubleToString(r.priceCorrelation, 2);
         CreateLabel(rowPfx + "SPEAR", spearStr, x + cols[2], rowY, spearClr, FONT_SIZE, "Consolas Bold");

         // Z-Score
         color zClr = GetZScoreColor(r.zScore);
         string zStr = DoubleToString(r.zScore, 2);
         CreateLabel(rowPfx + "Z", zStr, x + cols[3], rowY, zClr, FONT_SIZE, "Consolas Bold");

         // Type (Pos/Neg based on correlation)
         string typeStr = r.priceCorrelation >= 0 ? "Pos" : "Neg";
         color typeClr = r.priceCorrelation >= 0 ? CLR_NEON_GREEN : CLR_NEON_RED;
         CreateLabel(rowPfx + "TYPE", typeStr, x + cols[4], rowY, typeClr, FONT_SIZE);

         // Signal
         string sigStr = GetSignalText(r.signal);
         color sigClr = r.signal == 0 ? CLR_TEXT_DIM :
                       (r.signal > 0 ? CLR_NEON_GREEN : CLR_NEON_RED);
         CreateLabel(rowPfx + "SIG", sigStr, x + cols[5], rowY, sigClr, FONT_SIZE);

         rowY += ROW_HEIGHT;
      }

      // Footer
      int footerY = y + h - 16;
      int signalCount = 0;
      for(int i = 0; i < m_resultCount; i++) {
         if(m_scanResults[i].signal != 0) signalCount++;
      }

      string footerText = "Pairs: " + IntegerToString(m_resultCount) +
                          " | Signals: " + IntegerToString(signalCount) +
                          " | Pos: " + IntegerToString(posCount) +
                          " | Neg: " + IntegerToString(negCount);
      CreateLabel("DASH_FOOTER", footerText, x + 8, footerY, CLR_TEXT_DIM, FONT_SIZE_SMALL);

      // Time
      CreateLabel("DASH_TIME", TimeToString(TimeCurrent(), TIME_SECONDS),
                  x + w - 70, footerY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
   }

   //+------------------------------------------------------------------+
   //| Draw Symbols Panel                                                |
   //+------------------------------------------------------------------+
   void DrawSymbolsPanel(int x, int y, int w, int h) {
      // Panel background (isBackground=true for base layer)
      CreatePanel("SYM_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER, true);

      // Title (on top)
      CreatePanel("SYM_TITLE_BG", x, y, w, TITLE_HEIGHT, CLR_TITLE_BG, clrNONE, false);
      CreateLabel("SYM_TITLE", "Symbols", x + 5, y + 4, CLR_TITLE_TEXT, FONT_SIZE_SMALL, "Consolas Bold");

      // Symbol buttons
      int btnY = y + TITLE_HEIGHT + 5;
      int btnH = 22;
      int btnGap = 3;

      for(int i = 0; i < m_symbolButtonCount; i++) {
         string btnName = "BTN_SYM_" + IntegerToString(i);
         string symName = m_symbolButtons[i];

         // Check if symbol exists with broker suffix
         string fullSym = symName;
         if(!SymbolSelect(symName, true)) {
            fullSym = symName + "+";
            if(!SymbolSelect(fullSym, true)) {
               fullSym = symName;
            }
         }

         CreateButton(btnName, symName, x + 3, btnY, w - 6, btnH,
                      CLR_BTN_GRAY, CLR_TEXT_WHITE, FONT_SIZE);

         btnY += btnH + btnGap;
      }
   }

   //+------------------------------------------------------------------+
   //| Draw Spread Panel                                                 |
   //+------------------------------------------------------------------+
   void DrawSpreadPanel(int x, int y, int w, int h, SPairResult &result) {
      // Panel background (isBackground=true for base layer)
      CreatePanel("SPR_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER, true);

      // Title bar (on top)
      CreatePanel("SPR_TITLE_BG", x, y, w, TITLE_HEIGHT, CLR_TITLE_BG, clrNONE, false);
      string spreadTitle = "Spread: " + m_spreadPairA + " / " + m_spreadPairB;
      if(m_spreadPairA == "") spreadTitle = "Spread: " + result.pairName;
      CreateLabel("SPR_TITLE", spreadTitle, x + 8, y + 4, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      // Minimize button
      CreateButton("BTN_SPR_MIN", "-", x + w - 22, y + 2, 18, 18,
                   CLR_BTN_GRAY, CLR_TEXT_WHITE, FONT_SIZE);

      // Stats line: Z | HR (Hurst) | LE (Half-Life as spread std)
      int statsY = y + TITLE_HEIGHT + 3;
      string statsText = "Z: " + DoubleToString(result.zScore, 2) +
                         " | HR: " + DoubleToString(result.hurstExponent, 4) +
                         " | LE: " + DoubleToString(result.spreadStdDev, 5);
      CreateLabel("SPR_STATS", statsText, x + 8, statsY, CLR_TEXT_LIGHT, FONT_SIZE);

      // Chart area (isBackground=true so points draw on top)
      int chartX = x + 8;
      int chartY = statsY + 18;
      int chartW = w - 55;
      int chartH = h - 55;

      CreatePanel("SPR_CHART_BG", chartX, chartY, chartW, chartH, CLR_CHART_BG, CLR_CHART_GRID, true);

      // Draw Z-Score levels (LE notation from screenshot)
      int midY = chartY + chartH / 2;
      int level1Y = chartY + chartH / 4;
      int level2Y = chartY + chartH * 3 / 4;
      int levelTopY = chartY + 5;
      int levelBotY = chartY + chartH - 10;

      // Level labels (using LE notation like in screenshot)
      int labelX = chartX + chartW + 5;
      CreateLabel("SPR_L2U", "+2LE", labelX, levelTopY, CLR_NEON_RED, 7);
      CreateLabel("SPR_L1U", "+1LE", labelX, level1Y - 3, CLR_NEON_ORANGE, 7);
      CreateLabel("SPR_MEAN", "Mean", labelX, midY - 3, CLR_NEON_YELLOW, 7);
      CreateLabel("SPR_L1L", "-1LE", labelX, level2Y - 3, CLR_NEON_ORANGE, 7);
      CreateLabel("SPR_L2L", "-2LE", labelX, levelBotY, CLR_NEON_GREEN, 7);

      // Draw spread line points
      DrawSpreadChart(chartX, chartY, chartW, chartH);

      // Legend
      int legendY = y + h - 14;
      CreateLabel("SPR_LEG", "Green=Oversold | Yellow=Mean | Red=Overbought",
                  x + 8, legendY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
   }

   //+------------------------------------------------------------------+
   //| Draw Spread Chart Points                                          |
   //+------------------------------------------------------------------+
   void DrawSpreadChart(int x, int y, int w, int h) {
      // Count all available data points
      int dataCount = MathMin(m_historySize, 50);

      // Check if we have any data at all
      bool hasData = false;
      for(int i = 0; i < dataCount; i++) {
         if(m_zScoreHistory[i] != 0) {
            hasData = true;
            break;
         }
      }

      // If no real data, just draw zero line indicator
      if(!hasData) {
         // Draw "No Data" message
         CreateLabel("SPR_NODATA", "Awaiting data...", x + w/2 - 40, y + h/2 - 5, CLR_TEXT_DIM, FONT_SIZE_SMALL);
         return;
      }

      // Hide no data message if we have data
      string noDataObj = m_prefix + "SPR_NODATA";
      if(ObjectFind(0, noDataObj) >= 0) {
         ObjectSetString(0, noDataObj, OBJPROP_TEXT, "");
      }

      // Fixed range for Z-Score (-3 to +3)
      double minZ = -3.0;
      double maxZ = 3.0;
      double range = 6.0;

      // Draw horizontal grid lines for Z-Score levels
      int zeroY = y + h / 2;
      int plus1Y = y + h / 2 - (int)(h / 6);
      int plus2Y = y + h / 2 - (int)(h / 3);
      int minus1Y = y + h / 2 + (int)(h / 6);
      int minus2Y = y + h / 2 + (int)(h / 3);

      // Draw grid lines (thin horizontal lines)
      CreatePanel("SPR_GRID_0", x + 2, zeroY, w - 4, 1, CLR_NEON_YELLOW);
      CreatePanel("SPR_GRID_P1", x + 2, plus1Y, w - 4, 1, C'60,60,60');
      CreatePanel("SPR_GRID_P2", x + 2, plus2Y, w - 4, 1, C'60,60,60');
      CreatePanel("SPR_GRID_M1", x + 2, minus1Y, w - 4, 1, C'60,60,60');
      CreatePanel("SPR_GRID_M2", x + 2, minus2Y, w - 4, 1, C'60,60,60');

      // Draw points with connecting bars
      double stepX = (double)(w - 10) / MathMax(dataCount - 1, 1);

      for(int i = 0; i < dataCount; i++) {
         int idx = dataCount - 1 - i;  // Newest on right
         double z = m_zScoreHistory[idx];

         // Clamp Z-Score to range
         z = MathMax(-3.0, MathMin(3.0, z));

         int px = x + 5 + (int)(i * stepX);
         int py = y + (int)((maxZ - z) / range * h);
         py = MathMax(y + 2, MathMin(y + h - 4, py));

         color ptClr = GetZScoreColor(m_zScoreHistory[idx]);

         // Draw larger point (4x4 for better visibility)
         CreatePanel("SPR_P" + IntegerToString(i), px - 2, py - 2, 4, 4, ptClr);

         // Draw vertical bar from zero line to point
         int barTop = MathMin(py, zeroY);
         int barHeight = MathAbs(py - zeroY);
         if(barHeight > 1) {
            color barClr = (m_zScoreHistory[idx] > 0) ? C'80,40,40' : C'40,80,40';
            CreatePanel("SPR_BAR" + IntegerToString(i), px - 1, barTop, 2, barHeight, barClr);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Draw ICT Analysis Panel                                           |
   //+------------------------------------------------------------------+
   void DrawICTPanel(int x, int y, int w, int h) {
      // Panel background (isBackground=true for base layer)
      CreatePanel("ICT_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER, true);

      // Title bar (on top)
      CreatePanel("ICT_TITLE_BG", x, y, w, TITLE_HEIGHT, CLR_TITLE_BG, clrNONE, false);
      string ictTitle = "ICT Analysis - " + m_ictSymbol;
      CreateLabel("ICT_TITLE", ictTitle, x + 8, y + 4, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      // Draw and Minimize buttons
      CreateButton("BTN_ICT_DRAW", "Draw", x + w - 70, y + 2, 40, 18,
                   CLR_BTN_BLUE, CLR_NEON_CYAN, FONT_SIZE_SMALL);
      CreateButton("BTN_ICT_MIN", "-", x + w - 22, y + 2, 18, 18,
                   CLR_BTN_GRAY, CLR_TEXT_WHITE, FONT_SIZE);

      int contentY = y + TITLE_HEIGHT + 8;
      int col1 = x + 10;
      int col2 = x + 100;

      // --- SESSIONS ---
      CreateLabel("ICT_SESS_H", "--- SESSIONS ---", col1, contentY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      contentY += 16;

      // ASIA
      bool asiaActive = IsSessionActive(SESSION_ASIA);
      string asiaStatus = asiaActive ? "ACTIVE" : "Closed";
      color asiaClr = asiaActive ? CLR_NEON_BLUE : CLR_TEXT_DIM;
      CreateLabel("ICT_ASIA_L", "ASIA:", col1, contentY, CLR_NEON_BLUE, FONT_SIZE);
      CreateLabel("ICT_ASIA_V", asiaStatus, col2, contentY, asiaClr, FONT_SIZE);
      CreateLabel("ICT_ASIA_LBL", "Label", col2 + 55, contentY, CLR_NEON_CYAN, FONT_SIZE);
      contentY += 14;

      // LONDON
      bool londonActive = IsSessionActive(SESSION_LONDON);
      string londonStatus = londonActive ? "ACTIVE" : "Closed";
      color londonClr = londonActive ? CLR_NEON_GREEN : CLR_TEXT_DIM;
      CreateLabel("ICT_LONDON_L", "LONDON:", col1, contentY, CLR_NEON_GREEN, FONT_SIZE);
      CreateLabel("ICT_LONDON_V", londonStatus, col2, contentY, londonClr, FONT_SIZE);
      CreateLabel("ICT_LONDON_LBL", "Label", col2 + 55, contentY, CLR_NEON_CYAN, FONT_SIZE);
      contentY += 14;

      // NEW YORK
      bool nyActive = IsSessionActive(SESSION_NEW_YORK);
      string nyStatus = nyActive ? "ACTIVE" : "Closed";
      color nyClr = nyActive ? CLR_NEON_ORANGE : CLR_TEXT_DIM;
      CreateLabel("ICT_NY_L", "NEW YORK:", col1, contentY, CLR_NEON_ORANGE, FONT_SIZE);
      CreateLabel("ICT_NY_V", nyStatus, col2, contentY, nyClr, FONT_SIZE);
      CreateLabel("ICT_NY_LBL", "Label", col2 + 55, contentY, CLR_NEON_CYAN, FONT_SIZE);
      contentY += 20;

      // --- ICT PATTERNS ---
      CreateLabel("ICT_PAT_H", "--- ICT PATTERNS ---", col1, contentY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      contentY += 16;

      // Fair Value Gaps
      CreateLabel("ICT_FVG_L", "Fair Value Gaps:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("ICT_FVG_V", IntegerToString(m_ictPattern.fairValueGaps) + " active",
                  col2 + 30, contentY, CLR_NEON_CYAN, FONT_SIZE);
      contentY += 14;

      // Order Blocks
      CreateLabel("ICT_OB_L", "Order Blocks:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("ICT_OB_V", IntegerToString(m_ictPattern.orderBlocks) + " active",
                  col2 + 30, contentY, CLR_NEON_CYAN, FONT_SIZE);
   }

   //+------------------------------------------------------------------+
   //| Draw Position Calculator Panel                                    |
   //+------------------------------------------------------------------+
   void DrawPositionCalculator(int x, int y, int w, int h) {
      // Panel background (isBackground=true for base layer)
      CreatePanel("CALC_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER, true);

      // Title bar (on top)
      CreatePanel("CALC_TITLE_BG", x, y, w, TITLE_HEIGHT, CLR_TITLE_BG, clrNONE, false);
      CreateLabel("CALC_TITLE", "Position Calculator", x + 8, y + 4, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      int contentY = y + TITLE_HEIGHT + 8;
      int col1 = x + 8;
      int col2 = x + 100;
      int inputW = 90;
      int rowH = 22;

      // --- INPUTS ---
      CreateLabel("CALC_INP_H", "--- INPUTS ---", col1, contentY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      contentY += 16;

      // Symbol
      CreateLabel("CALC_SYM_L", "Symbol:", col1, contentY + 2, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateButton("CALC_SYM_V", m_calcSymbol, col2, contentY, inputW, 18,
                   CLR_CHART_BG, CLR_NEON_CYAN, FONT_SIZE);
      contentY += rowH;

      // Risk %
      CreateLabel("CALC_RISK_L", "Risk %:", col1, contentY + 2, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateEdit("CALC_RISK_V", DoubleToString(m_calcRiskPercent, 2), col2, contentY, inputW, 18,
                 CLR_CHART_BG, CLR_TEXT_WHITE, FONT_SIZE);
      contentY += rowH;

      // Stop Loss (pips)
      CreateLabel("CALC_SL_L", "Stop Loss (pips):", col1, contentY + 2, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateEdit("CALC_SL_V", DoubleToString(m_calcStopLossPips, 1), col2, contentY, inputW, 18,
                 CLR_CHART_BG, CLR_TEXT_WHITE, FONT_SIZE);
      contentY += rowH;

      // Take Profit (pips)
      CreateLabel("CALC_TP_L", "Take Profit (pips):", col1, contentY + 2, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateEdit("CALC_TP_V", DoubleToString(m_calcTakeProfitPips, 1), col2, contentY, inputW, 18,
                 CLR_CHART_BG, CLR_TEXT_WHITE, FONT_SIZE);
      contentY += rowH + 5;

      // BUY / SELL / CALCULATE buttons
      int btnW = (w - 24) / 3;
      CreateButton("BTN_CALC_BUY", "BUY", col1, contentY, btnW, 20,
                   CLR_NEON_GREEN, CLR_PANEL_BG, FONT_SIZE);
      CreateButton("BTN_CALC_SELL", "SELL", col1 + btnW + 4, contentY, btnW, 20,
                   CLR_NEON_RED, CLR_TEXT_WHITE, FONT_SIZE);
      CreateButton("BTN_CALC_CALC", "CALCULATE", col1 + 2 * (btnW + 4), contentY, btnW, 20,
                   CLR_BTN_BLUE, CLR_NEON_CYAN, FONT_SIZE_SMALL);
      contentY += 28;

      // --- RESULTS ---
      CreateLabel("CALC_RES_H", "--- RESULTS ---", col1, contentY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      contentY += 16;

      // Calculate position if we have a symbol
      if(m_calcSymbol != "") {
         CalculatePosition();
      }

      int resCol2 = x + 115;
      int resRowH = 16;

      // Position Size
      CreateLabel("CALC_POS_L", "Position Size:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_POS_V", DoubleToString(m_calcResult.positionSize, 2) + " lots",
                  resCol2, contentY, CLR_NEON_CYAN, FONT_SIZE, "Consolas Bold");
      contentY += resRowH;

      // Risk Amount
      CreateLabel("CALC_RAMT_L", "Risk Amount:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      string accCur = AccountInfoString(ACCOUNT_CURRENCY);
      CreateLabel("CALC_RAMT_V", DoubleToString(m_calcResult.riskAmount, 2) + " " + accCur,
                  resCol2, contentY, CLR_NEON_YELLOW, FONT_SIZE);
      contentY += resRowH;

      // Entry Price
      CreateLabel("CALC_ENT_L", "Entry Price:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_ENT_V", DoubleToString(m_calcResult.entryPrice, 5),
                  resCol2, contentY, CLR_TEXT_WHITE, FONT_SIZE);
      contentY += resRowH;

      // Stop Loss
      CreateLabel("CALC_SLP_L", "Stop Loss:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_SLP_V", DoubleToString(m_calcResult.stopLoss, 5),
                  resCol2, contentY, CLR_NEON_RED, FONT_SIZE);
      contentY += resRowH;

      // Take Profit
      CreateLabel("CALC_TPP_L", "Take Profit:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_TPP_V", DoubleToString(m_calcResult.takeProfit, 5),
                  resCol2, contentY, CLR_NEON_GREEN, FONT_SIZE);
      contentY += resRowH;

      // Potential Loss
      CreateLabel("CALC_PLOSS_L", "Potential Loss:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_PLOSS_V", DoubleToString(m_calcResult.potentialLoss, 2) + " " + accCur,
                  resCol2, contentY, CLR_NEON_RED, FONT_SIZE);
      contentY += resRowH;

      // Potential Profit
      CreateLabel("CALC_PPROF_L", "Potential Profit:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_PPROF_V", "+" + DoubleToString(m_calcResult.potentialProfit, 2) + " " + accCur,
                  resCol2, contentY, CLR_NEON_GREEN, FONT_SIZE);
      contentY += resRowH;

      // Risk/Reward
      CreateLabel("CALC_RR_L", "Risk/Reward:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_RR_V", "1:" + DoubleToString(m_calcResult.riskReward, 2),
                  resCol2, contentY, CLR_NEON_CYAN, FONT_SIZE);
      contentY += resRowH;

      // Margin Required
      CreateLabel("CALC_MAR_L", "Margin Required:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_MAR_V", DoubleToString(m_calcResult.marginRequired, 2) + " " + accCur,
                  resCol2, contentY, CLR_TEXT_WHITE, FONT_SIZE);
      contentY += resRowH;

      // Pip Value
      CreateLabel("CALC_PIP_L", "Pip Value:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_PIP_V", DoubleToString(m_calcResult.pipValue, 2) + " " + accCur + "/pip",
                  resCol2, contentY, CLR_TEXT_WHITE, FONT_SIZE);
      contentY += resRowH + 8;

      // Insufficient margin warning
      if(m_calcResult.insufficientMargin) {
         CreatePanel("CALC_WARN_BG", col1, contentY, w - 16, 18, CLR_NEON_RED);
         CreateLabel("CALC_WARN", "Insufficient margin!", col1 + 10, contentY + 2,
                     CLR_TEXT_WHITE, FONT_SIZE, "Consolas Bold");
      }
   }

   //+------------------------------------------------------------------+
   //| Draw Performance Metrics Panel (GS Quant / ffn style)             |
   //+------------------------------------------------------------------+
   void DrawPerformancePanel(int x, int y, int w, int h) {
      // Panel background (solid)
      CreatePanel("PERF_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER, true);

      // Title bar
      CreatePanel("PERF_TITLE_BG", x, y, w, TITLE_HEIGHT, CLR_TITLE_BG, clrNONE, false);
      CreateLabel("PERF_TITLE", "Performance Metrics", x + 8, y + 4, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      int contentY = y + TITLE_HEIGHT + 6;
      int col1 = x + 8;
      int col2 = x + 110;
      int rowH = 13;

      // --- RISK-ADJUSTED RETURNS ---
      CreateLabel("PERF_RAR_H", "--- RISK ADJUSTED ---", col1, contentY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      contentY += 14;

      // Sharpe Ratio
      color sharpeClr = m_perfStats.sharpeRatio > 1.0 ? CLR_NEON_GREEN :
                       (m_perfStats.sharpeRatio > 0 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_SHARPE_L", "Sharpe Ratio:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_SHARPE_V", DoubleToString(m_perfStats.sharpeRatio, 2),
                  col2, contentY, sharpeClr, FONT_SIZE, "Consolas Bold");
      contentY += rowH;

      // Sortino Ratio
      color sortinoClr = m_perfStats.sortinoRatio > 1.5 ? CLR_NEON_GREEN :
                        (m_perfStats.sortinoRatio > 0 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_SORTINO_L", "Sortino Ratio:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_SORTINO_V", DoubleToString(m_perfStats.sortinoRatio, 2),
                  col2, contentY, sortinoClr, FONT_SIZE, "Consolas Bold");
      contentY += rowH;

      // Calmar Ratio
      color calmarClr = m_perfStats.calmarRatio > 2.0 ? CLR_NEON_GREEN :
                       (m_perfStats.calmarRatio > 0.5 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_CALMAR_L", "Calmar Ratio:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_CALMAR_V", DoubleToString(m_perfStats.calmarRatio, 2),
                  col2, contentY, calmarClr, FONT_SIZE, "Consolas Bold");
      contentY += rowH + 4;

      // --- DRAWDOWN ---
      CreateLabel("PERF_DD_H", "--- DRAWDOWN ---", col1, contentY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      contentY += 14;

      // Max Drawdown
      color ddClr = m_perfStats.maxDrawdown < 5.0 ? CLR_NEON_GREEN :
                   (m_perfStats.maxDrawdown < 15.0 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_MDD_L", "Max DD:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_MDD_V", DoubleToString(m_perfStats.maxDrawdown, 2) + "%",
                  col2, contentY, ddClr, FONT_SIZE, "Consolas Bold");
      contentY += rowH;

      // Current Drawdown
      color cddClr = m_perfStats.currentDrawdown < 2.0 ? CLR_NEON_GREEN :
                    (m_perfStats.currentDrawdown < 8.0 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_CDD_L", "Current DD:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_CDD_V", DoubleToString(m_perfStats.currentDrawdown, 2) + "%",
                  col2, contentY, cddClr, FONT_SIZE);
      contentY += rowH;

      // Ulcer Index
      CreateLabel("PERF_ULCER_L", "Ulcer Index:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_ULCER_V", DoubleToString(m_perfStats.ulcerIndex, 2),
                  col2, contentY, CLR_TEXT_WHITE, FONT_SIZE);
      contentY += rowH + 4;

      // --- VOLATILITY ---
      CreateLabel("PERF_VOL_H", "--- VOLATILITY ---", col1, contentY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      contentY += 14;

      // Annualized Vol
      CreateLabel("PERF_AVOL_L", "Ann. Vol:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_AVOL_V", DoubleToString(m_perfStats.annualizedVol, 1) + "%",
                  col2, contentY, CLR_TEXT_WHITE, FONT_SIZE);
      contentY += rowH;

      // Vol Regime
      string volRegimeStr = "";
      color volRegimeClr = CLR_TEXT_WHITE;
      switch((int)m_volMetrics.volRegime) {
         case 0: volRegimeStr = "LOW"; volRegimeClr = CLR_NEON_GREEN; break;
         case 1: volRegimeStr = "NORMAL"; volRegimeClr = CLR_NEON_CYAN; break;
         case 2: volRegimeStr = "HIGH"; volRegimeClr = CLR_NEON_ORANGE; break;
         case 3: volRegimeStr = "EXTREME"; volRegimeClr = CLR_NEON_RED; break;
      }
      CreateLabel("PERF_VREG_L", "Vol Regime:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_VREG_V", volRegimeStr, col2, contentY, volRegimeClr, FONT_SIZE, "Consolas Bold");
      contentY += rowH;

      // ATR
      CreateLabel("PERF_ATR_L", "ATR(14):", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_ATR_V", DoubleToString(m_volMetrics.atr14, 5),
                  col2, contentY, CLR_TEXT_WHITE, FONT_SIZE);
      contentY += rowH + 4;

      // --- STATISTICS ---
      CreateLabel("PERF_STAT_H", "--- STATISTICS ---", col1, contentY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      contentY += 14;

      // Win Rate
      color winRateClr = m_perfStats.winRate > 50.0 ? CLR_NEON_GREEN :
                        (m_perfStats.winRate > 40.0 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_WIN_L", "Win Rate:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_WIN_V", DoubleToString(m_perfStats.winRate, 1) + "%",
                  col2, contentY, winRateClr, FONT_SIZE, "Consolas Bold");
      contentY += rowH;

      // Profit Factor
      color pfClr = m_perfStats.profitFactor > 1.5 ? CLR_NEON_GREEN :
                   (m_perfStats.profitFactor > 1.0 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_PF_L", "Profit Factor:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_PF_V", DoubleToString(m_perfStats.profitFactor, 2),
                  col2, contentY, pfClr, FONT_SIZE, "Consolas Bold");
      contentY += rowH;

      // Total Trades
      CreateLabel("PERF_TRADES_L", "Trades:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_TRADES_V", IntegerToString(m_perfStats.executedTrades) +
                  " (" + IntegerToString(m_perfStats.winningTrades) + "W/" +
                  IntegerToString(m_perfStats.losingTrades) + "L)",
                  col2, contentY, CLR_TEXT_WHITE, FONT_SIZE);
      contentY += rowH;

      // Recovery Factor
      color rfClr = m_perfStats.recoveryFactor > 2.0 ? CLR_NEON_GREEN :
                   (m_perfStats.recoveryFactor > 1.0 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_RF_L", "Recovery F.:", col1, contentY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("PERF_RF_V", DoubleToString(m_perfStats.recoveryFactor, 2),
                  col2, contentY, rfClr, FONT_SIZE);
   }

   //+------------------------------------------------------------------+
   //| Handle Click - returns action code and fills pair info            |
   //+------------------------------------------------------------------+
   int HandleClick(string objName, string &symbolA, string &symbolB, double &beta) {
      if(StringFind(objName, m_prefix) < 0) return 0;

      string name = StringSubstr(objName, StringLen(m_prefix));

      // Main buttons
      if(name == "BTN_SCAN") return 1;
      if(name == "BTN_CALC_CALC") {
         // Read input values and recalculate
         ReadCalculatorInputs();
         CalculatePosition();
         Draw();
         return 0;
      }
      if(name == "BTN_CALC_BUY") {
         m_calcIsBuy = true;
         CalculatePosition();
         Draw();
         return 0;
      }
      if(name == "BTN_CALC_SELL") {
         m_calcIsBuy = false;
         CalculatePosition();
         Draw();
         return 0;
      }
      if(name == "BTN_ICT_DRAW") {
         // Toggle ICT drawing (placeholder)
         return 5;
      }

      // Symbol buttons
      for(int i = 0; i < m_symbolButtonCount; i++) {
         if(name == "BTN_SYM_" + IntegerToString(i)) {
            string sym = m_symbolButtons[i];
            // Try to find with broker suffix
            if(SymbolSelect(sym, true)) {
               m_calcSymbol = sym;
               m_ictSymbol = sym;
            } else if(SymbolSelect(sym + "+", true)) {
               m_calcSymbol = sym + "+";
               m_ictSymbol = sym + "+";
            }
            CalculatePosition();
            Draw();
            return 0;
         }
      }

      // Row selection
      for(int i = 0; i < 15; i++) {
         if(StringFind(name, "R" + IntegerToString(i) + "_") >= 0) {
            int newSel = i + m_scrollOffset;
            if(newSel < m_resultCount) {
               m_selectedRow = newSel;
               symbolA = m_scanResults[m_selectedRow].symbolA;
               symbolB = m_scanResults[m_selectedRow].symbolB;
               beta = m_scanResults[m_selectedRow].beta;

               // Update spread pair display
               m_spreadPairA = symbolA;
               m_spreadPairB = symbolB;

               if(m_resultCount > 0) {
                  m_currentRegime = DetectRegime(m_scanResults[m_selectedRow]);
                  m_signalStrength = CalculateSignalStrength(m_scanResults[m_selectedRow]);
               }
               return 4;
            }
         }
      }

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Read Calculator Input Values                                      |
   //+------------------------------------------------------------------+
   void ReadCalculatorInputs() {
      string riskStr = ObjectGetString(0, m_prefix + "CALC_RISK_V", OBJPROP_TEXT);
      string slStr = ObjectGetString(0, m_prefix + "CALC_SL_V", OBJPROP_TEXT);
      string tpStr = ObjectGetString(0, m_prefix + "CALC_TP_V", OBJPROP_TEXT);

      if(riskStr != "") m_calcRiskPercent = StringToDouble(riskStr);
      if(slStr != "") m_calcStopLossPips = StringToDouble(slStr);
      if(tpStr != "") m_calcTakeProfitPips = StringToDouble(tpStr);

      // Clamp values
      m_calcRiskPercent = MathMax(0.1, MathMin(10.0, m_calcRiskPercent));
      m_calcStopLossPips = MathMax(1.0, MathMin(1000.0, m_calcStopLossPips));
      m_calcTakeProfitPips = MathMax(1.0, MathMin(2000.0, m_calcTakeProfitPips));
   }

   //+------------------------------------------------------------------+
   //| Get Selected Pair (SPairResult version)                           |
   //+------------------------------------------------------------------+
   bool GetSelectedPair(SPairResult &result) {
      if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
         result = m_scanResults[m_selectedRow];
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Get Selected Pair (4 parameter version)                           |
   //+------------------------------------------------------------------+
   bool GetSelectedPair(string &symbolA, string &symbolB, double &beta, double &zScore) {
      if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
         symbolA = m_scanResults[m_selectedRow].symbolA;
         symbolB = m_scanResults[m_selectedRow].symbolB;
         beta = m_scanResults[m_selectedRow].beta;
         zScore = m_scanResults[m_selectedRow].zScore;
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Configure Alerts                                                  |
   //+------------------------------------------------------------------+
   void ConfigureAlerts(bool enabled, double zThreshold, double strengthThreshold) {
      m_alertsEnabled = enabled;
      m_alertZThreshold = zThreshold;
      m_alertStrengthThreshold = strengthThreshold;
   }

   //+------------------------------------------------------------------+
   //| Are Alerts Enabled                                                |
   //+------------------------------------------------------------------+
   bool AreAlertsEnabled() {
      return m_alertsEnabled;
   }

   //+------------------------------------------------------------------+
   //| Sort By Z-Score                                                   |
   //+------------------------------------------------------------------+
   void SortByZScore() {
      for(int i = 0; i < m_resultCount - 1; i++) {
         for(int j = 0; j < m_resultCount - i - 1; j++) {
            if(MathAbs(m_scanResults[j].zScore) < MathAbs(m_scanResults[j + 1].zScore)) {
               SPairResult temp = m_scanResults[j];
               m_scanResults[j] = m_scanResults[j + 1];
               m_scanResults[j + 1] = temp;
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Record Trade Result                                               |
   //+------------------------------------------------------------------+
   void RecordTradeResult(double profit) {
      bool isWin = profit >= 0;
      AddTradeResult(profit, isWin);
   }

   //+------------------------------------------------------------------+
   //| Add Trade Result                                                  |
   //+------------------------------------------------------------------+
   void AddTradeResult(double profit, bool isWin) {
      m_perfStats.executedTrades++;
      m_perfStats.totalPL += profit;

      if(isWin) {
         m_perfStats.winningTrades++;
         m_perfStats.grossProfit += profit;
      } else {
         m_perfStats.losingTrades++;
         m_perfStats.grossLoss += MathAbs(profit);
      }

      m_perfStats.winRate = m_perfStats.executedTrades > 0 ?
         (double)m_perfStats.winningTrades / m_perfStats.executedTrades * 100 : 0;

      m_perfStats.profitFactor = m_perfStats.grossLoss > 0 ?
         m_perfStats.grossProfit / m_perfStats.grossLoss : 1.0;
   }

   //+------------------------------------------------------------------+
   //| Update Info                                                       |
   //+------------------------------------------------------------------+
   void UpdateInfo(double unrealizedPL, int positionCount, double maxDD, double activeBeta) {
      m_perfStats.maxDrawdown = maxDD;
   }

   //+------------------------------------------------------------------+
   //| Toggle Visibility                                                 |
   //+------------------------------------------------------------------+
   void ToggleVisibility() {
      m_isVisible = !m_isVisible;
      if(m_isVisible) {
         Draw();
      } else {
         DeleteAll();
         ChartRedraw(0);
      }
   }

   //+------------------------------------------------------------------+
   //| Is Visible                                                        |
   //+------------------------------------------------------------------+
   bool IsVisible() {
      return m_isVisible;
   }

   //+------------------------------------------------------------------+
   //| Get Signal Strength                                               |
   //+------------------------------------------------------------------+
   double GetSignalStrength() {
      return m_signalStrength;
   }

   //+------------------------------------------------------------------+
   //| Record Signal                                                     |
   //+------------------------------------------------------------------+
   void RecordSignal(string pairName, int signal, double zScore, double strength) {
      if(m_historyCount >= m_maxHistory) {
         for(int i = m_maxHistory - 1; i > 0; i--) {
            m_signalHistory[i] = m_signalHistory[i - 1];
         }
         m_historyCount = m_maxHistory;
      } else {
         m_historyCount++;
      }

      for(int i = m_historyCount - 1; i > 0; i--) {
         m_signalHistory[i] = m_signalHistory[i - 1];
      }

      m_signalHistory[0].time = TimeCurrent();
      m_signalHistory[0].pairName = pairName;
      m_signalHistory[0].signal = signal;
      m_signalHistory[0].zScore = zScore;
      m_signalHistory[0].strength = strength;
      m_signalHistory[0].executed = false;
      m_signalHistory[0].entryPL = 0;

      m_perfStats.totalSignals++;
   }

   //+------------------------------------------------------------------+
   //| Reset Stats                                                       |
   //+------------------------------------------------------------------+
   void ResetStats() {
      ZeroMemory(m_perfStats);
      m_perfStats.profitFactor = 1.0;
      m_historyCount = 0;
   }

   //+------------------------------------------------------------------+
   //| Get Top Pairs                                                     |
   //+------------------------------------------------------------------+
   int GetTopPairs(string &pairs[], int maxPairs = 6) {
      int count = MathMin(maxPairs, m_resultCount);
      ArrayResize(pairs, count);

      for(int i = 0; i < count; i++) {
         pairs[i] = m_scanResults[i].pairName;
      }

      return count;
   }

   //+------------------------------------------------------------------+
   //| Set ICT Pattern Data                                              |
   //+------------------------------------------------------------------+
   void SetICTPatterns(int fvgCount, int obCount) {
      m_ictPattern.fairValueGaps = fvgCount;
      m_ictPattern.orderBlocks = obCount;
   }

   //+------------------------------------------------------------------+
   //| Set Calculator Symbol                                             |
   //+------------------------------------------------------------------+
   void SetCalcSymbol(string symbol) {
      m_calcSymbol = symbol;
      m_ictSymbol = symbol;
   }
};

//+------------------------------------------------------------------+
