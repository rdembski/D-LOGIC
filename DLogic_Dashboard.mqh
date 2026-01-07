//+------------------------------------------------------------------+
//|                                           DLogic_Dashboard.mqh   |
//|              D-LOGIC Professional Pairs Trading Dashboard         |
//|                                        Author: Rafał Dembski     |
//|                                                                   |
//|  Classic Terminal Panel Design v4.70                              |
//|  - SOLID opaque backgrounds (OBJPROP_BACK = false)                |
//|  - Two-Column Layout: LEFT + RIGHT panels                         |
//+------------------------------------------------------------------+
#property copyright "Rafał Dembski"
#property strict

#include "DLogic_Engine.mqh"

// ============================================================
// COLOR SCHEME - CLASSIC TERMINAL (SOLID BACKGROUNDS)
// ============================================================
#define CLR_PANEL_BG       C'20,22,28'      // Dark panel background
#define CLR_PANEL_BORDER   C'50,55,70'      // Panel border
#define CLR_TITLE_BG       C'30,80,120'     // Title bar background
#define CLR_TITLE_TEXT     C'220,230,255'   // Title text

#define CLR_NEON_GREEN     C'0,255,100'     // Positive/Long
#define CLR_NEON_RED       C'255,80,80'     // Negative/Short
#define CLR_NEON_CYAN      C'0,200,255'     // Accent
#define CLR_NEON_YELLOW    C'255,220,0'     // Warning
#define CLR_NEON_ORANGE    C'255,150,50'    // Alert
#define CLR_NEON_PURPLE    C'180,100,255'   // Special

#define CLR_TEXT_WHITE     C'255,255,255'   // Primary text
#define CLR_TEXT_LIGHT     C'180,190,210'   // Secondary text
#define CLR_TEXT_DIM       C'120,130,150'   // Dim text

#define CLR_ROW_EVEN       C'25,28,35'      // Even row
#define CLR_ROW_ODD        C'30,33,42'      // Odd row
#define CLR_ROW_SELECTED   C'40,60,90'      // Selected row

#define CLR_CHART_BG       C'15,18,25'      // Chart background

// ============================================================
// LAYOUT DIMENSIONS
// ============================================================
#define PANEL_X            10              // Left panel X position
#define PANEL_Y            25              // Panel Y position
#define PANEL_WIDTH_L      340             // Left panel width
#define PANEL_WIDTH_R      250             // Right panel width
#define PANEL_GAP          10              // Gap between panels
#define TITLE_HEIGHT       22              // Title bar height
#define ROW_HEIGHT         18              // Table row height
#define FONT_SIZE          9               // Main font size
#define FONT_SIZE_TITLE    10              // Title font size
#define FONT_SIZE_SMALL    8               // Small font

// ============================================================
// STRUCTURES
// ============================================================
enum ENUM_REGIME {
   REGIME_MEAN_REVERT,
   REGIME_TRENDING,
   REGIME_VOLATILE,
   REGIME_CONSOLIDATION
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

//+------------------------------------------------------------------+
//| CDashboard - Classic Terminal Panel Design                        |
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

   // Analytics
   ENUM_REGIME    m_currentRegime;
   double         m_signalStrength;

   // Signal History
   SSignalHistory m_signalHistory[];
   int            m_historyCount;
   int            m_maxHistory;

   // Performance
   SPerformanceStats m_perfStats;

   // Correlation pairs
   string         m_corrPairs[6];

   // Alert system
   bool           m_alertsEnabled;
   double         m_alertZThreshold;
   double         m_alertStrengthThreshold;

   //+------------------------------------------------------------------+
   //| Create Label (on foreground)                                      |
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
   //| Create Rectangle Panel - OPAQUE, on foreground                    |
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
      // CRITICAL: OBJPROP_BACK = false means panel is drawn ON TOP of chart
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
   //| Get regime text                                                   |
   //+------------------------------------------------------------------+
   string GetRegimeText(ENUM_REGIME regime) {
      switch(regime) {
         case REGIME_MEAN_REVERT:    return "MEAN REVERT";
         case REGIME_TRENDING:       return "TRENDING";
         case REGIME_VOLATILE:       return "VOLATILE";
         default:                    return "CONSOLIDATION";
      }
   }

   //+------------------------------------------------------------------+
   //| Get regime color                                                  |
   //+------------------------------------------------------------------+
   color GetRegimeColor(ENUM_REGIME regime) {
      switch(regime) {
         case REGIME_MEAN_REVERT:    return CLR_NEON_GREEN;
         case REGIME_TRENDING:       return CLR_NEON_RED;
         case REGIME_VOLATILE:       return CLR_NEON_ORANGE;
         default:                    return CLR_NEON_YELLOW;
      }
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
      }
   }

   //+------------------------------------------------------------------+
   //| Update spread history (2 params)                                  |
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
   //| Update spread history (3 params)                                  |
   //+------------------------------------------------------------------+
   void UpdateSpreadHistory(double &spread[], double &zScore[], int size) {
      int copySize = MathMin(size, m_historySize);
      for(int i = 0; i < copySize; i++) {
         m_spreadHistory[i] = spread[i];
         m_zScoreHistory[i] = zScore[i];
      }
   }

   //+------------------------------------------------------------------+
   //| Main Draw function - TWO COLUMN LAYOUT                            |
   //+------------------------------------------------------------------+
   void Draw() {
      if(!m_isVisible) return;

      // Clear old objects first
      DeleteAll();

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

      // PANEL 1: Scanner (top-left)
      int scannerH = TITLE_HEIGHT + ROW_HEIGHT * 10 + 25;
      DrawScannerPanel(x, y, PANEL_WIDTH_L, scannerH);

      // PANEL 2: Spread Chart (bottom-left)
      int spreadY = y + scannerH + PANEL_GAP;
      int spreadH = 120;
      DrawSpreadPanel(x, spreadY, PANEL_WIDTH_L, spreadH, result);

      // PANEL 3: Analytics (bottom-left, below spread)
      int analyticsY = spreadY + spreadH + PANEL_GAP;
      int analyticsH = 145;
      DrawAnalyticsPanel(x, analyticsY, PANEL_WIDTH_L, analyticsH, result);

      // ================ RIGHT COLUMN ================
      int rightX = x + PANEL_WIDTH_L + PANEL_GAP;

      // PANEL 4: Trade Setup (top-right)
      int tradeH = 200;
      DrawTradePanel(rightX, y, PANEL_WIDTH_R, tradeH, result);

      // PANEL 5: Performance (bottom-right)
      int perfY = y + tradeH + PANEL_GAP;
      int perfH = scannerH + PANEL_GAP + spreadH + PANEL_GAP + analyticsH - tradeH - PANEL_GAP;
      DrawPerformancePanel(rightX, perfY, PANEL_WIDTH_R, perfH);

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Draw Scanner Panel                                                |
   //+------------------------------------------------------------------+
   void DrawScannerPanel(int x, int y, int w, int h) {
      // Panel background - SOLID
      CreatePanel("SCAN_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title bar
      CreatePanel("SCAN_TITLE_BG", x+1, y+1, w-2, TITLE_HEIGHT, CLR_TITLE_BG);
      CreateLabel("SCAN_TITLE", "Pairs Trading Dashboard - D-LOGIC 4.70",
                  x + 8, y + 4, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      // SCAN button
      CreateButton("BTN_SCAN", "SCAN", x + w - 55, y + 2, 50, 18,
                   C'40,100,60', CLR_NEON_GREEN, FONT_SIZE_SMALL);

      // Column headers
      int headerY = y + TITLE_HEIGHT + 5;
      CreateLabel("H_PAIR", "Pair", x + 8, headerY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("H_TF", "TF", x + 120, headerY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("H_CORR", "Corr", x + 150, headerY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("H_ZSCORE", "Z-Score", x + 195, headerY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("H_QUAL", "Qual", x + 260, headerY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("H_SIGNAL", "Signal", x + 295, headerY, CLR_TEXT_DIM, FONT_SIZE_SMALL);

      // Data rows
      int rowY = headerY + ROW_HEIGHT;
      int maxRows = MathMin(8, m_resultCount);

      for(int i = 0; i < maxRows; i++) {
         int idx = i + m_scrollOffset;
         if(idx >= m_resultCount) break;

         SPairResult r = m_scanResults[idx];
         string rowPfx = "R" + IntegerToString(i) + "_";
         bool isSelected = (idx == m_selectedRow);

         // Row background
         color rowBg = isSelected ? CLR_ROW_SELECTED : (i % 2 == 0 ? CLR_ROW_EVEN : CLR_ROW_ODD);
         CreatePanel(rowPfx + "BG", x + 2, rowY - 1, w - 4, ROW_HEIGHT, rowBg);

         // Pair name
         color pairClr = isSelected ? CLR_NEON_CYAN : CLR_TEXT_WHITE;
         CreateLabel(rowPfx + "PAIR", r.pairName, x + 8, rowY, pairClr, FONT_SIZE);

         // Timeframe
         string tfStr = "H4";
         if(r.timeframe == PERIOD_H1) tfStr = "H1";
         else if(r.timeframe == PERIOD_D1) tfStr = "D1";
         CreateLabel(rowPfx + "TF", tfStr, x + 120, rowY, CLR_TEXT_DIM, FONT_SIZE);

         // Correlation
         color corrClr = MathAbs(r.priceCorrelation) >= 0.7 ? CLR_NEON_GREEN :
                        (MathAbs(r.priceCorrelation) >= 0.5 ? CLR_NEON_YELLOW : CLR_TEXT_DIM);
         CreateLabel(rowPfx + "CORR", DoubleToString(r.priceCorrelation, 2), x + 150, rowY, corrClr, FONT_SIZE);

         // Z-Score
         color zClr = GetZScoreColor(r.zScore);
         string zStr = DoubleToString(r.zScore, 2);
         CreateLabel(rowPfx + "Z", zStr, x + 195, rowY, zClr, FONT_SIZE, "Consolas Bold");

         // Quality
         color qClr = r.qualityScore >= 70 ? CLR_NEON_GREEN :
                     (r.qualityScore >= 50 ? CLR_NEON_YELLOW : CLR_TEXT_DIM);
         CreateLabel(rowPfx + "QUAL", IntegerToString(r.qualityScore), x + 260, rowY, qClr, FONT_SIZE);

         // Signal
         string sigStr = GetSignalText(r.signal);
         color sigClr = r.signal == 0 ? CLR_TEXT_DIM :
                       (r.signal > 0 ? CLR_NEON_GREEN : CLR_NEON_RED);
         CreateLabel(rowPfx + "SIG", sigStr, x + 295, rowY, sigClr, FONT_SIZE, "Consolas Bold");

         rowY += ROW_HEIGHT;
      }

      // Footer
      int footerY = y + h - 16;
      string footerText = "Pairs: " + IntegerToString(m_resultCount) +
                          " | Signals: " + IntegerToString(m_perfStats.totalSignals) +
                          " | Pos: " + IntegerToString(m_perfStats.winningTrades) +
                          " | Neg: " + IntegerToString(m_perfStats.losingTrades);
      CreateLabel("SCAN_FOOTER", footerText, x + 8, footerY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
      CreateLabel("SCAN_TIME", TimeToString(TimeCurrent(), TIME_SECONDS), x + w - 70, footerY, CLR_TEXT_DIM, FONT_SIZE_SMALL);
   }

   //+------------------------------------------------------------------+
   //| Draw Spread Panel                                                 |
   //+------------------------------------------------------------------+
   void DrawSpreadPanel(int x, int y, int w, int h, SPairResult &result) {
      // Panel background - SOLID
      CreatePanel("SPR_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title bar
      CreatePanel("SPR_TITLE_BG", x+1, y+1, w-2, TITLE_HEIGHT, CLR_TITLE_BG);
      CreateLabel("SPR_TITLE", "Spread: " + result.pairName, x + 8, y + 4, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      // Stats
      int statsY = y + TITLE_HEIGHT + 5;
      string statsText = "Z: " + DoubleToString(result.zScore, 2) +
                         " | HR: " + DoubleToString(result.hurstExponent, 4) +
                         " | HL: " + DoubleToString(result.halfLife, 1);
      CreateLabel("SPR_STATS", statsText, x + 8, statsY, CLR_TEXT_LIGHT, FONT_SIZE);

      // Chart area
      int chartX = x + 8;
      int chartY = statsY + 18;
      int chartW = w - 50;
      int chartH = h - 55;

      CreatePanel("SPR_CHART_BG", chartX, chartY, chartW, chartH, CLR_CHART_BG, CLR_PANEL_BORDER);

      // Level labels
      int midY = chartY + chartH / 2;
      CreateLabel("SPR_L2U", "+2σ", x + w - 35, chartY + 5, CLR_NEON_RED, 7);
      CreateLabel("SPR_MEAN", "Mean", x + w - 35, midY - 5, CLR_NEON_YELLOW, 7);
      CreateLabel("SPR_L2L", "-2σ", x + w - 35, chartY + chartH - 12, CLR_NEON_GREEN, 7);

      // Draw Z-Score points
      DrawSpreadChart(chartX, chartY, chartW, chartH);

      // Legend
      CreateLabel("SPR_LEG", "Green=Oversold | Yellow=Mean | Red=Overbought", x + 8, y + h - 14, CLR_TEXT_DIM, 7);
   }

   //+------------------------------------------------------------------+
   //| Draw Spread Chart Points                                          |
   //+------------------------------------------------------------------+
   void DrawSpreadChart(int x, int y, int w, int h) {
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

      double range = MathMax(4.0, maxZ - minZ);
      double mid = (maxZ + minZ) / 2;
      minZ = mid - range / 2;
      maxZ = mid + range / 2;

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
   //| Draw Analytics Panel                                              |
   //+------------------------------------------------------------------+
   void DrawAnalyticsPanel(int x, int y, int w, int h, SPairResult &result) {
      // Panel background - SOLID
      CreatePanel("ANA_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title bar
      CreatePanel("ANA_TITLE_BG", x+1, y+1, w-2, TITLE_HEIGHT, CLR_TITLE_BG);
      CreateLabel("ANA_TITLE", "Analytics - " + result.pairName, x + 8, y + 4, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      // Buttons
      CreateButton("BTN_TRADE", "TRADE", x + w - 115, y + 2, 50, 18, C'30,80,120', CLR_NEON_CYAN, FONT_SIZE_SMALL);
      CreateButton("BTN_CLOSE", "CLOSE", x + w - 58, y + 2, 50, 18, C'120,40,40', CLR_NEON_RED, FONT_SIZE_SMALL);

      int cy = y + TITLE_HEIGHT + 8;
      int col1 = x + 10;
      int col2 = x + 90;
      int col3 = x + 180;
      int col4 = x + 260;
      int rowH = 16;

      // Row 1
      CreateLabel("ANA_ZL", "Z-Score:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      CreateLabel("ANA_ZV", DoubleToString(result.zScore, 3), col2, cy, GetZScoreColor(result.zScore), FONT_SIZE, "Consolas Bold");
      CreateLabel("ANA_SL", "Signal:", col3, cy, CLR_TEXT_DIM, FONT_SIZE);
      string sigText = result.signal > 0 ? "LONG" : (result.signal < 0 ? "SHORT" : "WAIT");
      color sigClr = result.signal > 0 ? CLR_NEON_GREEN : (result.signal < 0 ? CLR_NEON_RED : CLR_TEXT_DIM);
      CreateLabel("ANA_SV", sigText, col4, cy, sigClr, FONT_SIZE, "Consolas Bold");
      cy += rowH;

      // Row 2
      CreateLabel("ANA_HL", "Hurst:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      color hClr = result.hurstExponent < 0.45 ? CLR_NEON_GREEN : (result.hurstExponent < 0.55 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("ANA_HV", DoubleToString(result.hurstExponent, 3), col2, cy, hClr, FONT_SIZE);
      CreateLabel("ANA_VRL", "VR Test:", col3, cy, CLR_TEXT_DIM, FONT_SIZE);
      color vrClr = result.varianceRatio < 0.9 ? CLR_NEON_GREEN : (result.varianceRatio < 1.1 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("ANA_VRV", DoubleToString(result.varianceRatio, 3), col4, cy, vrClr, FONT_SIZE);
      cy += rowH;

      // Row 3
      CreateLabel("ANA_CL", "Correl:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      color cClr = MathAbs(result.priceCorrelation) >= 0.7 ? CLR_NEON_GREEN : CLR_NEON_YELLOW;
      CreateLabel("ANA_CV", DoubleToString(result.priceCorrelation, 3), col2, cy, cClr, FONT_SIZE);
      CreateLabel("ANA_STL", "Stability:", col3, cy, CLR_TEXT_DIM, FONT_SIZE);
      color stClr = result.spreadStability >= 70 ? CLR_NEON_GREEN : (result.spreadStability >= 40 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("ANA_STV", DoubleToString(result.spreadStability, 0) + "%", col4, cy, stClr, FONT_SIZE);
      cy += rowH;

      // Row 4
      CreateLabel("ANA_QL", "Quality:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      color qClr = result.qualityScore >= 70 ? CLR_NEON_GREEN : (result.qualityScore >= 50 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("ANA_QV", IntegerToString(result.qualityScore) + "/100", col2, cy, qClr, FONT_SIZE, "Consolas Bold");
      CreateLabel("ANA_KL", "Kelly:", col3, cy, CLR_TEXT_DIM, FONT_SIZE);
      CreateLabel("ANA_KV", DoubleToString(result.kellyFraction * 100, 1) + "%", col4, cy, CLR_NEON_CYAN, FONT_SIZE);
      cy += rowH;

      // Row 5
      CreateLabel("ANA_HLL", "Half-Life:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      color hlClr = (result.halfLife > 5 && result.halfLife < 50) ? CLR_NEON_GREEN : CLR_NEON_YELLOW;
      CreateLabel("ANA_HLV", DoubleToString(result.halfLife, 1) + " bars", col2, cy, hlClr, FONT_SIZE);
      CreateLabel("ANA_COINTL", "Coint:", col3, cy, CLR_TEXT_DIM, FONT_SIZE);
      string cointText = result.isCointegrated ? "YES" : "NO";
      color cointClr = result.isCointegrated ? CLR_NEON_GREEN : CLR_NEON_RED;
      CreateLabel("ANA_COINTV", cointText, col4, cy, cointClr, FONT_SIZE, "Consolas Bold");
      cy += rowH;

      // Row 6
      CreateLabel("ANA_R2L", "R²:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      color r2Clr = result.rSquared >= 0.8 ? CLR_NEON_GREEN : (result.rSquared >= 0.6 ? CLR_NEON_YELLOW : CLR_TEXT_DIM);
      CreateLabel("ANA_R2V", DoubleToString(result.rSquared * 100, 1) + "%", col2, cy, r2Clr, FONT_SIZE);
      CreateLabel("ANA_ZCL", "Zero Cross:", col3, cy, CLR_TEXT_DIM, FONT_SIZE);
      CreateLabel("ANA_ZCV", IntegerToString(result.zeroCrossings), col4, cy, CLR_TEXT_LIGHT, FONT_SIZE);
   }

   //+------------------------------------------------------------------+
   //| Draw Trade Panel (RIGHT TOP)                                      |
   //+------------------------------------------------------------------+
   void DrawTradePanel(int x, int y, int w, int h, SPairResult &result) {
      // Panel background - SOLID
      CreatePanel("TRD_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title bar
      CreatePanel("TRD_TITLE_BG", x+1, y+1, w-2, TITLE_HEIGHT, CLR_TITLE_BG);
      CreateLabel("TRD_TITLE", "Trade Setup", x + 8, y + 4, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      int cy = y + TITLE_HEIGHT + 10;
      int col1 = x + 10;
      int col2 = x + 100;
      int rowH = 20;

      // Signal
      CreateLabel("TRD_SL", "Signal:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      string sigText = result.signal > 0 ? "LONG" : (result.signal < 0 ? "SHORT" : "WAIT");
      color sigClr = result.signal > 0 ? CLR_NEON_GREEN : (result.signal < 0 ? CLR_NEON_RED : CLR_TEXT_DIM);
      CreateLabel("TRD_SV", sigText, col2, cy, sigClr, FONT_SIZE_TITLE, "Consolas Bold");
      cy += rowH;

      // Strength
      CreateLabel("TRD_STL", "Strength:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      color strClr = m_signalStrength >= 70 ? CLR_NEON_GREEN : (m_signalStrength >= 40 ? CLR_NEON_YELLOW : CLR_TEXT_DIM);
      CreateLabel("TRD_STV", DoubleToString(m_signalStrength, 0) + "%", col2, cy, strClr, FONT_SIZE);
      cy += rowH;

      // Kelly
      CreateLabel("TRD_KL", "Kelly:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      CreateLabel("TRD_KV", DoubleToString(result.kellyFraction * 100, 1) + "%", col2, cy, CLR_NEON_CYAN, FONT_SIZE);
      cy += rowH;

      // Regime
      CreateLabel("TRD_RGL", "Regime:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      CreateLabel("TRD_RGV", GetRegimeText(m_currentRegime), col2, cy, GetRegimeColor(m_currentRegime), FONT_SIZE);
      cy += rowH + 5;

      // Separator
      CreatePanel("TRD_SEP", x + 10, cy, w - 20, 1, CLR_PANEL_BORDER);
      cy += 10;

      // Recommendation
      string recText = "";
      color recClr = CLR_TEXT_DIM;

      bool goodHurst = result.hurstExponent < 0.5;
      bool goodVR = result.varianceRatio < 1.0;
      int factors = (goodHurst?1:0) + (goodVR?1:0) + (result.isCointegrated?1:0);

      if(factors >= 2 && result.qualityScore >= 70 && MathAbs(result.zScore) >= 2.0) {
         recText = result.zScore > 0 ? ">>> SHORT <<<" : ">>> LONG <<<";
         recClr = result.zScore > 0 ? CLR_NEON_RED : CLR_NEON_GREEN;
      }
      else if(factors >= 1 && result.qualityScore >= 50 && MathAbs(result.zScore) >= 1.5) {
         recText = ">> SETUP <<";
         recClr = CLR_NEON_YELLOW;
      }
      else if(!goodHurst && !goodVR) {
         recText = "! AVOID - TRENDING !";
         recClr = CLR_NEON_RED;
      }
      else {
         recText = "- WAIT FOR SETUP -";
         recClr = CLR_TEXT_DIM;
      }

      CreateLabel("TRD_REC", recText, x + 15, cy, recClr, FONT_SIZE_TITLE, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Draw Performance Panel (RIGHT BOTTOM)                             |
   //+------------------------------------------------------------------+
   void DrawPerformancePanel(int x, int y, int w, int h) {
      // Panel background - SOLID
      CreatePanel("PERF_BG", x, y, w, h, CLR_PANEL_BG, CLR_PANEL_BORDER);

      // Title bar
      CreatePanel("PERF_TITLE_BG", x+1, y+1, w-2, TITLE_HEIGHT, CLR_TITLE_BG);
      CreateLabel("PERF_TITLE", "Performance", x + 8, y + 4, CLR_TITLE_TEXT, FONT_SIZE_TITLE, "Consolas Bold");

      int cy = y + TITLE_HEIGHT + 10;
      int col1 = x + 10;
      int col2 = x + 100;
      int rowH = 18;

      // Win Rate
      CreateLabel("PERF_WRL", "Win Rate:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      color wrClr = m_perfStats.winRate >= 60 ? CLR_NEON_GREEN : (m_perfStats.winRate >= 40 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_WRV", DoubleToString(m_perfStats.winRate, 1) + "%", col2, cy, wrClr, FONT_SIZE);
      cy += rowH;

      // Profit Factor
      CreateLabel("PERF_PFL", "PF:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      color pfClr = m_perfStats.profitFactor >= 1.5 ? CLR_NEON_GREEN : (m_perfStats.profitFactor >= 1.0 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_PFV", DoubleToString(m_perfStats.profitFactor, 2), col2, cy, pfClr, FONT_SIZE);
      cy += rowH;

      // Total P/L
      CreateLabel("PERF_PLL", "Total P/L:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      color plClr = m_perfStats.totalPL >= 0 ? CLR_NEON_GREEN : CLR_NEON_RED;
      string plSign = m_perfStats.totalPL >= 0 ? "+" : "";
      CreateLabel("PERF_PLV", plSign + DoubleToString(m_perfStats.totalPL, 2), col2, cy, plClr, FONT_SIZE);
      cy += rowH;

      // Trades
      CreateLabel("PERF_TCL", "Trades:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      string tcText = IntegerToString(m_perfStats.winningTrades) + "W / " + IntegerToString(m_perfStats.losingTrades) + "L";
      CreateLabel("PERF_TCV", tcText, col2, cy, CLR_TEXT_LIGHT, FONT_SIZE);
      cy += rowH;

      // Signals
      CreateLabel("PERF_SGL", "Signals:", col1, cy, CLR_TEXT_DIM, FONT_SIZE);
      CreateLabel("PERF_SGV", IntegerToString(m_perfStats.totalSignals), col2, cy, CLR_NEON_CYAN, FONT_SIZE);
   }

   //+------------------------------------------------------------------+
   //| Handle Click                                                      |
   //+------------------------------------------------------------------+
   int HandleClick(string objName, string &symbolA, string &symbolB, double &beta) {
      if(StringFind(objName, m_prefix) < 0) return 0;

      string name = StringSubstr(objName, StringLen(m_prefix));

      if(name == "BTN_SCAN") return 1;
      if(name == "BTN_TRADE") {
         if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
            symbolA = m_scanResults[m_selectedRow].symbolA;
            symbolB = m_scanResults[m_selectedRow].symbolB;
            beta = m_scanResults[m_selectedRow].beta;
         }
         return 2;
      }
      if(name == "BTN_CLOSE") return 3;

      // Row selection
      for(int i = 0; i < 10; i++) {
         if(StringFind(name, "R" + IntegerToString(i) + "_") >= 0) {
            int newSel = i + m_scrollOffset;
            if(newSel < m_resultCount) {
               m_selectedRow = newSel;
               symbolA = m_scanResults[m_selectedRow].symbolA;
               symbolB = m_scanResults[m_selectedRow].symbolB;
               beta = m_scanResults[m_selectedRow].beta;
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
   bool AreAlertsEnabled() { return m_alertsEnabled; }

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
   bool IsVisible() { return m_isVisible; }

   //+------------------------------------------------------------------+
   //| Get Signal Strength                                               |
   //+------------------------------------------------------------------+
   double GetSignalStrength() { return m_signalStrength; }

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
         if(i < 6) m_corrPairs[i] = pairs[i];
      }

      return count;
   }
};

//+------------------------------------------------------------------+
