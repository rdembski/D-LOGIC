//+------------------------------------------------------------------+
//|                                           DLogic_Dashboard.mqh   |
//|              D-LOGIC Professional Pairs Trading Dashboard         |
//|                                        Author: Rafał Dembski     |
//|                                                                   |
//|  Original Layout Design v5.00                                     |
//|  - Pairs Trading Dashboard (with TF, Spearman, Type columns)      |
//|  - Symbols Panel (currency pair buttons)                          |
//|  - Spread Panel (with LE levels notation)                         |
//|  - ICT Analysis Panel (Sessions + ICT Patterns)                   |
//|  - Position Calculator Panel (full calculator)                    |
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
   int        totalSignals;
   int        executedTrades;
   int        winningTrades;
   int        losingTrades;
   double     totalPL;
   double     grossProfit;
   double     grossLoss;
   double     maxDrawdown;
   double     sharpeRatio;
   double     winRate;
   double     profitFactor;
   double     avgWin;
   double     avgLoss;
   double     expectancy;
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
      }

      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, objName, OBJPROP_FONT, font);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   }

   //+------------------------------------------------------------------+
   //| Create Rectangle Panel                                            |
   //+------------------------------------------------------------------+
   void CreatePanel(string name, int x, int y, int w, int h,
                    color bgClr, color borderClr = clrNONE) {
      string objName = m_prefix + name;

      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      }

      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);

      if(borderClr != clrNONE) {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, borderClr);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      } else {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, bgClr);
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
      }

      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, txtClr);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, CLR_PANEL_BORDER);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetString(0, objName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   }

   //+------------------------------------------------------------------+
   //| Create Edit Box                                                   |
   //+------------------------------------------------------------------+
   void CreateEdit(string name, string text, int x, int y, int w, int h,
                   color bgClr, color txtClr, int fontSize = FONT_SIZE) {
      string objName = m_prefix + name;

      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_EDIT, 0, 0, 0);
      }

      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, txtClr);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, CLR_PANEL_BORDER);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetString(0, objName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_ALIGN, ALIGN_RIGHT);
      ObjectSetInteger(0, objName, OBJPROP_READONLY, false);
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
      OrderCalcMargin(orderType, m_calcSymbol, m_calcResult.positionSize, price, marginRequired);
      m_calcResult.marginRequired = marginRequired;

      // Pip value
      m_calcResult.pipValue = pipsValue;

      // Check margin
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      m_calcResult.insufficientMargin = (marginRequired > freeMargin * 0.9);
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
      int calcH = dashboardH + PANEL_GAP + SPREAD_HEIGHT + PANEL_GAP + ICT_HEIGHT;
      DrawPositionCalculator(calcX, y, CALC_WIDTH, calcH);

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Draw Dashboard Panel (Pairs Trading Dashboard)                    |
   //+------------------------------------------------------------------+
   void DrawDashboardPanel(int x, int y, int w, int h) {
      // Panel background
      CreatePanel("DASH_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title bar
      CreatePanel("DASH_TITLE_BG", x, y, w, TITLE_HEIGHT, CLR_TITLE_BG);
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
      // Panel background
      CreatePanel("SYM_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title
      CreatePanel("SYM_TITLE_BG", x, y, w, TITLE_HEIGHT, CLR_TITLE_BG);
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
      // Panel background
      CreatePanel("SPR_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title bar
      CreatePanel("SPR_TITLE_BG", x, y, w, TITLE_HEIGHT, CLR_TITLE_BG);
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

      // Chart area
      int chartX = x + 8;
      int chartY = statsY + 18;
      int chartW = w - 55;
      int chartH = h - 55;

      CreatePanel("SPR_CHART_BG", chartX, chartY, chartW, chartH, CLR_CHART_BG, CLR_CHART_GRID);

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
      // Find valid data range
      int validCount = 0;
      double minZ = 999, maxZ = -999;

      for(int i = 0; i < m_historySize && i < 50; i++) {
         if(m_zScoreHistory[i] != 0 || i == 0) {
            minZ = MathMin(minZ, m_zScoreHistory[i]);
            maxZ = MathMax(maxZ, m_zScoreHistory[i]);
            validCount++;
         }
      }

      if(validCount < 5) return;

      // Ensure range (-3 to +3 typically)
      double range = MathMax(6.0, maxZ - minZ);
      double mid = 0;  // Center on zero for Z-Score
      minZ = mid - range / 2;
      maxZ = mid + range / 2;

      // Draw points
      int pointCount = MathMin(validCount, 50);
      double stepX = (double)(w - 10) / pointCount;

      for(int i = 0; i < pointCount; i++) {
         int idx = pointCount - 1 - i;
         double z = m_zScoreHistory[idx];

         int px = x + 5 + (int)(i * stepX);
         int py = y + 5 + (int)((maxZ - z) / range * (h - 10));
         py = MathMax(y + 2, MathMin(y + h - 2, py));

         color ptClr = GetZScoreColor(z);
         CreatePanel("SPR_P" + IntegerToString(i), px, py, 3, 3, ptClr);
      }
   }

   //+------------------------------------------------------------------+
   //| Draw ICT Analysis Panel                                           |
   //+------------------------------------------------------------------+
   void DrawICTPanel(int x, int y, int w, int h) {
      // Panel background
      CreatePanel("ICT_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title bar
      CreatePanel("ICT_TITLE_BG", x, y, w, TITLE_HEIGHT, CLR_TITLE_BG);
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
      // Panel background
      CreatePanel("CALC_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title bar
      CreatePanel("CALC_TITLE_BG", x, y, w, TITLE_HEIGHT, CLR_TITLE_BG);
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
