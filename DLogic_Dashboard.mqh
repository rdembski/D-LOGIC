//+------------------------------------------------------------------+
//|                                           DLogic_Dashboard.mqh   |
//|              D-LOGIC Professional Pairs Trading Dashboard         |
//|                                        Author: Rafał Dembski     |
//|                                                                   |
//|  Dark/Neon Aesthetic - Institutional Grade UI                     |
//|  - Scanner Heatmap                                                |
//|  - Spread Visualization                                           |
//|  - Z-Score Histogram                                              |
//|  - Risk Management Panel                                          |
//+------------------------------------------------------------------+
#property copyright "Rafał Dembski"
#property strict

#include "DLogic_Engine.mqh"

// ============================================================
// COLOR SCHEME - DARK/NEON INSTITUTIONAL
// ============================================================
#define CLR_BG_MAIN        C'8,8,12'        // Deep black
#define CLR_BG_PANEL       C'16,18,24'      // Panel background
#define CLR_BG_HEADER      C'20,22,30'      // Header background
#define CLR_BG_ROW         C'12,14,20'      // Row background
#define CLR_BG_ROW_ALT     C'18,20,28'      // Alternate row
#define CLR_BG_HOVER       C'30,35,50'      // Hover state

#define CLR_NEON_GREEN     C'0,255,128'     // Long/Profit
#define CLR_NEON_RED       C'255,60,80'     // Short/Loss
#define CLR_NEON_CYAN      C'0,220,255'     // Info/Neutral
#define CLR_NEON_YELLOW    C'255,220,50'    // Warning
#define CLR_NEON_MAGENTA   C'255,50,200'    // Highlight

#define CLR_TEXT_BRIGHT    C'240,245,255'   // Primary text
#define CLR_TEXT_DIM       C'120,130,150'   // Secondary text
#define CLR_TEXT_MUTED     C'70,80,100'     // Disabled text

#define CLR_BORDER         C'40,45,60'      // Border
#define CLR_GRID           C'25,30,45'      // Grid lines

#define CLR_BB_UPPER       C'0,180,255'     // Bollinger upper
#define CLR_BB_LOWER       C'0,180,255'     // Bollinger lower
#define CLR_BB_MIDDLE      C'100,150,200'   // Bollinger middle
#define CLR_SPREAD_LINE    C'255,255,255'   // Spread line

// ============================================================
// UI DIMENSIONS
// ============================================================
#define SCANNER_WIDTH      420
#define SCANNER_ROW_HEIGHT 20
#define SCANNER_MAX_ROWS   15

#define CHART_WIDTH        350
#define CHART_HEIGHT       200
#define ZSCORE_WIDTH       120
#define ZSCORE_HEIGHT      200

#define CONTROL_HEIGHT     80

//+------------------------------------------------------------------+
//| CDashboard - Main UI Controller                                   |
//+------------------------------------------------------------------+
class CDashboard {
private:
   string         m_prefix;
   int            m_startX;
   int            m_startY;
   bool           m_isVisible;
   bool           m_isMinimized;

   // Scanner data
   SPairResult    m_scanResults[];
   int            m_resultCount;
   int            m_selectedRow;
   int            m_scrollOffset;

   // Spread chart data
   double         m_spreadHistory[];
   double         m_zScoreHistory[];
   int            m_historySize;

   //+------------------------------------------------------------------+
   //| Create Rectangle                                                  |
   //+------------------------------------------------------------------+
   void CreateRect(string name, int x, int y, int w, int h, color bg, color border = clrNONE) {
      string objName = m_prefix + name;
      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      }
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, (border == clrNONE) ? CLR_BORDER : border);
   }

   //+------------------------------------------------------------------+
   //| Create Label                                                      |
   //+------------------------------------------------------------------+
   void CreateLabel(string name, string text, int x, int y, color clr, int size = 8, string font = "Consolas") {
      string objName = m_prefix + name;
      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      }
      ObjectSetString(0, objName, OBJPROP_FONT, font);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   }

   //+------------------------------------------------------------------+
   //| Create Button                                                     |
   //+------------------------------------------------------------------+
   void CreateButton(string name, string text, int x, int y, int w, int h,
                     color bg, color textClr, int fontSize = 8) {
      string objName = m_prefix + name;
      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      }
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, textClr);
      ObjectSetString(0, objName, OBJPROP_FONT, "Consolas Bold");
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   }

   //+------------------------------------------------------------------+
   //| Get Z-Score Color                                                 |
   //+------------------------------------------------------------------+
   color GetZScoreColor(double z) {
      double absZ = MathAbs(z);

      if(absZ >= 2.0) {
         return (z > 0) ? CLR_NEON_RED : CLR_NEON_GREEN;
      } else if(absZ >= 1.5) {
         return CLR_NEON_YELLOW;
      } else if(absZ >= 1.0) {
         return CLR_NEON_CYAN;
      }
      return CLR_TEXT_DIM;
   }

   //+------------------------------------------------------------------+
   //| Draw Scanner Header                                               |
   //+------------------------------------------------------------------+
   void DrawScannerHeader(int x, int y) {
      int colW[] = {140, 50, 70, 70, 80};  // Pair, TF, Z-Score, R², Signal

      CreateRect("SCN_HDR", x, y, SCANNER_WIDTH, 24, CLR_BG_HEADER, CLR_BORDER);

      CreateLabel("SCN_H1", "PAIR", x + 10, y + 5, CLR_TEXT_DIM, 8, "Consolas Bold");
      CreateLabel("SCN_H2", "TF", x + colW[0], y + 5, CLR_TEXT_DIM, 8, "Consolas Bold");
      CreateLabel("SCN_H3", "Z-SCORE", x + colW[0] + colW[1], y + 5, CLR_TEXT_DIM, 8, "Consolas Bold");
      CreateLabel("SCN_H4", "R²", x + colW[0] + colW[1] + colW[2], y + 5, CLR_TEXT_DIM, 8, "Consolas Bold");
      CreateLabel("SCN_H5", "SIGNAL", x + colW[0] + colW[1] + colW[2] + colW[3], y + 5, CLR_TEXT_DIM, 8, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Draw Scanner Row                                                  |
   //+------------------------------------------------------------------+
   void DrawScannerRow(int index, int x, int y, SPairResult &result, bool isSelected) {
      int colW[] = {140, 50, 70, 70, 80};
      int rowH = SCANNER_ROW_HEIGHT;
      string rowName = "ROW_" + IntegerToString(index);

      // Background
      color bgColor = isSelected ? CLR_BG_HOVER : (index % 2 == 0) ? CLR_BG_ROW : CLR_BG_ROW_ALT;
      CreateRect(rowName + "_BG", x, y, SCANNER_WIDTH, rowH, bgColor, CLR_BG_MAIN);

      // Cointegration indicator dot
      color dotColor = result.isCointegrated ? CLR_NEON_GREEN : CLR_NEON_RED;
      CreateRect(rowName + "_DOT", x + 3, y + 6, 6, 8, dotColor);

      // Pair name
      CreateLabel(rowName + "_PAIR", result.pairName, x + 12, y + 3, CLR_TEXT_BRIGHT, 8);

      // Timeframe
      string tfName = "";
      switch(result.timeframe) {
         case PERIOD_M15: tfName = "M15"; break;
         case PERIOD_H1:  tfName = "H1"; break;
         case PERIOD_H4:  tfName = "H4"; break;
         case PERIOD_D1:  tfName = "D1"; break;
         default: tfName = "??";
      }
      CreateLabel(rowName + "_TF", tfName, x + colW[0], y + 3, CLR_TEXT_DIM, 8);

      // Z-Score with color
      string zText = DoubleToString(result.zScore, 2);
      color zColor = GetZScoreColor(result.zScore);
      CreateLabel(rowName + "_Z", zText, x + colW[0] + colW[1], y + 3, zColor, 8, "Consolas Bold");

      // R² value
      string r2Text = DoubleToString(result.rSquared * 100, 0) + "%";
      color r2Color = result.rSquared >= 0.7 ? CLR_NEON_CYAN : CLR_TEXT_DIM;
      CreateLabel(rowName + "_R2", r2Text, x + colW[0] + colW[1] + colW[2], y + 3, r2Color, 8);

      // Signal
      color sigColor = CLR_TEXT_DIM;
      if(result.signal == 2 || result.signal == -2) {
         sigColor = (result.signal > 0) ? CLR_NEON_GREEN : CLR_NEON_RED;
      } else if(result.signal == 1 || result.signal == -1) {
         sigColor = CLR_NEON_YELLOW;
      }
      CreateLabel(rowName + "_SIG", result.signalText, x + colW[0] + colW[1] + colW[2] + colW[3], y + 3, sigColor, 7);
   }

   //+------------------------------------------------------------------+
   //| Draw Spread Chart                                                 |
   //+------------------------------------------------------------------+
   void DrawSpreadChart(int x, int y, SPairResult &result) {
      int w = CHART_WIDTH;
      int h = CHART_HEIGHT;

      // Panel background
      CreateRect("SPREAD_BG", x, y, w, h, CLR_BG_PANEL, CLR_BORDER);

      // Title
      CreateLabel("SPREAD_TITLE", "SPREAD: " + result.pairName, x + 10, y + 5, CLR_TEXT_BRIGHT, 9, "Consolas Bold");
      CreateLabel("SPREAD_BETA", "β=" + DoubleToString(result.beta, 4), x + w - 80, y + 5, CLR_NEON_CYAN, 8);

      // Chart area
      int chartX = x + 10;
      int chartY = y + 30;
      int chartW = w - 20;
      int chartH = h - 50;

      CreateRect("SPREAD_CHART", chartX, chartY, chartW, chartH, CLR_BG_MAIN, CLR_GRID);

      // Draw Bollinger Bands and spread line if we have history
      if(m_historySize > 10) {
         DrawSpreadLineOnChart(chartX, chartY, chartW, chartH, result);
      }

      // Current values
      CreateLabel("SPREAD_VAL", "Spread: " + DoubleToString(result.currentSpread, 6),
                  x + 10, y + h - 18, CLR_TEXT_DIM, 7);
      CreateLabel("SPREAD_STD", "σ: " + DoubleToString(result.spreadStdDev, 6),
                  x + 140, y + h - 18, CLR_TEXT_DIM, 7);
   }

   //+------------------------------------------------------------------+
   //| Draw spread line on chart area                                    |
   //+------------------------------------------------------------------+
   void DrawSpreadLineOnChart(int chartX, int chartY, int chartW, int chartH, SPairResult &result) {
      if(m_historySize < 2) return;

      // Find min/max for scaling
      double mean = result.spreadMean;
      double stdDev = result.spreadStdDev;
      double minVal = mean - 3 * stdDev;
      double maxVal = mean + 3 * stdDev;

      for(int i = 0; i < m_historySize; i++) {
         if(m_spreadHistory[i] < minVal) minVal = m_spreadHistory[i];
         if(m_spreadHistory[i] > maxVal) maxVal = m_spreadHistory[i];
      }

      double range = maxVal - minVal;
      if(range < 1e-10) range = 1;

      // Draw Bollinger Bands
      int bbUpperY = chartY + chartH - (int)((mean + 2 * stdDev - minVal) / range * chartH);
      int bbMiddleY = chartY + chartH - (int)((mean - minVal) / range * chartH);
      int bbLowerY = chartY + chartH - (int)((mean - 2 * stdDev - minVal) / range * chartH);

      // Clamp
      bbUpperY = MathMax(chartY, MathMin(chartY + chartH - 1, bbUpperY));
      bbMiddleY = MathMax(chartY, MathMin(chartY + chartH - 1, bbMiddleY));
      bbLowerY = MathMax(chartY, MathMin(chartY + chartH - 1, bbLowerY));

      CreateRect("BB_UPPER", chartX, bbUpperY, chartW, 1, CLR_BB_UPPER);
      CreateRect("BB_MIDDLE", chartX, bbMiddleY, chartW, 2, CLR_BB_MIDDLE);
      CreateRect("BB_LOWER", chartX, bbLowerY, chartW, 1, CLR_BB_LOWER);

      // Draw spread points
      int pointW = MathMax(2, chartW / m_historySize);
      int displayPoints = MathMin(m_historySize, chartW / pointW);

      for(int i = 0; i < displayPoints; i++) {
         int idx = i;
         if(idx >= m_historySize) continue;

         int pointX = chartX + chartW - (i + 1) * pointW;
         int pointY = chartY + chartH - (int)((m_spreadHistory[idx] - minVal) / range * chartH);

         pointY = MathMax(chartY, MathMin(chartY + chartH - 2, pointY));

         string pointName = m_prefix + "SPT_" + IntegerToString(i);
         if(ObjectFind(0, pointName) < 0) {
            ObjectCreate(0, pointName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         }
         ObjectSetInteger(0, pointName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, pointName, OBJPROP_XDISTANCE, pointX);
         ObjectSetInteger(0, pointName, OBJPROP_YDISTANCE, pointY);
         ObjectSetInteger(0, pointName, OBJPROP_XSIZE, MathMax(2, pointW - 1));
         ObjectSetInteger(0, pointName, OBJPROP_YSIZE, 2);
         ObjectSetInteger(0, pointName, OBJPROP_BGCOLOR, CLR_SPREAD_LINE);
         ObjectSetInteger(0, pointName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, pointName, OBJPROP_BORDER_COLOR, CLR_SPREAD_LINE);
         ObjectSetInteger(0, pointName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, pointName, OBJPROP_HIDDEN, true);
      }

      // Labels
      CreateLabel("BB_LBL_U", "+2σ", chartX + chartW + 5, bbUpperY - 5, CLR_BB_UPPER, 7);
      CreateLabel("BB_LBL_M", "μ", chartX + chartW + 5, bbMiddleY - 5, CLR_BB_MIDDLE, 7);
      CreateLabel("BB_LBL_L", "-2σ", chartX + chartW + 5, bbLowerY - 5, CLR_BB_LOWER, 7);
   }

   //+------------------------------------------------------------------+
   //| Draw Z-Score Histogram                                            |
   //+------------------------------------------------------------------+
   void DrawZScoreHistogram(int x, int y, double currentZ) {
      int w = ZSCORE_WIDTH;
      int h = ZSCORE_HEIGHT;

      // Panel background
      CreateRect("ZSCORE_BG", x, y, w, h, CLR_BG_PANEL, CLR_BORDER);

      // Title
      CreateLabel("ZSCORE_TITLE", "Z-SCORE", x + 10, y + 5, CLR_TEXT_BRIGHT, 9, "Consolas Bold");

      // Chart area
      int chartX = x + 30;
      int chartY = y + 30;
      int chartW = w - 45;
      int chartH = h - 50;

      CreateRect("ZSCORE_CHART", chartX, chartY, chartW, chartH, CLR_BG_MAIN, CLR_GRID);

      // Draw level lines
      // Scale: -3.5 to +3.5
      double maxZ = 3.5;
      double minZ = -3.5;
      double range = maxZ - minZ;

      // Level positions
      int y0 = chartY + chartH - (int)((0 - minZ) / range * chartH);
      int yP2 = chartY + chartH - (int)((2.0 - minZ) / range * chartH);
      int yM2 = chartY + chartH - (int)((-2.0 - minZ) / range * chartH);
      int yP35 = chartY + chartH - (int)((3.5 - minZ) / range * chartH);
      int yM35 = chartY + chartH - (int)((-3.5 - minZ) / range * chartH);

      // Draw level lines
      CreateRect("ZLVL_0", chartX, y0, chartW, 1, CLR_TEXT_DIM);
      CreateRect("ZLVL_P2", chartX, yP2, chartW, 1, CLR_NEON_RED);
      CreateRect("ZLVL_M2", chartX, yM2, chartW, 1, CLR_NEON_GREEN);

      // Draw Z-Score bar
      currentZ = MathMax(minZ, MathMin(maxZ, currentZ));
      int barTop, barBottom;

      if(currentZ >= 0) {
         barTop = chartY + chartH - (int)((currentZ - minZ) / range * chartH);
         barBottom = y0;
      } else {
         barTop = y0;
         barBottom = chartY + chartH - (int)((currentZ - minZ) / range * chartH);
      }

      int barH = MathAbs(barBottom - barTop);
      color barColor = GetZScoreColor(currentZ);

      CreateRect("ZSCORE_BAR", chartX + 10, MathMin(barTop, barBottom), chartW - 20, barH, barColor);

      // Labels
      CreateLabel("ZLBL_P35", "+3.5", x + 5, yP35 - 5, CLR_TEXT_MUTED, 7);
      CreateLabel("ZLBL_P2", "+2.0", x + 5, yP2 - 5, CLR_NEON_RED, 7);
      CreateLabel("ZLBL_0", "0", x + 5, y0 - 5, CLR_TEXT_DIM, 7);
      CreateLabel("ZLBL_M2", "-2.0", x + 5, yM2 - 5, CLR_NEON_GREEN, 7);
      CreateLabel("ZLBL_M35", "-3.5", x + 5, yM35 - 5, CLR_TEXT_MUTED, 7);

      // Current value
      CreateLabel("ZSCORE_VAL", DoubleToString(currentZ, 2), x + 10, y + h - 18, barColor, 12, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Draw Control Panel                                                |
   //+------------------------------------------------------------------+
   void DrawControlPanel(int x, int y, int totalWidth) {
      int h = CONTROL_HEIGHT;

      // Background
      CreateRect("CTRL_BG", x, y, totalWidth, h, CLR_BG_PANEL, CLR_BORDER);

      // Buttons
      int btnW = 100;
      int btnH = 28;
      int btnY = y + 10;
      int spacing = 10;

      CreateButton("BTN_SCAN", "SCAN MARKET", x + 10, btnY, btnW, btnH, C'20,80,40', CLR_NEON_GREEN, 8);
      CreateButton("BTN_EXEC", "EXECUTE HEDGE", x + 10 + btnW + spacing, btnY, btnW + 10, btnH, C'20,60,100', CLR_NEON_CYAN, 8);
      CreateButton("BTN_CLOSE", "CLOSE ALL", x + 10 + 2*(btnW + spacing) + 10, btnY, btnW - 10, btnH, C'100,30,30', CLR_NEON_RED, 8);

      // Status info
      int infoX = x + 350;
      CreateLabel("INFO_PL", "Unrealized P&L:", infoX, y + 10, CLR_TEXT_DIM, 8);
      CreateLabel("INFO_PL_VAL", "$0.00", infoX + 100, y + 10, CLR_TEXT_BRIGHT, 8, "Consolas Bold");

      CreateLabel("INFO_POS", "Open Positions:", infoX, y + 28, CLR_TEXT_DIM, 8);
      CreateLabel("INFO_POS_VAL", "0", infoX + 100, y + 28, CLR_TEXT_BRIGHT, 8, "Consolas Bold");

      CreateLabel("INFO_DD", "Max Drawdown:", infoX, y + 46, CLR_TEXT_DIM, 8);
      CreateLabel("INFO_DD_VAL", "0.00%", infoX + 100, y + 46, CLR_TEXT_BRIGHT, 8, "Consolas Bold");

      CreateLabel("INFO_BETA", "Active Beta:", infoX + 180, y + 10, CLR_TEXT_DIM, 8);
      CreateLabel("INFO_BETA_VAL", "-", infoX + 270, y + 10, CLR_NEON_CYAN, 8, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Delete all content objects (for minimize)                         |
   //+------------------------------------------------------------------+
   void DeleteAllContent() {
      int total = ObjectsTotal(0, 0, -1);
      for(int i = total - 1; i >= 0; i--) {
         string name = ObjectName(0, i, 0, -1);
         if(StringFind(name, m_prefix) != 0) continue;

         // Keep main BG and title
         if(StringFind(name, m_prefix + "MAIN_") == 0) continue;
         if(StringFind(name, m_prefix + "BTN_MIN") == 0) continue;

         ObjectDelete(0, name);
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CDashboard() {
      m_prefix = "DL_QUANT_";
      m_startX = 10;
      m_startY = 30;
      m_isVisible = true;
      m_isMinimized = false;
      m_resultCount = 0;
      m_selectedRow = -1;
      m_scrollOffset = 0;
      m_historySize = 0;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CDashboard() {
      ObjectsDeleteAll(0, m_prefix);
   }

   //+------------------------------------------------------------------+
   //| Set Position                                                      |
   //+------------------------------------------------------------------+
   void SetPosition(int x, int y) {
      m_startX = x;
      m_startY = y;
   }

   //+------------------------------------------------------------------+
   //| Update Results                                                    |
   //+------------------------------------------------------------------+
   void UpdateResults(SPairResult &results[], int count) {
      m_resultCount = count;
      ArrayResize(m_scanResults, count);
      for(int i = 0; i < count; i++) {
         m_scanResults[i] = results[i];
      }
   }

   //+------------------------------------------------------------------+
   //| Update Spread History                                             |
   //+------------------------------------------------------------------+
   void UpdateSpreadHistory(double &spreadHist[], double &zHist[], int size) {
      m_historySize = size;
      ArrayResize(m_spreadHistory, size);
      ArrayResize(m_zScoreHistory, size);
      for(int i = 0; i < size; i++) {
         m_spreadHistory[i] = spreadHist[i];
         m_zScoreHistory[i] = zHist[i];
      }
   }

   //+------------------------------------------------------------------+
   //| Draw Full Dashboard                                               |
   //+------------------------------------------------------------------+
   void Draw() {
      if(!m_isVisible) return;

      int x = m_startX;
      int y = m_startY;

      int totalWidth = SCANNER_WIDTH + CHART_WIDTH + ZSCORE_WIDTH + 30;
      int scannerHeight = 28 + SCANNER_MAX_ROWS * SCANNER_ROW_HEIGHT;
      int totalHeight = scannerHeight + CHART_HEIGHT + CONTROL_HEIGHT + 40;

      if(m_isMinimized) {
         DeleteAllContent();
         CreateRect("MAIN_BG", x, y, totalWidth, 28, CLR_BG_MAIN, CLR_NEON_CYAN);
         CreateLabel("MAIN_TITLE", "D-LOGIC QUANT DASHBOARD v4.00", x + 10, y + 6, CLR_TEXT_BRIGHT, 10, "Consolas Bold");
         CreateButton("BTN_MIN", "+", x + totalWidth - 28, y + 4, 22, 20, CLR_BG_PANEL, CLR_TEXT_BRIGHT, 10);
         ChartRedraw(0);
         return;
      }

      // Main background
      CreateRect("MAIN_BG", x, y, totalWidth, totalHeight, CLR_BG_MAIN, CLR_NEON_CYAN);

      // Title bar
      CreateRect("MAIN_HEADER", x, y, totalWidth, 28, CLR_BG_HEADER, CLR_BORDER);
      CreateLabel("MAIN_TITLE", "D-LOGIC QUANT DASHBOARD v4.00", x + 10, y + 6, CLR_TEXT_BRIGHT, 10, "Consolas Bold");
      CreateLabel("MAIN_SUBTITLE", "Statistical Arbitrage Engine", x + 300, y + 8, CLR_NEON_CYAN, 8);
      CreateButton("BTN_MIN", "-", x + totalWidth - 28, y + 4, 22, 20, CLR_BG_PANEL, CLR_TEXT_BRIGHT, 10);

      // Scanner section
      int scannerY = y + 32;
      CreateLabel("SEC_SCANNER", "▼ PAIRS SCANNER", x + 5, scannerY, CLR_NEON_CYAN, 8, "Consolas Bold");
      DrawScannerHeader(x + 5, scannerY + 18);

      // Draw rows
      int rowY = scannerY + 42;
      int displayRows = MathMin(SCANNER_MAX_ROWS, m_resultCount - m_scrollOffset);

      for(int i = 0; i < displayRows; i++) {
         int idx = i + m_scrollOffset;
         if(idx >= m_resultCount) break;

         bool isSelected = (idx == m_selectedRow);
         DrawScannerRow(i, x + 5, rowY + i * SCANNER_ROW_HEIGHT, m_scanResults[idx], isSelected);
      }

      // Middle section - Charts
      int chartY = scannerY + scannerHeight - 20;

      // Selected pair info or default
      SPairResult displayResult;
      if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
         displayResult = m_scanResults[m_selectedRow];
      } else if(m_resultCount > 0) {
         displayResult = m_scanResults[0];
      } else {
         displayResult.pairName = "NO DATA";
         displayResult.beta = 0;
         displayResult.zScore = 0;
         displayResult.spreadMean = 0;
         displayResult.spreadStdDev = 0;
         displayResult.currentSpread = 0;
      }

      // Spread chart
      DrawSpreadChart(x + 5, chartY, displayResult);

      // Z-Score histogram
      DrawZScoreHistogram(x + CHART_WIDTH + 15, chartY, displayResult.zScore);

      // Control panel
      int controlY = chartY + CHART_HEIGHT + 10;
      DrawControlPanel(x + 5, controlY, totalWidth - 10);

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Update Info Display                                               |
   //+------------------------------------------------------------------+
   void UpdateInfo(double unrealizedPL, int positions, double drawdown, double activeBeta) {
      color plColor = unrealizedPL >= 0 ? CLR_NEON_GREEN : CLR_NEON_RED;

      string plText = (unrealizedPL >= 0 ? "+" : "") + DoubleToString(unrealizedPL, 2);
      ObjectSetString(0, m_prefix + "INFO_PL_VAL", OBJPROP_TEXT, "$" + plText);
      ObjectSetInteger(0, m_prefix + "INFO_PL_VAL", OBJPROP_COLOR, plColor);

      ObjectSetString(0, m_prefix + "INFO_POS_VAL", OBJPROP_TEXT, IntegerToString(positions));
      ObjectSetString(0, m_prefix + "INFO_DD_VAL", OBJPROP_TEXT, DoubleToString(drawdown, 2) + "%");
      ObjectSetString(0, m_prefix + "INFO_BETA_VAL", OBJPROP_TEXT, activeBeta != 0 ? DoubleToString(activeBeta, 4) : "-");
   }

   //+------------------------------------------------------------------+
   //| Handle Click Events                                               |
   //+------------------------------------------------------------------+
   int HandleClick(string sparam, string &symbolA, string &symbolB, double &beta) {
      // Minimize button
      if(sparam == m_prefix + "BTN_MIN") {
         m_isMinimized = !m_isMinimized;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Draw();
         return -1;
      }

      // Scan button
      if(sparam == m_prefix + "BTN_SCAN") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         return 1;  // Request scan
      }

      // Execute button
      if(sparam == m_prefix + "BTN_EXEC") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
            symbolA = m_scanResults[m_selectedRow].symbolA;
            symbolB = m_scanResults[m_selectedRow].symbolB;
            beta = m_scanResults[m_selectedRow].beta;
            return 2;  // Request execute
         }
         return 0;
      }

      // Close all button
      if(sparam == m_prefix + "BTN_CLOSE") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         return 3;  // Request close all
      }

      // Row selection
      for(int i = 0; i < SCANNER_MAX_ROWS; i++) {
         string rowBgName = m_prefix + "ROW_" + IntegerToString(i) + "_BG";
         if(sparam == rowBgName || StringFind(sparam, m_prefix + "ROW_" + IntegerToString(i)) == 0) {
            m_selectedRow = i + m_scrollOffset;
            if(m_selectedRow < m_resultCount) {
               symbolA = m_scanResults[m_selectedRow].symbolA;
               symbolB = m_scanResults[m_selectedRow].symbolB;
               beta = m_scanResults[m_selectedRow].beta;
               Draw();
               return 4;  // Row selected
            }
            return 0;
         }
      }

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Toggle Visibility                                                 |
   //+------------------------------------------------------------------+
   void ToggleVisibility() {
      m_isVisible = !m_isVisible;
      if(!m_isVisible) {
         ObjectsDeleteAll(0, m_prefix);
      } else {
         m_isMinimized = false;
         Draw();
      }
   }

   //+------------------------------------------------------------------+
   //| Sort Results by Z-Score (Absolute Value)                          |
   //+------------------------------------------------------------------+
   void SortByZScore() {
      // Simple bubble sort by absolute Z-Score (highest first)
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
   //| Get Selected Pair                                                 |
   //+------------------------------------------------------------------+
   bool GetSelectedPair(string &symbolA, string &symbolB, double &beta, double &zScore) {
      if(m_selectedRow < 0 || m_selectedRow >= m_resultCount) return false;

      symbolA = m_scanResults[m_selectedRow].symbolA;
      symbolB = m_scanResults[m_selectedRow].symbolB;
      beta = m_scanResults[m_selectedRow].beta;
      zScore = m_scanResults[m_selectedRow].zScore;
      return true;
   }

   bool IsVisible() { return m_isVisible; }
   int GetResultCount() { return m_resultCount; }
};

//+------------------------------------------------------------------+
