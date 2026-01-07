//+------------------------------------------------------------------+
//|                                           DLogic_Dashboard.mqh   |
//|              D-LOGIC Professional Pairs Trading Dashboard         |
//|                                        Author: Rafał Dembski     |
//|                                                                   |
//|  Professional Dashboard v5.00                                     |
//|  - Scanner Panel (full pairs table)                               |
//|  - Spread Panel (Z-Score chart)                                   |
//|  - ICT Analysis Panel (Sessions + Patterns)                       |
//|  - Position Calculator (right side)                               |
//+------------------------------------------------------------------+
#property copyright "Rafał Dembski"
#property strict

#include "DLogic_Engine.mqh"

// ============================================================
// COLOR SCHEME - PROFESSIONAL DARK
// ============================================================
#define CLR_PANEL_BG       C'20,22,28'      // Dark panel background
#define CLR_PANEL_BORDER   C'50,55,70'      // Panel border
#define CLR_TITLE_BG       C'30,80,120'     // Title bar (blue)
#define CLR_TITLE_TEXT     C'220,230,255'   // Title text

#define CLR_GREEN          C'0,255,100'     // Green
#define CLR_RED            C'255,80,80'     // Red
#define CLR_CYAN           C'0,200,255'     // Cyan
#define CLR_YELLOW         C'255,220,0'     // Yellow
#define CLR_ORANGE         C'255,150,50'    // Orange
#define CLR_PURPLE         C'180,100,255'   // Purple
#define CLR_BLUE           C'100,150,255'   // Blue

#define CLR_TEXT_WHITE     C'255,255,255'   // White
#define CLR_TEXT_LIGHT     C'180,190,210'   // Light gray
#define CLR_TEXT_DIM       C'120,130,150'   // Dim gray

#define CLR_ROW_EVEN       C'25,28,35'      // Even row
#define CLR_ROW_ODD        C'30,33,42'      // Odd row
#define CLR_ROW_SELECTED   C'40,60,90'      // Selected row

#define CLR_INPUT_BG       C'35,40,50'      // Input background
#define CLR_BTN_BUY        C'40,120,80'     // Buy button
#define CLR_BTN_SELL       C'120,50,50'     // Sell button
#define CLR_BTN_CALC       C'60,100,140'    // Calculate button

// ============================================================
// LAYOUT DIMENSIONS
// ============================================================
#define PANEL_X            10              // Panel X start
#define PANEL_Y            25              // Panel Y start
#define LEFT_WIDTH         390             // Left panels width
#define RIGHT_WIDTH        220             // Right panel width
#define PANEL_GAP          8               // Gap between panels
#define TITLE_HEIGHT       22              // Title bar height
#define ROW_HEIGHT         16              // Table row height
#define FONT_SIZE          8               // Main font
#define FONT_SIZE_TITLE    9               // Title font
#define FONT_SIZE_SMALL    7               // Small font

// ============================================================
// STRUCTURES
// ============================================================
struct SSessionInfo {
   string   name;
   bool     isActive;
   datetime openTime;
   datetime closeTime;
};

struct SICTPattern {
   string   type;         // FVG, OB, BOS, etc.
   double   priceHigh;
   double   priceLow;
   datetime time;
   bool     isBullish;
   bool     isActive;
};

struct SPositionCalc {
   string   symbol;
   double   riskPercent;
   double   stopLossPips;
   double   takeProfitPips;
   double   positionSize;
   double   riskAmount;
   double   entryPrice;
   double   stopLossPrice;
   double   takeProfitPrice;
   double   potentialLoss;
   double   potentialProfit;
   double   riskReward;
   double   marginRequired;
   double   pipValue;
   bool     isBuy;
};

struct SSignalHistory {
   datetime time;
   string   pairName;
   int      signal;
   double   zScore;
   double   strength;
   bool     executed;
   double   entryPL;
};

struct SPerformanceStats {
   int      totalSignals;
   int      executedTrades;
   int      winningTrades;
   int      losingTrades;
   double   totalPL;
   double   grossProfit;
   double   grossLoss;
   double   maxDrawdown;
   double   winRate;
   double   profitFactor;
};

//+------------------------------------------------------------------+
//| CDashboard - Professional Trading Dashboard                       |
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

   // ICT Data
   SSessionInfo   m_sessions[3];
   SICTPattern    m_patterns[];
   int            m_fvgCount;
   int            m_obCount;

   // Position Calculator
   SPositionCalc  m_posCalc;

   // Signal History & Performance
   SSignalHistory m_signalHistory[];
   int            m_historyCount;
   int            m_maxHistory;
   SPerformanceStats m_perfStats;

   // Alert system
   bool           m_alertsEnabled;
   double         m_alertZThreshold;
   double         m_alertStrengthThreshold;

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
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 10);
   }

   //+------------------------------------------------------------------+
   //| Create Panel (SOLID)                                              |
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
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);

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
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 20);
   }

   //+------------------------------------------------------------------+
   //| Create Edit Box                                                   |
   //+------------------------------------------------------------------+
   void CreateEdit(string name, string text, int x, int y, int w, int h,
                   color bgClr = CLR_INPUT_BG, color txtClr = CLR_TEXT_WHITE) {
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
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, FONT_SIZE);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_ALIGN, ALIGN_RIGHT);
      ObjectSetInteger(0, objName, OBJPROP_READONLY, false);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 15);
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
      if(absZ >= 2.5) return CLR_RED;
      if(absZ >= 2.0) return CLR_ORANGE;
      if(absZ >= 1.5) return CLR_YELLOW;
      if(absZ <= 0.5) return CLR_GREEN;
      return CLR_TEXT_LIGHT;
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
   //| Update Sessions                                                   |
   //+------------------------------------------------------------------+
   void UpdateSessions() {
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);
      int hour = dt.hour;

      // Tokyo/Asia: 00:00-09:00 UTC
      m_sessions[0].name = "ASIA";
      m_sessions[0].isActive = (hour >= 0 && hour < 9);

      // London: 08:00-17:00 UTC
      m_sessions[1].name = "LONDON";
      m_sessions[1].isActive = (hour >= 8 && hour < 17);

      // New York: 13:00-22:00 UTC
      m_sessions[2].name = "NEW YORK";
      m_sessions[2].isActive = (hour >= 13 && hour < 22);
   }

   //+------------------------------------------------------------------+
   //| Calculate Position                                                |
   //+------------------------------------------------------------------+
   void CalculatePosition() {
      if(m_posCalc.symbol == "" || m_posCalc.riskPercent <= 0) return;

      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double tickSize = SymbolInfoDouble(m_posCalc.symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(m_posCalc.symbol, SYMBOL_TRADE_TICK_VALUE);
      double pointValue = SymbolInfoDouble(m_posCalc.symbol, SYMBOL_POINT);
      double lotStep = SymbolInfoDouble(m_posCalc.symbol, SYMBOL_VOLUME_STEP);
      double minLot = SymbolInfoDouble(m_posCalc.symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_posCalc.symbol, SYMBOL_VOLUME_MAX);

      // Get current price
      m_posCalc.entryPrice = m_posCalc.isBuy ?
         SymbolInfoDouble(m_posCalc.symbol, SYMBOL_ASK) :
         SymbolInfoDouble(m_posCalc.symbol, SYMBOL_BID);

      // Calculate pip value (assuming 4/5 digit brokers)
      int digits = (int)SymbolInfoInteger(m_posCalc.symbol, SYMBOL_DIGITS);
      double pipSize = (digits == 3 || digits == 5) ? pointValue * 10 : pointValue;

      // Risk amount
      m_posCalc.riskAmount = accountBalance * m_posCalc.riskPercent / 100.0;

      // Position size
      if(m_posCalc.stopLossPips > 0 && tickValue > 0) {
         double pipValuePerLot = tickValue * pipSize / tickSize;
         m_posCalc.positionSize = m_posCalc.riskAmount / (m_posCalc.stopLossPips * pipValuePerLot);
         m_posCalc.positionSize = MathFloor(m_posCalc.positionSize / lotStep) * lotStep;
         m_posCalc.positionSize = MathMax(minLot, MathMin(maxLot, m_posCalc.positionSize));
         m_posCalc.pipValue = pipValuePerLot * m_posCalc.positionSize;
      } else {
         m_posCalc.positionSize = minLot;
         m_posCalc.pipValue = 0;
      }

      // Stop Loss & Take Profit prices
      double slPips = m_posCalc.stopLossPips * pipSize;
      double tpPips = m_posCalc.takeProfitPips * pipSize;

      if(m_posCalc.isBuy) {
         m_posCalc.stopLossPrice = m_posCalc.entryPrice - slPips;
         m_posCalc.takeProfitPrice = m_posCalc.entryPrice + tpPips;
      } else {
         m_posCalc.stopLossPrice = m_posCalc.entryPrice + slPips;
         m_posCalc.takeProfitPrice = m_posCalc.entryPrice - tpPips;
      }

      // Potential Loss/Profit
      m_posCalc.potentialLoss = -m_posCalc.stopLossPips * m_posCalc.pipValue;
      m_posCalc.potentialProfit = m_posCalc.takeProfitPips * m_posCalc.pipValue;

      // Risk/Reward
      m_posCalc.riskReward = m_posCalc.stopLossPips > 0 ?
         m_posCalc.takeProfitPips / m_posCalc.stopLossPips : 0;

      // Margin Required
      double marginRate = 0;
      if(OrderCalcMargin(m_posCalc.isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                         m_posCalc.symbol, m_posCalc.positionSize,
                         m_posCalc.entryPrice, marginRate)) {
         m_posCalc.marginRequired = marginRate;
      } else {
         m_posCalc.marginRequired = 0;
      }
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
      m_fvgCount = 0;
      m_obCount = 0;

      ArrayResize(m_spreadHistory, m_historySize);
      ArrayResize(m_zScoreHistory, m_historySize);
      ArrayResize(m_signalHistory, m_maxHistory);
      ArrayInitialize(m_spreadHistory, 0);
      ArrayInitialize(m_zScoreHistory, 0);
      ZeroMemory(m_perfStats);
      ZeroMemory(m_posCalc);

      // Default position calculator values
      m_posCalc.symbol = _Symbol;
      m_posCalc.riskPercent = 1.0;
      m_posCalc.stopLossPips = 50.0;
      m_posCalc.takeProfitPips = 100.0;
      m_posCalc.isBuy = true;
   }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   void Init() {
      DeleteAll();
      m_isVisible = true;
      UpdateSessions();
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
   }

   //+------------------------------------------------------------------+
   //| Update spread history                                             |
   //+------------------------------------------------------------------+
   void UpdateSpreadHistory(double spread, double zScore) {
      for(int i = m_historySize - 1; i > 0; i--) {
         m_spreadHistory[i] = m_spreadHistory[i-1];
         m_zScoreHistory[i] = m_zScoreHistory[i-1];
      }
      m_spreadHistory[0] = spread;
      m_zScoreHistory[0] = zScore;
   }

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

      DeleteAll();
      UpdateSessions();

      int x = m_startX;
      int y = m_startY;

      // Get selected pair
      SPairResult result;
      if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
         result = m_scanResults[m_selectedRow];
      } else if(m_resultCount > 0) {
         result = m_scanResults[0];
      } else {
         ZeroMemory(result);
         result.pairName = "NO DATA";
      }

      // ================ LEFT COLUMN ================

      // PANEL 1: Scanner
      int scannerH = TITLE_HEIGHT + ROW_HEIGHT * 15 + 25;
      DrawScannerPanel(x, y, LEFT_WIDTH, scannerH);

      // PANEL 2: Spread
      int spreadY = y + scannerH + PANEL_GAP;
      int spreadH = 140;
      DrawSpreadPanel(x, spreadY, LEFT_WIDTH, spreadH, result);

      // PANEL 3: ICT Analysis
      int ictY = spreadY + spreadH + PANEL_GAP;
      int ictH = 150;
      DrawICTPanel(x, ictY, LEFT_WIDTH, ictH, result);

      // ================ RIGHT COLUMN ================
      int rightX = x + LEFT_WIDTH + PANEL_GAP;

      // PANEL 4: Position Calculator
      int calcH = scannerH + PANEL_GAP + spreadH + PANEL_GAP + ictH;
      DrawPositionCalculator(rightX, y, RIGHT_WIDTH, calcH);

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Draw Scanner Panel                                                |
   //+------------------------------------------------------------------+
   void DrawScannerPanel(int x, int y, int w, int h) {
      // Background
      CreatePanel("SCAN_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title bar
      CreatePanel("SCAN_TITLE", x+1, y+1, w-2, TITLE_HEIGHT, CLR_TITLE_BG);
      CreateLabel("SCAN_T", "Pairs Trading Dashboard - D-LOGIC 5.00",
                  x + 8, y + 5, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      // SCAN button
      CreateButton("BTN_SCAN", "SCAN", x + w - 50, y + 3, 45, 17,
                   CLR_BTN_BUY, CLR_GREEN, FONT_SIZE_SMALL);

      // Column headers
      int hY = y + TITLE_HEIGHT + 4;
      CreateLabel("H_PAIR", "Pair", x + 8, hY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("H_TF", "TF", x + 125, hY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("H_SPEAR", "Spearman", x + 150, hY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("H_ZSCORE", "Z-Score", x + 215, hY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("H_TYPE", "Type", x + 275, hY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("H_SIGNAL", "Signal", x + 320, hY, CLR_TEXT_DIM, FONT_SIZE_SMALL);

      // Data rows
      int rowY = hY + ROW_HEIGHT;
      int maxRows = MathMin(13, m_resultCount);

      for(int i = 0; i < maxRows; i++) {
         int idx = i + m_scrollOffset;
         if(idx >= m_resultCount) break;

         SPairResult r = m_scanResults[idx];
         string pfx = "R" + IntegerToString(i) + "_";
         bool selected = (idx == m_selectedRow);

         // Row bg
         color rowBg = selected ? CLR_ROW_SELECTED : (i % 2 == 0 ? CLR_ROW_EVEN : CLR_ROW_ODD);
         CreatePanel(pfx + "BG", x + 2, rowY - 1, w - 4, ROW_HEIGHT, rowBg);

         // Pair
         color pClr = selected ? CLR_CYAN : CLR_TEXT_WHITE;
         CreateLabel(pfx + "PAIR", r.pairName, x + 8, rowY, pClr, FONT_SIZE);

         // TF
         string tfStr = "H4";
         if(r.timeframe == PERIOD_H1) tfStr = "H1";
         else if(r.timeframe == PERIOD_D1) tfStr = "D1";
         else if(r.timeframe == PERIOD_M15) tfStr = "M15";
         CreateLabel(pfx + "TF", tfStr, x + 125, rowY, CLR_TEXT_DIM, FONT_SIZE);

         // Spearman/Correlation
         color corrClr = r.priceCorrelation >= 0 ? CLR_GREEN : CLR_RED;
         CreateLabel(pfx + "CORR", DoubleToString(r.priceCorrelation, 2), x + 160, rowY, corrClr, FONT_SIZE);

         // Z-Score
         color zClr = GetZScoreColor(r.zScore);
         CreateLabel(pfx + "Z", DoubleToString(r.zScore, 2), x + 225, rowY, zClr, FONT_SIZE, "Consolas Bold");

         // Type
         string typeStr = r.zScore >= 0 ? "Pos" : "Neg";
         color typeClr = r.zScore >= 0 ? CLR_GREEN : CLR_RED;
         CreateLabel(pfx + "TYPE", typeStr, x + 280, rowY, typeClr, FONT_SIZE);

         // Signal
         string sigStr = GetSignalText(r.signal);
         color sigClr = r.signal > 0 ? CLR_GREEN : (r.signal < 0 ? CLR_RED : CLR_TEXT_DIM);
         CreateLabel(pfx + "SIG", sigStr, x + 325, rowY, sigClr, FONT_SIZE);

         rowY += ROW_HEIGHT;
      }

      // Footer
      int fY = y + h - 15;
      string footer = "Pairs: " + IntegerToString(m_resultCount) +
                     " | Signals: " + IntegerToString(m_perfStats.totalSignals) +
                     " | Pos: " + IntegerToString(m_perfStats.winningTrades) +
                     " | Neg: " + IntegerToString(m_perfStats.losingTrades);
      CreateLabel("SCAN_FOOT", footer, x + 8, fY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("SCAN_TIME", TimeToString(TimeCurrent(), TIME_SECONDS), x + w - 65, fY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
   }

   //+------------------------------------------------------------------+
   //| Draw Spread Panel                                                 |
   //+------------------------------------------------------------------+
   void DrawSpreadPanel(int x, int y, int w, int h, SPairResult &result) {
      // Background
      CreatePanel("SPR_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title
      CreatePanel("SPR_TITLE", x+1, y+1, w-2, TITLE_HEIGHT, CLR_TITLE_BG);
      string title = "Spread: " + result.symbolA + " / " + result.symbolB;
      CreateLabel("SPR_T", title, x + 8, y + 5, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      // Toggle button
      CreateButton("BTN_SPR_TOGGLE", "-", x + w - 20, y + 3, 15, 17, CLR_PANEL_BORDER, CLR_TEXT_WHITE, FONT_SIZE);

      // Stats line
      int sY = y + TITLE_HEIGHT + 4;
      string stats = "Z: " + DoubleToString(result.zScore, 2) +
                    " | HR: " + DoubleToString(result.hurstExponent, 4) +
                    " | LE: " + DoubleToString(result.halfLife, 5);
      CreateLabel("SPR_STATS", stats, x + 8, sY, CLR_TEXT_LIGHT, FONT_SIZE);

      // Chart area
      int cX = x + 8;
      int cY = sY + 16;
      int cW = w - 50;
      int cH = h - 55;

      CreatePanel("SPR_CHART", cX, cY, cW, cH, C'15,18,25', CLR_PANEL_BORDER);

      // Level markers
      int midY = cY + cH / 2;
      CreateLabel("SPR_2U", "+2LE", x + w - 35, cY + 5, CLR_RED, FONT_SIZE_SMALL);
      CreateLabel("SPR_1U", "+1LE", x + w - 35, cY + cH/4, CLR_YELLOW, FONT_SIZE_SMALL);
      CreateLabel("SPR_M", "Mean", x + w - 35, midY - 4, CLR_YELLOW, FONT_SIZE_SMALL);
      CreateLabel("SPR_1L", "-1LE", x + w - 35, cY + 3*cH/4, CLR_YELLOW, FONT_SIZE_SMALL);
      CreateLabel("SPR_2L", "-2LE", x + w - 35, cY + cH - 12, CLR_GREEN, FONT_SIZE_SMALL);

      // Draw chart points
      DrawSpreadChart(cX, cY, cW, cH);

      // Legend
      CreateLabel("SPR_LEG", "Green=Oversold | Yellow=Mean | Red=Overbought",
                  x + 8, y + h - 14, CLR_TEXT_DIM, FONT_SIZE_SMALL);
   }

   //+------------------------------------------------------------------+
   //| Draw Spread Chart                                                 |
   //+------------------------------------------------------------------+
   void DrawSpreadChart(int x, int y, int w, int h) {
      int validCount = 0;
      double minZ = 999, maxZ = -999;

      for(int i = 0; i < m_historySize && i < 60; i++) {
         if(m_zScoreHistory[i] != 0 || i == 0) {
            minZ = MathMin(minZ, m_zScoreHistory[i]);
            maxZ = MathMax(maxZ, m_zScoreHistory[i]);
            validCount++;
         }
      }

      if(validCount < 3) return;

      double range = MathMax(4.0, MathMax(MathAbs(maxZ), MathAbs(minZ)) * 2);
      minZ = -range / 2;
      maxZ = range / 2;

      int pointCount = MathMin(validCount, 60);
      double stepX = (double)(w - 10) / pointCount;

      for(int i = 0; i < pointCount; i++) {
         int idx = pointCount - 1 - i;
         double z = m_zScoreHistory[idx];

         int px = x + 5 + (int)(i * stepX);
         int py = y + h/2 - (int)(z / range * (h - 10));
         py = MathMax(y + 2, MathMin(y + h - 2, py));

         CreatePanel("SPR_P" + IntegerToString(i), px, py, 3, 3, GetZScoreColor(z));
      }
   }

   //+------------------------------------------------------------------+
   //| Draw ICT Analysis Panel                                           |
   //+------------------------------------------------------------------+
   void DrawICTPanel(int x, int y, int w, int h, SPairResult &result) {
      // Background
      CreatePanel("ICT_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title
      CreatePanel("ICT_TITLE", x+1, y+1, w-2, TITLE_HEIGHT, CLR_TITLE_BG);
      CreateLabel("ICT_T", "ICT Analysis - " + result.symbolA, x + 8, y + 5, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      // Draw button
      CreateButton("BTN_DRAW", "Draw", x + w - 70, y + 3, 40, 17, CLR_BTN_CALC, CLR_TEXT_WHITE, FONT_SIZE_SMALL);
      CreateButton("BTN_ICT_TOGGLE", "-", x + w - 20, y + 3, 15, 17, CLR_PANEL_BORDER, CLR_TEXT_WHITE, FONT_SIZE);

      int cY = y + TITLE_HEIGHT + 8;

      // Sessions section
      CreateLabel("ICT_SESS_T", "--- SESSIONS ---", x + 8, cY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      cY += 16;

      for(int i = 0; i < 3; i++) {
         string status = m_sessions[i].isActive ? "ACTIVE" : "Closed";
         color statusClr = m_sessions[i].isActive ? CLR_GREEN : CLR_RED;
         color dotClr = m_sessions[i].isActive ? CLR_GREEN : CLR_RED;

         CreateLabel("ICT_S" + IntegerToString(i) + "_DOT", CharToString(0x25CF), x + 10, cY, dotClr, FONT_SIZE_SMALL);
         CreateLabel("ICT_S" + IntegerToString(i) + "_NAME", m_sessions[i].name + ":", x + 22, cY, CLR_TEXT_LIGHT, FONT_SIZE);
         CreateLabel("ICT_S" + IntegerToString(i) + "_ST", status, x + 90, cY, statusClr, FONT_SIZE);
         CreateLabel("ICT_S" + IntegerToString(i) + "_LBL", "Label", x + 145, cY, CLR_CYAN, FONT_SIZE);
         cY += 15;
      }

      cY += 8;

      // ICT Patterns section
      CreateLabel("ICT_PAT_T", "--- ICT PATTERNS ---", x + 8, cY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      cY += 16;

      CreateLabel("ICT_FVG_L", "Fair Value Gaps:", x + 10, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("ICT_FVG_V", IntegerToString(m_fvgCount) + " active", x + 120, cY, CLR_TEXT_WHITE, FONT_SIZE);
      cY += 15;

      CreateLabel("ICT_OB_L", "Order Blocks:", x + 10, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("ICT_OB_V", IntegerToString(m_obCount) + " active", x + 120, cY, CLR_TEXT_WHITE, FONT_SIZE);
   }

   //+------------------------------------------------------------------+
   //| Draw Position Calculator                                          |
   //+------------------------------------------------------------------+
   void DrawPositionCalculator(int x, int y, int w, int h) {
      // Background
      CreatePanel("CALC_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title
      CreatePanel("CALC_TITLE", x+1, y+1, w-2, TITLE_HEIGHT, CLR_TITLE_BG);
      CreateLabel("CALC_T", "Position Calculator", x + 8, y + 5, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");
      CreateButton("BTN_CALC_TOGGLE", "-", x + w - 20, y + 3, 15, 17, CLR_PANEL_BORDER, CLR_TEXT_WHITE, FONT_SIZE);

      int cY = y + TITLE_HEIGHT + 8;
      int col1 = x + 10;
      int col2 = x + 110;
      int inputW = w - 120;
      int rowH = 20;

      // --- INPUTS ---
      CreateLabel("CALC_INP", "--- INPUTS ---", col1, cY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      cY += 16;

      // Symbol
      CreateLabel("CALC_SYM_L", "Symbol:", col1, cY + 2, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateEdit("CALC_SYM_V", m_posCalc.symbol, col2, cY, inputW, 16);
      cY += rowH;

      // Risk %
      CreateLabel("CALC_RISK_L", "Risk %:", col1, cY + 2, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateEdit("CALC_RISK_V", DoubleToString(m_posCalc.riskPercent, 2), col2, cY, inputW, 16);
      cY += rowH;

      // Stop Loss
      CreateLabel("CALC_SL_L", "Stop Loss (pips):", col1, cY + 2, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateEdit("CALC_SL_V", DoubleToString(m_posCalc.stopLossPips, 1), col2, cY, inputW, 16);
      cY += rowH;

      // Take Profit
      CreateLabel("CALC_TP_L", "Take Profit (pips):", col1, cY + 2, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateEdit("CALC_TP_V", DoubleToString(m_posCalc.takeProfitPips, 1), col2, cY, inputW, 16);
      cY += rowH + 5;

      // Buttons
      int btnW = (w - 30) / 3;
      CreateButton("BTN_BUY", "BUY", x + 10, cY, btnW, 20, CLR_BTN_BUY, CLR_GREEN, FONT_SIZE);
      CreateButton("BTN_SELL", "SELL", x + 15 + btnW, cY, btnW, 20, CLR_BTN_SELL, CLR_RED, FONT_SIZE);
      CreateButton("BTN_CALCULATE", "CALCULATE", x + 20 + btnW * 2, cY, btnW, 20, CLR_BTN_CALC, CLR_CYAN, FONT_SIZE);
      cY += 30;

      // --- RESULTS ---
      CreateLabel("CALC_RES", "--- RESULTS ---", col1, cY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      cY += 16;

      // Calculate if needed
      CalculatePosition();

      // Position Size
      CreateLabel("CALC_PS_L", "Position Size:", col1, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_PS_V", DoubleToString(m_posCalc.positionSize, 2) + " lots", col2, cY, CLR_GREEN, FONT_SIZE, "Consolas Bold");
      cY += rowH;

      // Risk Amount
      CreateLabel("CALC_RA_L", "Risk Amount:", col1, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_RA_V", DoubleToString(m_posCalc.riskAmount, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY), col2, cY, CLR_RED, FONT_SIZE);
      cY += rowH;

      // Entry Price
      CreateLabel("CALC_EP_L", "Entry Price:", col1, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_EP_V", DoubleToString(m_posCalc.entryPrice, 5), col2, cY, CLR_CYAN, FONT_SIZE);
      cY += rowH;

      // Stop Loss Price
      CreateLabel("CALC_SLP_L", "Stop Loss:", col1, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_SLP_V", DoubleToString(m_posCalc.stopLossPrice, 5), col2, cY, CLR_RED, FONT_SIZE);
      cY += rowH;

      // Take Profit Price
      CreateLabel("CALC_TPP_L", "Take Profit:", col1, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_TPP_V", DoubleToString(m_posCalc.takeProfitPrice, 5), col2, cY, CLR_GREEN, FONT_SIZE);
      cY += rowH;

      // Potential Loss
      CreateLabel("CALC_PL_L", "Potential Loss:", col1, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_PL_V", DoubleToString(m_posCalc.potentialLoss, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY),
                  col2, cY, CLR_RED, FONT_SIZE);
      cY += rowH;

      // Potential Profit
      CreateLabel("CALC_PP_L", "Potential Profit:", col1, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_PP_V", "+" + DoubleToString(m_posCalc.potentialProfit, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY),
                  col2, cY, CLR_GREEN, FONT_SIZE);
      cY += rowH;

      // Risk/Reward
      CreateLabel("CALC_RR_L", "Risk/Reward:", col1, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_RR_V", "1:" + DoubleToString(m_posCalc.riskReward, 2), col2, cY, CLR_CYAN, FONT_SIZE, "Consolas Bold");
      cY += rowH;

      // Margin Required
      CreateLabel("CALC_MR_L", "Margin Required:", col1, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_MR_V", DoubleToString(m_posCalc.marginRequired, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY),
                  col2, cY, CLR_YELLOW, FONT_SIZE);
      cY += rowH;

      // Pip Value
      CreateLabel("CALC_PV_L", "Pip Value:", col1, cY, CLR_TEXT_LIGHT, FONT_SIZE);
      CreateLabel("CALC_PV_V", DoubleToString(m_posCalc.pipValue, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "/pip",
                  col2, cY, CLR_TEXT_WHITE, FONT_SIZE);
      cY += rowH + 10;

      // Warning
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(m_posCalc.marginRequired > freeMargin) {
         CreatePanel("CALC_WARN_BG", x + 10, cY, w - 20, 18, CLR_RED);
         CreateLabel("CALC_WARN", "Insufficient margin!", x + 15, cY + 2, CLR_TEXT_WHITE, FONT_SIZE);
      }
   }

   //+------------------------------------------------------------------+
   //| Handle Click                                                      |
   //+------------------------------------------------------------------+
   int HandleClick(string objName, string &symbolA, string &symbolB, double &beta) {
      if(StringFind(objName, m_prefix) < 0) return 0;

      string name = StringSubstr(objName, StringLen(m_prefix));

      if(name == "BTN_SCAN") return 1;
      if(name == "BTN_BUY") {
         m_posCalc.isBuy = true;
         CalculatePosition();
         return 5;
      }
      if(name == "BTN_SELL") {
         m_posCalc.isBuy = false;
         CalculatePosition();
         return 6;
      }
      if(name == "BTN_CALCULATE") {
         // Read values from edit boxes
         string symVal = ObjectGetString(0, m_prefix + "CALC_SYM_V", OBJPROP_TEXT);
         string riskVal = ObjectGetString(0, m_prefix + "CALC_RISK_V", OBJPROP_TEXT);
         string slVal = ObjectGetString(0, m_prefix + "CALC_SL_V", OBJPROP_TEXT);
         string tpVal = ObjectGetString(0, m_prefix + "CALC_TP_V", OBJPROP_TEXT);

         if(symVal != "") m_posCalc.symbol = symVal;
         m_posCalc.riskPercent = StringToDouble(riskVal);
         m_posCalc.stopLossPips = StringToDouble(slVal);
         m_posCalc.takeProfitPips = StringToDouble(tpVal);

         CalculatePosition();
         return 7;
      }
      if(name == "BTN_DRAW") return 8;

      // Row selection
      for(int i = 0; i < 15; i++) {
         if(StringFind(name, "R" + IntegerToString(i) + "_") >= 0) {
            int newSel = i + m_scrollOffset;
            if(newSel < m_resultCount) {
               m_selectedRow = newSel;
               symbolA = m_scanResults[m_selectedRow].symbolA;
               symbolB = m_scanResults[m_selectedRow].symbolB;
               beta = m_scanResults[m_selectedRow].beta;
               return 4;
            }
         }
      }

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Get Selected Pair                                                 |
   //+------------------------------------------------------------------+
   bool GetSelectedPair(SPairResult &result) {
      if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
         result = m_scanResults[m_selectedRow];
         return true;
      }
      return false;
   }

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
   //| Other methods                                                     |
   //+------------------------------------------------------------------+
   void ConfigureAlerts(bool enabled, double zThreshold, double strengthThreshold) {
      m_alertsEnabled = enabled;
      m_alertZThreshold = zThreshold;
      m_alertStrengthThreshold = strengthThreshold;
   }

   bool AreAlertsEnabled() { return m_alertsEnabled; }

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

   void RecordTradeResult(double profit) {
      m_perfStats.executedTrades++;
      m_perfStats.totalPL += profit;
      if(profit >= 0) {
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

   void AddTradeResult(double profit, bool isWin) { RecordTradeResult(profit); }

   void UpdateInfo(double unrealizedPL, int positionCount, double maxDD, double activeBeta) {
      m_perfStats.maxDrawdown = maxDD;
   }

   void ToggleVisibility() {
      m_isVisible = !m_isVisible;
      if(m_isVisible) Draw();
      else { DeleteAll(); ChartRedraw(0); }
   }

   bool IsVisible() { return m_isVisible; }
   double GetSignalStrength() { return 0; }

   void RecordSignal(string pairName, int signal, double zScore, double strength) {
      m_perfStats.totalSignals++;
   }

   void ResetStats() {
      ZeroMemory(m_perfStats);
      m_perfStats.profitFactor = 1.0;
   }

   int GetTopPairs(string &pairs[], int maxPairs = 6) {
      int count = MathMin(maxPairs, m_resultCount);
      ArrayResize(pairs, count);
      for(int i = 0; i < count; i++) pairs[i] = m_scanResults[i].pairName;
      return count;
   }

   // ICT Pattern setters
   void SetFVGCount(int count) { m_fvgCount = count; }
   void SetOBCount(int count) { m_obCount = count; }
};

//+------------------------------------------------------------------+
