//+------------------------------------------------------------------+
//|                                           DLogic_Dashboard.mqh   |
//|              D-LOGIC Professional Pairs Trading Dashboard         |
//|                                        Author: Rafał Dembski     |
//|                                                                   |
//|  Professional Transparent Overlay Dashboard v4.50                 |
//|  - Header: Title + Pairs Scanner                                  |
//|  - Left Panel: Analytics & Metrics                                |
//|  - Bottom: Spread Chart + Performance                             |
//+------------------------------------------------------------------+
#property copyright "Rafał Dembski"
#property strict

#include "DLogic_Engine.mqh"

// ============================================================
// COLOR SCHEME - PROFESSIONAL NEON ON TRANSPARENT
// ============================================================
#define CLR_NEON_GREEN     C'0,255,128'     // Long/Profit
#define CLR_NEON_RED       C'255,60,80'     // Short/Loss
#define CLR_NEON_CYAN      C'0,220,255'     // Info/Accent
#define CLR_NEON_YELLOW    C'255,220,50'    // Warning
#define CLR_NEON_MAGENTA   C'255,50,200'    // Highlight
#define CLR_NEON_ORANGE    C'255,150,50'    // Alert
#define CLR_NEON_BLUE      C'80,150,255'    // Secondary

#define CLR_TEXT_WHITE     C'255,255,255'   // Primary text
#define CLR_TEXT_LIGHT     C'200,210,230'   // Light text
#define CLR_TEXT_DIM       C'140,150,170'   // Secondary text
#define CLR_TEXT_DARK      C'90,100,120'    // Muted text

#define CLR_PANEL_BG       C'15,17,23'      // Semi-transparent panels
#define CLR_BORDER_GLOW    C'60,80,120'     // Subtle glow borders

// ============================================================
// LAYOUT DIMENSIONS
// ============================================================
#define HEADER_HEIGHT      85              // Compact header
#define LEFT_PANEL_WIDTH   280             // Left analytics panel
#define BOTTOM_HEIGHT      140             // Bottom panel
#define MARGIN             8               // Standard margin
#define ROW_HEIGHT         15              // Text row height

// ============================================================
// REGIME TYPES
// ============================================================
enum ENUM_REGIME {
   REGIME_MEAN_REVERT,
   REGIME_TRENDING,
   REGIME_VOLATILE,
   REGIME_CONSOLIDATION
};

// ============================================================
// SIGNAL HISTORY STRUCTURE
// ============================================================
struct SSignalHistory {
   datetime   time;
   string     pairName;
   int        signal;
   double     zScore;
   double     strength;
   bool       executed;
   double     entryPL;
};

// ============================================================
// PERFORMANCE TRACKING
// ============================================================
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
//| CDashboard - Professional Transparent Overlay                     |
//+------------------------------------------------------------------+
class CDashboard {
private:
   string         m_prefix;
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
   double         m_lastAlertZ;
   datetime       m_lastAlertTime;

   //+------------------------------------------------------------------+
   //| Create Label - Core function                                      |
   //+------------------------------------------------------------------+
   void CreateLabel(string name, string text, int x, int y, color clr,
                    int fontSize = 8, string font = "Consolas") {
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
   //| Create Rectangle with transparency support                        |
   //+------------------------------------------------------------------+
   void CreateRect(string name, int x, int y, int w, int h, color clr,
                   color borderClr = clrNONE, int transparency = 0) {
      string objName = m_prefix + name;

      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      }

      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);

      if(borderClr != clrNONE) {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, borderClr);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      } else {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      }
   }

   //+------------------------------------------------------------------+
   //| Create thin line separator                                        |
   //+------------------------------------------------------------------+
   void CreateLine(string name, int x1, int y1, int x2, int y2, color clr) {
      // Use rectangle as line
      string objName = m_prefix + name;
      int w = MathMax(1, MathAbs(x2 - x1));
      int h = MathMax(1, MathAbs(y2 - y1));

      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      }

      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, MathMin(x1, x2));
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, MathMin(y1, y2));
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   }

   //+------------------------------------------------------------------+
   //| Create Button                                                     |
   //+------------------------------------------------------------------+
   void CreateButton(string name, string text, int x, int y, int w, int h,
                     color bgClr, color txtClr, int fontSize = 8) {
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
      ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, CLR_BORDER_GLOW);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetString(0, objName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   }

   //+------------------------------------------------------------------+
   //| Delete all dashboard objects                                      |
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
   string GetSignalText(int signal, double z) {
      if(signal == 2) return "▲▲ LONG";
      if(signal == 1) return "▲ LONG";
      if(signal == -1) return "▼ SHORT";
      if(signal == -2) return "▼▼ SHORT";
      if(MathAbs(z) <= 0.5) return "◆ EXIT";
      return "● WAIT";
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

      // Z-Score component (40%)
      double zComponent = MathMin(40, MathAbs(result.zScore) * 15);
      strength += zComponent;

      // Cointegration (25%)
      if(result.isCointegrated) strength += 25;

      // Hurst mean reversion (20%)
      if(result.hurstExponent < 0.5) {
         strength += (0.5 - result.hurstExponent) * 40;
      }

      // Stability (15%)
      strength += result.spreadStability * 0.15;

      return MathMin(100, strength);
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CDashboard() {
      m_prefix = "DLOGIC_";
      m_isVisible = true;
      m_resultCount = 0;
      m_selectedRow = 0;
      m_scrollOffset = 0;
      m_historySize = 100;
      m_historyCount = 0;
      m_maxHistory = 50;
      m_alertsEnabled = true;
      m_lastAlertZ = 0;
      m_lastAlertTime = 0;
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
   //| Initialize Dashboard                                              |
   //+------------------------------------------------------------------+
   void Init() {
      DeleteAll();
      m_isVisible = true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize Dashboard                                            |
   //+------------------------------------------------------------------+
   void Deinit() {
      DeleteAll();
   }

   //+------------------------------------------------------------------+
   //| Update scan results                                               |
   //+------------------------------------------------------------------+
   void UpdateResults(SPairResult &results[], int count) {
      m_resultCount = count;
      ArrayResize(m_scanResults, count);

      for(int i = 0; i < count; i++) {
         m_scanResults[i] = results[i];
      }

      if(m_selectedRow >= count) m_selectedRow = MathMax(0, count - 1);

      // Update analytics for selected pair
      if(count > 0 && m_selectedRow < count) {
         m_currentRegime = DetectRegime(m_scanResults[m_selectedRow]);
         m_signalStrength = CalculateSignalStrength(m_scanResults[m_selectedRow]);
      }
   }

   //+------------------------------------------------------------------+
   //| Update spread history                                             |
   //+------------------------------------------------------------------+
   void UpdateSpreadHistory(double spread, double zScore) {
      // Shift arrays
      for(int i = m_historySize - 1; i > 0; i--) {
         m_spreadHistory[i] = m_spreadHistory[i-1];
         m_zScoreHistory[i] = m_zScoreHistory[i-1];
      }
      m_spreadHistory[0] = spread;
      m_zScoreHistory[0] = zScore;
   }

   //+------------------------------------------------------------------+
   //| Main Draw function                                                |
   //+------------------------------------------------------------------+
   void Draw() {
      if(!m_isVisible) return;

      int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

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
         result.spreadStability = 0;
         result.priceCorrelation = 0;
      }

      // Draw panels
      DrawHeader(chartW);
      DrawLeftPanel(chartH, result);
      DrawBottom(chartW, chartH, result);

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Draw Header (Top)                                                 |
   //+------------------------------------------------------------------+
   void DrawHeader(int chartW) {
      int x = MARGIN;
      int y = 5;

      // Semi-transparent header background
      CreateRect("HDR_BG", 0, 0, chartW, HEADER_HEIGHT, CLR_PANEL_BG, CLR_BORDER_GLOW);

      // Title section
      CreateLabel("TITLE", "D-LOGIC", x, y, CLR_NEON_CYAN, 14, "Consolas Bold");
      CreateLabel("TITLE2", "QUANT", x + 95, y, CLR_TEXT_WHITE, 14, "Consolas Bold");
      CreateLabel("VERSION", "v4.50", x + 170, y + 4, CLR_TEXT_DIM, 8);

      // Status
      string statusText = m_resultCount > 0 ? "● LIVE" : "○ IDLE";
      color statusClr = m_resultCount > 0 ? CLR_NEON_GREEN : CLR_TEXT_DIM;
      CreateLabel("STATUS", statusText, x + 220, y + 4, statusClr, 8);

      // Current time
      CreateLabel("TIME", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
                  chartW - 120, y + 2, CLR_TEXT_DIM, 8);

      // Separator line
      CreateLine("HDR_LINE", x, y + 22, chartW - MARGIN, y + 22, CLR_BORDER_GLOW);

      // Scanner section
      DrawScanner(x, y + 28, chartW - MARGIN * 2);
   }

   //+------------------------------------------------------------------+
   //| Draw Scanner Table                                                |
   //+------------------------------------------------------------------+
   void DrawScanner(int x, int y, int w) {
      // Column headers
      int cols[] = {0, 25, 130, 180, 240, 300, 365, 430, 500, 570, 650, 730};

      CreateLabel("SC_H0", "●", x + cols[0], y, CLR_TEXT_DIM, 7);
      CreateLabel("SC_H1", "PAIR", x + cols[1], y, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("SC_H2", "Z", x + cols[2], y, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("SC_H3", "SIGNAL", x + cols[3], y, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("SC_H4", "BETA", x + cols[4], y, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("SC_H5", "R²", x + cols[5], y, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("SC_H6", "HL", x + cols[6], y, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("SC_H7", "HURST", x + cols[7], y, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("SC_H8", "VR", x + cols[8], y, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("SC_H9", "CORR", x + cols[9], y, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("SC_H10", "QUAL", x + cols[10], y, CLR_TEXT_DIM, 7, "Consolas Bold");

      // Header underline
      CreateLine("SC_HLINE", x, y + 12, x + 800, y + 12, CLR_BORDER_GLOW);

      // Data rows
      int rowY = y + 16;
      int maxRows = MathMin(4, m_resultCount);

      for(int i = 0; i < maxRows; i++) {
         int idx = i + m_scrollOffset;
         if(idx >= m_resultCount) break;

         SPairResult r = m_scanResults[idx];
         string rowPrefix = "SC_R" + IntegerToString(i) + "_";
         bool isSelected = (idx == m_selectedRow);

         // Selection indicator
         color rowColor = isSelected ? CLR_NEON_CYAN : CLR_TEXT_LIGHT;
         string selectMark = isSelected ? "▶" : (r.isCointegrated ? "●" : "○");
         color selectClr = r.isCointegrated ? CLR_NEON_GREEN : CLR_TEXT_DARK;
         if(isSelected) selectClr = CLR_NEON_CYAN;

         CreateLabel(rowPrefix + "SEL", selectMark, x + cols[0], rowY, selectClr, 7);
         CreateLabel(rowPrefix + "PAIR", r.pairName, x + cols[1], rowY, rowColor, 7, isSelected ? "Consolas Bold" : "Consolas");

         // Z-Score with color
         color zClr = GetZScoreColor(r.zScore);
         string zText = (r.zScore > 0 ? "+" : "") + DoubleToString(r.zScore, 2);
         CreateLabel(rowPrefix + "Z", zText, x + cols[2], rowY, zClr, 7, "Consolas Bold");

         // Signal
         color sigClr = r.signal > 0 ? CLR_NEON_GREEN : (r.signal < 0 ? CLR_NEON_RED : CLR_TEXT_DIM);
         CreateLabel(rowPrefix + "SIG", GetSignalText(r.signal, r.zScore), x + cols[3], rowY, sigClr, 7);

         // Beta
         CreateLabel(rowPrefix + "BETA", DoubleToString(r.beta, 4), x + cols[4], rowY, CLR_TEXT_LIGHT, 7);

         // R²
         color r2Clr = r.rSquared >= 0.8 ? CLR_NEON_GREEN : (r.rSquared >= 0.6 ? CLR_NEON_YELLOW : CLR_TEXT_DIM);
         CreateLabel(rowPrefix + "R2", DoubleToString(r.rSquared, 2), x + cols[5], rowY, r2Clr, 7);

         // Half-life
         color hlClr = (r.halfLife > 5 && r.halfLife < 50) ? CLR_NEON_GREEN : CLR_NEON_YELLOW;
         CreateLabel(rowPrefix + "HL", DoubleToString(r.halfLife, 1), x + cols[6], rowY, hlClr, 7);

         // Hurst
         color hClr = r.hurstExponent < 0.45 ? CLR_NEON_GREEN : (r.hurstExponent < 0.55 ? CLR_NEON_YELLOW : CLR_NEON_RED);
         CreateLabel(rowPrefix + "HURST", DoubleToString(r.hurstExponent, 2), x + cols[7], rowY, hClr, 7);

         // VR
         color vrClr = r.varianceRatio < 0.9 ? CLR_NEON_GREEN : (r.varianceRatio < 1.1 ? CLR_NEON_YELLOW : CLR_NEON_RED);
         CreateLabel(rowPrefix + "VR", DoubleToString(r.varianceRatio, 2), x + cols[8], rowY, vrClr, 7);

         // Correlation
         color corrClr = MathAbs(r.priceCorrelation) >= 0.7 ? CLR_NEON_GREEN : CLR_NEON_YELLOW;
         CreateLabel(rowPrefix + "CORR", DoubleToString(r.priceCorrelation, 2), x + cols[9], rowY, corrClr, 7);

         // Quality
         color qClr = r.qualityScore >= 70 ? CLR_NEON_GREEN : (r.qualityScore >= 50 ? CLR_NEON_YELLOW : CLR_NEON_RED);
         CreateLabel(rowPrefix + "QUAL", IntegerToString(r.qualityScore), x + cols[10], rowY, qClr, 7, "Consolas Bold");

         rowY += ROW_HEIGHT;
      }
   }

   //+------------------------------------------------------------------+
   //| Draw Left Panel (Analytics)                                       |
   //+------------------------------------------------------------------+
   void DrawLeftPanel(int chartH, SPairResult &result) {
      int x = MARGIN;
      int y = HEADER_HEIGHT + MARGIN;
      int w = LEFT_PANEL_WIDTH;
      int h = chartH - HEADER_HEIGHT - BOTTOM_HEIGHT - MARGIN * 3;

      // Panel background
      CreateRect("LEFT_BG", 0, y, w + MARGIN, h, CLR_PANEL_BG, CLR_BORDER_GLOW);

      // Z-SCORE DISPLAY
      int secY = y + 8;
      CreateLabel("L_ZTITLE", "Z-SCORE", x, secY, CLR_NEON_CYAN, 8, "Consolas Bold");

      secY += 18;
      color zClr = GetZScoreColor(result.zScore);
      string zText = (result.zScore > 0 ? "+" : "") + DoubleToString(result.zScore, 3);
      CreateLabel("L_ZVALUE", zText, x, secY, zClr, 22, "Consolas Bold");

      // Zone text
      secY += 32;
      string zoneText = "NEUTRAL";
      color zoneClr = CLR_TEXT_DIM;
      if(result.zScore >= 2.5 || result.zScore <= -2.5) { zoneText = "⚠ STOP ZONE"; zoneClr = CLR_NEON_RED; }
      else if(result.zScore >= 2.0) { zoneText = "▼ SHORT ZONE"; zoneClr = CLR_NEON_ORANGE; }
      else if(result.zScore <= -2.0) { zoneText = "▲ LONG ZONE"; zoneClr = CLR_NEON_GREEN; }
      else if(MathAbs(result.zScore) <= 0.5) { zoneText = "◆ EXIT ZONE"; zoneClr = CLR_NEON_YELLOW; }
      CreateLabel("L_ZONE", zoneText, x, secY, zoneClr, 9, "Consolas Bold");

      // Separator
      secY += 18;
      CreateLine("L_SEP1", x, secY, x + w - 20, secY, CLR_BORDER_GLOW);

      // SIGNAL STRENGTH
      secY += 10;
      CreateLabel("L_SIGTITLE", "SIGNAL STRENGTH", x, secY, CLR_NEON_MAGENTA, 8, "Consolas Bold");

      secY += 16;
      // Strength bar background
      CreateRect("L_SIGBAR_BG", x, secY, w - 20, 8, C'30,35,45');
      // Strength bar fill
      int fillW = (int)((w - 20) * m_signalStrength / 100.0);
      color barClr = m_signalStrength >= 70 ? CLR_NEON_GREEN : (m_signalStrength >= 40 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateRect("L_SIGBAR", x, secY, fillW, 8, barClr);

      secY += 12;
      CreateLabel("L_SIGVAL", DoubleToString(m_signalStrength, 0) + "%", x, secY, barClr, 9, "Consolas Bold");

      // REGIME
      secY += 20;
      CreateLabel("L_REGTITLE", "REGIME", x, secY, CLR_NEON_BLUE, 8, "Consolas Bold");
      secY += 14;

      string regText = "";
      color regClr = CLR_TEXT_DIM;
      switch(m_currentRegime) {
         case REGIME_MEAN_REVERT: regText = "● MEAN REVERT"; regClr = CLR_NEON_GREEN; break;
         case REGIME_TRENDING: regText = "◆ TRENDING"; regClr = CLR_NEON_RED; break;
         case REGIME_VOLATILE: regText = "▲ VOLATILE"; regClr = CLR_NEON_ORANGE; break;
         default: regText = "○ CONSOLIDATION"; regClr = CLR_TEXT_DIM;
      }
      CreateLabel("L_REGIME", regText, x, secY, regClr, 9, "Consolas Bold");

      // Separator
      secY += 18;
      CreateLine("L_SEP2", x, secY, x + w - 20, secY, CLR_BORDER_GLOW);

      // QUANT METRICS
      secY += 10;
      CreateLabel("L_METR", "QUANT METRICS", x, secY, CLR_NEON_YELLOW, 8, "Consolas Bold");
      secY += 16;

      int labelX = x;
      int valX = x + 85;

      // Hurst
      color hClr = result.hurstExponent < 0.45 ? CLR_NEON_GREEN : (result.hurstExponent < 0.55 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("L_M_HL", "Hurst:", labelX, secY, CLR_TEXT_DIM, 7);
      CreateLabel("L_M_HV", DoubleToString(result.hurstExponent, 3), valX, secY, hClr, 7, "Consolas Bold");
      secY += ROW_HEIGHT;

      // VR Test
      color vrClr = result.varianceRatio < 0.9 ? CLR_NEON_GREEN : (result.varianceRatio < 1.1 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("L_M_VRL", "VR Test:", labelX, secY, CLR_TEXT_DIM, 7);
      CreateLabel("L_M_VRV", DoubleToString(result.varianceRatio, 3), valX, secY, vrClr, 7, "Consolas Bold");
      secY += ROW_HEIGHT;

      // Correlation
      color corrClr = MathAbs(result.priceCorrelation) >= 0.7 ? CLR_NEON_GREEN : CLR_NEON_YELLOW;
      CreateLabel("L_M_CRL", "Correl:", labelX, secY, CLR_TEXT_DIM, 7);
      CreateLabel("L_M_CRV", DoubleToString(result.priceCorrelation, 3), valX, secY, corrClr, 7, "Consolas Bold");
      secY += ROW_HEIGHT;

      // Autocorr
      color acClr = result.autocorrelation > 0.3 ? CLR_NEON_GREEN : CLR_NEON_YELLOW;
      CreateLabel("L_M_ACL", "AutoCorr:", labelX, secY, CLR_TEXT_DIM, 7);
      CreateLabel("L_M_ACV", DoubleToString(result.autocorrelation, 3), valX, secY, acClr, 7, "Consolas Bold");
      secY += ROW_HEIGHT;

      // Stability
      color stClr = result.spreadStability >= 70 ? CLR_NEON_GREEN : (result.spreadStability >= 40 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("L_M_STL", "Stability:", labelX, secY, CLR_TEXT_DIM, 7);
      CreateLabel("L_M_STV", DoubleToString(result.spreadStability, 0) + "%", valX, secY, stClr, 7, "Consolas Bold");
      secY += ROW_HEIGHT;

      // Quality Score
      color qClr = result.qualityScore >= 70 ? CLR_NEON_GREEN : (result.qualityScore >= 50 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("L_M_QL", "Quality:", labelX, secY, CLR_TEXT_DIM, 7);
      CreateLabel("L_M_QV", IntegerToString(result.qualityScore) + "/100", valX, secY, qClr, 7, "Consolas Bold");
      secY += ROW_HEIGHT;

      // Kelly
      CreateLabel("L_M_KL", "Kelly:", labelX, secY, CLR_TEXT_DIM, 7);
      CreateLabel("L_M_KV", DoubleToString(result.kellyFraction * 100, 1) + "%", valX, secY, CLR_NEON_CYAN, 7, "Consolas Bold");
      secY += ROW_HEIGHT;

      // Opt Entry
      CreateLabel("L_M_OEL", "Opt Entry:", labelX, secY, CLR_TEXT_DIM, 7);
      CreateLabel("L_M_OEV", "Z=" + DoubleToString(result.optimalEntryZ, 2), valX, secY, CLR_NEON_CYAN, 7, "Consolas Bold");

      // Separator
      secY += 20;
      CreateLine("L_SEP3", x, secY, x + w - 20, secY, CLR_BORDER_GLOW);

      // TRADE RECOMMENDATION
      secY += 10;
      CreateLabel("L_RECTITLE", "RECOMMENDATION", x, secY, CLR_TEXT_WHITE, 8, "Consolas Bold");
      secY += 16;

      // Calculate recommendation
      bool goodHurst = result.hurstExponent < 0.5;
      bool goodVR = result.varianceRatio < 1.0;
      bool goodCorr = MathAbs(result.priceCorrelation) >= 0.6;
      bool goodStab = result.spreadStability >= 50;
      bool strongZ = MathAbs(result.zScore) >= result.optimalEntryZ;
      int factors = (goodHurst?1:0) + (goodVR?1:0) + (goodCorr?1:0) + (goodStab?1:0);

      string recText = "";
      color recClr = CLR_TEXT_DIM;

      if(factors >= 3 && strongZ && result.qualityScore >= 70) {
         recText = result.zScore > 0 ? "★★★ STRONG SHORT" : "★★★ STRONG LONG";
         recClr = result.zScore > 0 ? CLR_NEON_RED : CLR_NEON_GREEN;
      }
      else if(factors >= 2 && result.qualityScore >= 50 && MathAbs(result.zScore) >= 1.5) {
         recText = result.zScore > 0 ? "★★ SHORT SETUP" : "★★ LONG SETUP";
         recClr = CLR_NEON_YELLOW;
      }
      else if(!goodHurst && !goodVR) {
         recText = "⚠ AVOID - TRENDING";
         recClr = CLR_NEON_RED;
      }
      else if(!goodStab) {
         recText = "⚠ AVOID - UNSTABLE";
         recClr = CLR_NEON_ORANGE;
      }
      else {
         recText = "○ WAIT FOR SETUP";
         recClr = CLR_TEXT_DIM;
      }

      CreateLabel("L_REC", recText, x, secY, recClr, 10, "Consolas Bold");

      // BUTTONS at bottom of left panel
      secY = y + h - 35;
      CreateButton("BTN_SCAN", "SCAN", x, secY, 60, 22, C'20,60,35', CLR_NEON_GREEN, 8);
      CreateButton("BTN_TRADE", "TRADE", x + 68, secY, 60, 22, C'20,40,80', CLR_NEON_CYAN, 8);
      CreateButton("BTN_CLOSE", "CLOSE", x + 136, secY, 60, 22, C'80,30,30', CLR_NEON_RED, 8);
   }

   //+------------------------------------------------------------------+
   //| Draw Bottom Panel                                                 |
   //+------------------------------------------------------------------+
   void DrawBottom(int chartW, int chartH, SPairResult &result) {
      int x = LEFT_PANEL_WIDTH + MARGIN * 2;
      int y = chartH - BOTTOM_HEIGHT;
      int w = chartW - LEFT_PANEL_WIDTH - MARGIN * 3;
      int h = BOTTOM_HEIGHT;

      // Background
      CreateRect("BOT_BG", x - MARGIN, y, w + MARGIN * 2, h, CLR_PANEL_BG, CLR_BORDER_GLOW);

      // Split into 3 sections
      int sec1W = (int)(w * 0.40);  // Spread mini-chart
      int sec2W = (int)(w * 0.30);  // Performance
      int sec3W = w - sec1W - sec2W; // Pair info

      // SECTION 1: Spread Chart
      int s1x = x;
      CreateLabel("BOT_S1T", "SPREAD: " + result.pairName, s1x, y + 5, CLR_NEON_CYAN, 8, "Consolas Bold");
      CreateLabel("BOT_S1B", "β=" + DoubleToString(result.beta, 4) + "  μ=" + DoubleToString(result.spreadMean, 5),
                  s1x, y + 18, CLR_TEXT_DIM, 7);

      // Mini spread visualization
      DrawMiniSpread(s1x, y + 35, sec1W - 10, h - 45, result);

      // SECTION 2: Performance
      int s2x = x + sec1W + 10;
      CreateLabel("BOT_S2T", "PERFORMANCE", s2x, y + 5, CLR_NEON_YELLOW, 8, "Consolas Bold");

      int perfY = y + 22;

      // Win Rate
      color wrClr = m_perfStats.winRate >= 55 ? CLR_NEON_GREEN : (m_perfStats.winRate >= 45 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("BOT_WRL", "Win Rate:", s2x, perfY, CLR_TEXT_DIM, 7);
      CreateLabel("BOT_WRV", DoubleToString(m_perfStats.winRate, 1) + "%", s2x + 70, perfY, wrClr, 7, "Consolas Bold");
      perfY += 14;

      // P&L
      color plClr = m_perfStats.totalPL >= 0 ? CLR_NEON_GREEN : CLR_NEON_RED;
      string plStr = (m_perfStats.totalPL >= 0 ? "+" : "") + DoubleToString(m_perfStats.totalPL, 2);
      CreateLabel("BOT_PLL", "P&L:", s2x, perfY, CLR_TEXT_DIM, 7);
      CreateLabel("BOT_PLV", "$" + plStr, s2x + 70, perfY, plClr, 7, "Consolas Bold");
      perfY += 14;

      // Trades
      CreateLabel("BOT_TRL", "Trades:", s2x, perfY, CLR_TEXT_DIM, 7);
      CreateLabel("BOT_TRV", IntegerToString(m_perfStats.executedTrades), s2x + 70, perfY, CLR_TEXT_LIGHT, 7, "Consolas Bold");
      perfY += 14;

      // Profit Factor
      color pfClr = m_perfStats.profitFactor >= 1.5 ? CLR_NEON_GREEN : (m_perfStats.profitFactor >= 1.0 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("BOT_PFL", "PF:", s2x, perfY, CLR_TEXT_DIM, 7);
      CreateLabel("BOT_PFV", DoubleToString(m_perfStats.profitFactor, 2), s2x + 70, perfY, pfClr, 7, "Consolas Bold");
      perfY += 14;

      // Sharpe
      color srClr = m_perfStats.sharpeRatio >= 1.5 ? CLR_NEON_GREEN : (m_perfStats.sharpeRatio >= 0.5 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("BOT_SRL", "Sharpe:", s2x, perfY, CLR_TEXT_DIM, 7);
      CreateLabel("BOT_SRV", DoubleToString(m_perfStats.sharpeRatio, 2), s2x + 70, perfY, srClr, 7, "Consolas Bold");
      perfY += 14;

      // Max DD
      color ddClr = m_perfStats.maxDrawdown <= 5 ? CLR_NEON_GREEN : (m_perfStats.maxDrawdown <= 15 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("BOT_DDL", "Max DD:", s2x, perfY, CLR_TEXT_DIM, 7);
      CreateLabel("BOT_DDV", DoubleToString(m_perfStats.maxDrawdown, 1) + "%", s2x + 70, perfY, ddClr, 7, "Consolas Bold");

      // SECTION 3: Selected Pair Info
      int s3x = x + sec1W + sec2W + 20;
      CreateLabel("BOT_S3T", "SELECTED PAIR", s3x, y + 5, CLR_NEON_MAGENTA, 8, "Consolas Bold");

      int infoY = y + 22;
      CreateLabel("BOT_PN", result.pairName, s3x, infoY, CLR_TEXT_WHITE, 9, "Consolas Bold");
      infoY += 16;

      // Signal
      color sigClr = result.signal > 0 ? CLR_NEON_GREEN : (result.signal < 0 ? CLR_NEON_RED : CLR_TEXT_DIM);
      CreateLabel("BOT_SIG", GetSignalText(result.signal, result.zScore), s3x, infoY, sigClr, 9, "Consolas Bold");
      infoY += 16;

      // Stats
      CreateLabel("BOT_R2L", "R²: " + DoubleToString(result.rSquared, 3), s3x, infoY, CLR_TEXT_LIGHT, 7);
      infoY += 13;
      CreateLabel("BOT_HLL", "Half-Life: " + DoubleToString(result.halfLife, 1) + " bars", s3x, infoY, CLR_TEXT_LIGHT, 7);
      infoY += 13;
      CreateLabel("BOT_ZCL", "Zero Cross: " + IntegerToString(result.zeroCrossings), s3x, infoY, CLR_TEXT_LIGHT, 7);
      infoY += 13;

      // Cointegration status
      string cointText = result.isCointegrated ? "✓ COINTEGRATED" : "✗ NOT COINTEGRATED";
      color cointClr = result.isCointegrated ? CLR_NEON_GREEN : CLR_NEON_RED;
      CreateLabel("BOT_COINT", cointText, s3x, infoY, cointClr, 7, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Draw Mini Spread Chart                                            |
   //+------------------------------------------------------------------+
   void DrawMiniSpread(int x, int y, int w, int h, SPairResult &result) {
      // Chart background
      CreateRect("MINI_BG", x, y, w, h, C'20,22,30', CLR_BORDER_GLOW);

      // Find min/max for scaling
      double minVal = 999999, maxVal = -999999;
      int validPoints = 0;

      for(int i = 0; i < m_historySize && i < 60; i++) {
         if(m_zScoreHistory[i] != 0 || i == 0) {
            minVal = MathMin(minVal, m_zScoreHistory[i]);
            maxVal = MathMax(maxVal, m_zScoreHistory[i]);
            validPoints++;
         }
      }

      if(validPoints < 5) {
         CreateLabel("MINI_NO", "Collecting data...", x + 10, y + h/2 - 5, CLR_TEXT_DIM, 7);
         return;
      }

      // Ensure range
      double range = maxVal - minVal;
      if(range < 0.5) {
         minVal -= 0.5;
         maxVal += 0.5;
         range = 1.0;
      }

      // Draw reference lines
      int zeroY = y + (int)((maxVal - 0) / range * (h - 10)) + 5;
      int upper2Y = y + (int)((maxVal - 2.0) / range * (h - 10)) + 5;
      int lower2Y = y + (int)((maxVal - (-2.0)) / range * (h - 10)) + 5;

      // Clamp to chart area
      zeroY = MathMax(y + 2, MathMin(y + h - 2, zeroY));
      upper2Y = MathMax(y + 2, MathMin(y + h - 2, upper2Y));
      lower2Y = MathMax(y + 2, MathMin(y + h - 2, lower2Y));

      CreateLine("MINI_Z0", x + 2, zeroY, x + w - 2, zeroY, CLR_TEXT_DARK);
      CreateLine("MINI_Z2U", x + 2, upper2Y, x + w - 2, upper2Y, C'60,30,30');
      CreateLine("MINI_Z2L", x + 2, lower2Y, x + w - 2, lower2Y, C'30,60,30');

      // Draw Z labels
      CreateLabel("MINI_L0", "0", x + w - 12, zeroY - 4, CLR_TEXT_DARK, 6);
      CreateLabel("MINI_L2U", "+2", x + w - 15, upper2Y - 4, CLR_NEON_RED, 6);
      CreateLabel("MINI_L2L", "-2", x + w - 15, lower2Y - 4, CLR_NEON_GREEN, 6);

      // Draw spread line as points
      int pointCount = MathMin(validPoints, 60);
      double stepX = (double)(w - 10) / pointCount;

      for(int i = 0; i < pointCount - 1; i++) {
         int idx = pointCount - 1 - i;
         double val = m_zScoreHistory[idx];

         int px = x + 5 + (int)(i * stepX);
         int py = y + 5 + (int)((maxVal - val) / range * (h - 10));
         py = MathMax(y + 2, MathMin(y + h - 2, py));

         color ptClr = GetZScoreColor(val);
         CreateRect("MINI_P" + IntegerToString(i), px, py - 1, 2, 2, ptClr);
      }

      // Current value marker
      int currPx = x + w - 10;
      int currPy = y + 5 + (int)((maxVal - m_zScoreHistory[0]) / range * (h - 10));
      currPy = MathMax(y + 2, MathMin(y + h - 2, currPy));
      CreateRect("MINI_CURR", currPx - 2, currPy - 2, 5, 5, CLR_TEXT_WHITE);
   }

   //+------------------------------------------------------------------+
   //| Handle click events                                               |
   //+------------------------------------------------------------------+
   bool OnClick(string objName) {
      if(StringFind(objName, m_prefix) < 0) return false;

      string name = StringSubstr(objName, StringLen(m_prefix));

      if(name == "BTN_SCAN") {
         // Trigger scan - handled by main EA
         return true;
      }
      else if(name == "BTN_TRADE") {
         // Execute trade - handled by main EA
         return true;
      }
      else if(name == "BTN_CLOSE") {
         // Close all - handled by main EA
         return true;
      }

      // Check for row selection
      for(int i = 0; i < 4; i++) {
         if(StringFind(name, "SC_R" + IntegerToString(i) + "_") >= 0) {
            int newSel = i + m_scrollOffset;
            if(newSel < m_resultCount) {
               m_selectedRow = newSel;
               if(m_resultCount > 0) {
                  m_currentRegime = DetectRegime(m_scanResults[m_selectedRow]);
                  m_signalStrength = CalculateSignalStrength(m_scanResults[m_selectedRow]);
               }
               Draw();
               return true;
            }
         }
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Handle keyboard events                                            |
   //+------------------------------------------------------------------+
   bool OnKey(int key) {
      // Arrow up/down for selection
      if(key == 38) { // Up
         if(m_selectedRow > 0) {
            m_selectedRow--;
            if(m_selectedRow < m_scrollOffset) m_scrollOffset = m_selectedRow;
            Draw();
            return true;
         }
      }
      else if(key == 40) { // Down
         if(m_selectedRow < m_resultCount - 1) {
            m_selectedRow++;
            if(m_selectedRow >= m_scrollOffset + 4) m_scrollOffset = m_selectedRow - 3;
            Draw();
            return true;
         }
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Add trade to performance stats                                    |
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
         m_perfStats.grossProfit / m_perfStats.grossLoss :
         (m_perfStats.grossProfit > 0 ? 99.9 : 1.0);

      m_perfStats.avgWin = m_perfStats.winningTrades > 0 ?
         m_perfStats.grossProfit / m_perfStats.winningTrades : 0;

      m_perfStats.avgLoss = m_perfStats.losingTrades > 0 ?
         m_perfStats.grossLoss / m_perfStats.losingTrades : 0;

      m_perfStats.expectancy = m_perfStats.avgWin * (m_perfStats.winRate / 100) -
                               m_perfStats.avgLoss * (1 - m_perfStats.winRate / 100);
   }

   //+------------------------------------------------------------------+
   //| Get selected pair                                                 |
   //+------------------------------------------------------------------+
   bool GetSelectedPair(SPairResult &result) {
      if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
         result = m_scanResults[m_selectedRow];
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Get button state                                                  |
   //+------------------------------------------------------------------+
   string GetClickedButton() {
      // Check button states
      if(ObjectGetInteger(0, m_prefix + "BTN_SCAN", OBJPROP_STATE) == 1) {
         ObjectSetInteger(0, m_prefix + "BTN_SCAN", OBJPROP_STATE, 0);
         return "SCAN";
      }
      if(ObjectGetInteger(0, m_prefix + "BTN_TRADE", OBJPROP_STATE) == 1) {
         ObjectSetInteger(0, m_prefix + "BTN_TRADE", OBJPROP_STATE, 0);
         return "TRADE";
      }
      if(ObjectGetInteger(0, m_prefix + "BTN_CLOSE", OBJPROP_STATE) == 1) {
         ObjectSetInteger(0, m_prefix + "BTN_CLOSE", OBJPROP_STATE, 0);
         return "CLOSE";
      }
      return "";
   }

   //+------------------------------------------------------------------+
   //| Get top pairs for correlation                                     |
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

   //+------------------------------------------------------------------+
   //| Reset stats                                                       |
   //+------------------------------------------------------------------+
   void ResetStats() {
      ZeroMemory(m_perfStats);
      m_perfStats.profitFactor = 1.0;
   }

   // ============================================================
   // COMPATIBILITY METHODS (for main EA interface)
   // ============================================================

   //+------------------------------------------------------------------+
   //| Set Position (stub - not used in overlay mode)                    |
   //+------------------------------------------------------------------+
   void SetPosition(int x, int y) {
      // Not used in overlay mode - panels positioned dynamically
   }

   //+------------------------------------------------------------------+
   //| Configure Alerts                                                  |
   //+------------------------------------------------------------------+
   void ConfigureAlerts(bool enabled, double zThreshold, double strengthThreshold) {
      m_alertsEnabled = enabled;
      // Store thresholds for alert processing
   }

   //+------------------------------------------------------------------+
   //| Are Alerts Enabled                                                |
   //+------------------------------------------------------------------+
   bool AreAlertsEnabled() {
      return m_alertsEnabled;
   }

   //+------------------------------------------------------------------+
   //| Sort By Z-Score (sort the results array)                          |
   //+------------------------------------------------------------------+
   void SortByZScore() {
      // Sort by absolute Z-Score descending
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
   //| Update Spread History (array version)                             |
   //+------------------------------------------------------------------+
   void UpdateSpreadHistory(double &spread[], double &zScore[], int size) {
      // Copy arrays to internal storage
      int copySize = MathMin(size, m_historySize);
      for(int i = 0; i < copySize; i++) {
         m_spreadHistory[i] = spread[i];
         m_zScoreHistory[i] = zScore[i];
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
   //| Update Info (positions, P&L, etc.)                                |
   //+------------------------------------------------------------------+
   void UpdateInfo(double unrealizedPL, int positionCount, double maxDD, double activeBeta) {
      m_perfStats.maxDrawdown = maxDD;
      // Other info can be displayed if needed
   }

   //+------------------------------------------------------------------+
   //| Handle Click - returns action code and fills pair info            |
   //+------------------------------------------------------------------+
   int HandleClick(string objName, string &symbolA, string &symbolB, double &beta) {
      if(StringFind(objName, m_prefix) < 0) return 0;

      string name = StringSubstr(objName, StringLen(m_prefix));

      // Button clicks
      if(name == "BTN_SCAN") {
         return 1;  // Scan
      }
      else if(name == "BTN_TRADE") {
         // Fill selected pair info
         if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
            symbolA = m_scanResults[m_selectedRow].symbolA;
            symbolB = m_scanResults[m_selectedRow].symbolB;
            beta = m_scanResults[m_selectedRow].beta;
         }
         return 2;  // Execute
      }
      else if(name == "BTN_CLOSE") {
         return 3;  // Close all
      }

      // Row selection
      for(int i = 0; i < 4; i++) {
         if(StringFind(name, "SC_R" + IntegerToString(i) + "_") >= 0) {
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
               return 4;  // Row selected
            }
         }
      }

      return 0;  // No action
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
   //| Record Signal to history                                          |
   //+------------------------------------------------------------------+
   void RecordSignal(string pairName, int signal, double zScore, double strength) {
      if(m_historyCount >= m_maxHistory) {
         // Shift history
         for(int i = m_maxHistory - 1; i > 0; i--) {
            m_signalHistory[i] = m_signalHistory[i - 1];
         }
         m_historyCount = m_maxHistory;
      } else {
         m_historyCount++;
      }

      // Add new signal at beginning
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
};

//+------------------------------------------------------------------+
