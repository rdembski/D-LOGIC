//+------------------------------------------------------------------+
//|                                           DLogic_Dashboard.mqh   |
//|              D-LOGIC Professional Pairs Trading Dashboard         |
//|                                        Author: Rafał Dembski     |
//|                                                                   |
//|  3-Panel Layout: TOP (Scanner) | BOTTOM (Charts) | RIGHT (Analytics)
//|  Advanced Features: Regime Detection, Signal Strength, Risk Metrics
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
#define CLR_BG_CHART       C'10,12,18'      // Chart background

#define CLR_NEON_GREEN     C'0,255,128'     // Long/Profit
#define CLR_NEON_RED       C'255,60,80'     // Short/Loss
#define CLR_NEON_CYAN      C'0,220,255'     // Info/Neutral
#define CLR_NEON_YELLOW    C'255,220,50'    // Warning
#define CLR_NEON_MAGENTA   C'255,50,200'    // Highlight
#define CLR_NEON_ORANGE    C'255,150,50'    // Alert

#define CLR_TEXT_BRIGHT    C'240,245,255'   // Primary text
#define CLR_TEXT_DIM       C'120,130,150'   // Secondary text
#define CLR_TEXT_MUTED     C'70,80,100'     // Disabled text

#define CLR_BORDER         C'40,45,60'      // Border
#define CLR_BORDER_ACCENT  C'60,70,100'     // Accent border
#define CLR_GRID           C'25,30,45'      // Grid lines

#define CLR_BB_UPPER       C'255,100,100'   // Bollinger upper (sell zone)
#define CLR_BB_LOWER       C'100,255,150'   // Bollinger lower (buy zone)
#define CLR_BB_MIDDLE      C'150,180,220'   // Bollinger middle
#define CLR_SPREAD_LINE    C'255,255,255'   // Spread line

// ============================================================
// UI DIMENSIONS - 3 SEPARATE PANELS LAYOUT
// ============================================================

// Chart dimensions (will be detected dynamically)
#define CHART_MARGIN       5

// TOP PANEL (Header - full width at top)
#define TOP_PANEL_HEIGHT   220
#define TOP_PANEL_Y        25

// RIGHT PANEL (Vertical panel on right side)
#define RIGHT_PANEL_WIDTH  320
#define RIGHT_PANEL_Y      250

// BOTTOM PANEL (Full width at bottom)
#define BOTTOM_PANEL_HEIGHT 230
#define BOTTOM_PANEL_Y_OFFSET 240   // From bottom of chart

// Scanner settings
#define SCANNER_ROW_HEIGHT 16
#define SCANNER_MAX_ROWS   10

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
   int        signal;       // +2=Strong Long, +1=Long, -1=Short, -2=Strong Short
   double     zScore;
   double     strength;
   bool       executed;
   double     entryPL;      // P&L if executed
};

// ============================================================
// PERFORMANCE TRACKING STRUCTURE
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
//| CDashboard - Professional 3-Panel UI Controller                   |
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

   // Analytics data
   ENUM_REGIME    m_currentRegime;
   double         m_signalStrength;
   double         m_estimatedSharpe;
   int            m_signalCount;
   int            m_winCount;

   // Signal History
   SSignalHistory m_signalHistory[];
   int            m_historyCount;
   int            m_maxHistory;

   // Performance Statistics
   SPerformanceStats m_perfStats;
   double         m_equityCurve[];
   int            m_equitySize;

   // Correlation Matrix
   double         m_correlationMatrix[6][6];  // 6x6 matrix for top pairs
   string         m_corrPairs[6];

   // Alert System
   double         m_alertThresholdZ;
   double         m_alertThresholdStrength;
   bool           m_alertsEnabled;
   datetime       m_lastAlertTime;
   int            m_alertCooldown;

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
      if(absZ >= 2.5) return (z > 0) ? CLR_NEON_RED : CLR_NEON_GREEN;
      if(absZ >= 2.0) return (z > 0) ? CLR_NEON_ORANGE : CLR_NEON_CYAN;
      if(absZ >= 1.5) return CLR_NEON_YELLOW;
      return CLR_TEXT_DIM;
   }

   //+------------------------------------------------------------------+
   //| Calculate Signal Strength (0-100)                                 |
   //+------------------------------------------------------------------+
   double CalcSignalStrength(SPairResult &result) {
      double strength = 0;

      // Z-Score component (0-40 points)
      double absZ = MathAbs(result.zScore);
      if(absZ >= 2.5) strength += 40;
      else if(absZ >= 2.0) strength += 30;
      else if(absZ >= 1.5) strength += 15;

      // Cointegration component (0-30 points)
      if(result.isCointegrated) strength += 30;

      // R² component (0-20 points)
      strength += result.rSquared * 20;

      // Half-life component (0-10 points)
      if(result.halfLife > 0 && result.halfLife < 30) {
         strength += (30 - result.halfLife) / 3;
      }

      return MathMin(100, strength);
   }

   //+------------------------------------------------------------------+
   //| Detect Market Regime                                              |
   //+------------------------------------------------------------------+
   ENUM_REGIME DetectRegime(SPairResult &result) {
      // Based on zero-crossings and half-life
      if(result.zeroCrossings >= 15 && result.halfLife < 20) {
         return REGIME_MEAN_REVERT;
      }
      if(result.zeroCrossings < 5) {
         return REGIME_TRENDING;
      }
      if(result.spreadStdDev > result.spreadMean * 0.1) {
         return REGIME_VOLATILE;
      }
      return REGIME_CONSOLIDATION;
   }

   //+------------------------------------------------------------------+
   //| Get Regime Name                                                   |
   //+------------------------------------------------------------------+
   string GetRegimeName(ENUM_REGIME regime) {
      switch(regime) {
         case REGIME_MEAN_REVERT:   return "MEAN REVERSION";
         case REGIME_TRENDING:      return "TRENDING";
         case REGIME_VOLATILE:      return "HIGH VOLATILITY";
         case REGIME_CONSOLIDATION: return "CONSOLIDATION";
      }
      return "UNKNOWN";
   }

   //+------------------------------------------------------------------+
   //| Get Regime Color                                                  |
   //+------------------------------------------------------------------+
   color GetRegimeColor(ENUM_REGIME regime) {
      switch(regime) {
         case REGIME_MEAN_REVERT:   return CLR_NEON_GREEN;
         case REGIME_TRENDING:      return CLR_NEON_RED;
         case REGIME_VOLATILE:      return CLR_NEON_ORANGE;
         case REGIME_CONSOLIDATION: return CLR_NEON_YELLOW;
      }
      return CLR_TEXT_DIM;
   }

   //+------------------------------------------------------------------+
   //| Add Signal to History                                             |
   //+------------------------------------------------------------------+
   void AddSignalToHistory(string pairName, int signal, double zScore, double strength) {
      if(m_historyCount >= m_maxHistory) {
         // Shift array (FIFO)
         for(int i = 0; i < m_maxHistory - 1; i++) {
            m_signalHistory[i] = m_signalHistory[i + 1];
         }
         m_historyCount = m_maxHistory - 1;
      }

      SSignalHistory newSignal;
      newSignal.time = TimeCurrent();
      newSignal.pairName = pairName;
      newSignal.signal = signal;
      newSignal.zScore = zScore;
      newSignal.strength = strength;
      newSignal.executed = false;
      newSignal.entryPL = 0;

      m_signalHistory[m_historyCount] = newSignal;
      m_historyCount++;
   }

   //+------------------------------------------------------------------+
   //| Update Performance Statistics                                     |
   //+------------------------------------------------------------------+
   void UpdatePerformanceStats(double tradePL, bool isWin) {
      m_perfStats.executedTrades++;

      if(isWin) {
         m_perfStats.winningTrades++;
         m_perfStats.grossProfit += tradePL;
      } else {
         m_perfStats.losingTrades++;
         m_perfStats.grossLoss += MathAbs(tradePL);
      }

      m_perfStats.totalPL += tradePL;

      // Update Win Rate
      if(m_perfStats.executedTrades > 0) {
         m_perfStats.winRate = (double)m_perfStats.winningTrades / m_perfStats.executedTrades * 100;
      }

      // Update Profit Factor
      if(m_perfStats.grossLoss > 0) {
         m_perfStats.profitFactor = m_perfStats.grossProfit / m_perfStats.grossLoss;
      }

      // Update Averages
      if(m_perfStats.winningTrades > 0) {
         m_perfStats.avgWin = m_perfStats.grossProfit / m_perfStats.winningTrades;
      }
      if(m_perfStats.losingTrades > 0) {
         m_perfStats.avgLoss = m_perfStats.grossLoss / m_perfStats.losingTrades;
      }

      // Update Expectancy: (WinRate × AvgWin) - (LossRate × AvgLoss)
      double lossRate = 100 - m_perfStats.winRate;
      m_perfStats.expectancy = (m_perfStats.winRate / 100 * m_perfStats.avgWin) -
                               (lossRate / 100 * m_perfStats.avgLoss);

      // Update Equity Curve
      if(m_equitySize < 500) {
         ArrayResize(m_equityCurve, m_equitySize + 1);
         m_equityCurve[m_equitySize] = m_perfStats.totalPL;
         m_equitySize++;

         // Calculate Max Drawdown
         double peak = 0;
         double maxDD = 0;
         for(int i = 0; i < m_equitySize; i++) {
            if(m_equityCurve[i] > peak) peak = m_equityCurve[i];
            double dd = peak - m_equityCurve[i];
            if(dd > maxDD) maxDD = dd;
         }
         m_perfStats.maxDrawdown = maxDD;
      }

      // Simplified Sharpe Ratio (using running stats)
      if(m_equitySize > 10) {
         double sum = 0, sumSq = 0;
         for(int i = 1; i < m_equitySize; i++) {
            double ret = m_equityCurve[i] - m_equityCurve[i - 1];
            sum += ret;
            sumSq += ret * ret;
         }
         double mean = sum / (m_equitySize - 1);
         double variance = (sumSq / (m_equitySize - 1)) - (mean * mean);
         double stdDev = MathSqrt(MathMax(0, variance));
         if(stdDev > 0) {
            m_perfStats.sharpeRatio = mean / stdDev * MathSqrt(252);  // Annualized
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Correlation between two Z-Score series                  |
   //+------------------------------------------------------------------+
   double CalcCorrelation(double &seriesA[], double &seriesB[], int size) {
      if(size < 10) return 0;

      double sumA = 0, sumB = 0, sumAB = 0, sumA2 = 0, sumB2 = 0;

      for(int i = 0; i < size; i++) {
         sumA += seriesA[i];
         sumB += seriesB[i];
         sumAB += seriesA[i] * seriesB[i];
         sumA2 += seriesA[i] * seriesA[i];
         sumB2 += seriesB[i] * seriesB[i];
      }

      double meanA = sumA / size;
      double meanB = sumB / size;

      double numerator = sumAB - size * meanA * meanB;
      double denomA = MathSqrt(sumA2 - size * meanA * meanA);
      double denomB = MathSqrt(sumB2 - size * meanB * meanB);

      if(denomA < 1e-10 || denomB < 1e-10) return 0;

      return numerator / (denomA * denomB);
   }

   //+------------------------------------------------------------------+
   //| Check and Trigger Alerts                                          |
   //+------------------------------------------------------------------+
   bool CheckAlerts(SPairResult &result) {
      if(!m_alertsEnabled) return false;

      if(TimeCurrent() - m_lastAlertTime < m_alertCooldown) return false;

      double absZ = MathAbs(result.zScore);
      double strength = CalcSignalStrength(result);

      // Alert conditions
      bool shouldAlert = false;
      string alertMessage = "";

      if(absZ >= m_alertThresholdZ && strength >= m_alertThresholdStrength) {
         shouldAlert = true;
         string direction = result.zScore > 0 ? "SHORT" : "LONG";
         alertMessage = "D-LOGIC: " + result.pairName + " | " + direction +
                        " Signal | Z=" + DoubleToString(result.zScore, 2) +
                        " | Strength=" + DoubleToString(strength, 0) + "%";
      }

      if(absZ >= 3.0) {
         shouldAlert = true;
         alertMessage = "D-LOGIC WARNING: " + result.pairName +
                        " | EXTREME Z-Score: " + DoubleToString(result.zScore, 2) +
                        " | Consider Stop-Loss!";
      }

      if(shouldAlert && alertMessage != "") {
         Alert(alertMessage);
         PlaySound("alert.wav");
         m_lastAlertTime = TimeCurrent();
         return true;
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Get Correlation Color                                             |
   //+------------------------------------------------------------------+
   color GetCorrelationColor(double corr) {
      double absCorr = MathAbs(corr);
      if(absCorr >= 0.8) return (corr > 0) ? CLR_NEON_GREEN : CLR_NEON_RED;
      if(absCorr >= 0.5) return (corr > 0) ? CLR_NEON_CYAN : CLR_NEON_ORANGE;
      return CLR_TEXT_DIM;
   }

   //+------------------------------------------------------------------+
   //| Draw Performance Panel                                            |
   //+------------------------------------------------------------------+
   void DrawPerformancePanel(int x, int y, int w) {
      int h = 95;
      CreateRect("PERF_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("PERF_TITLE", "PERFORMANCE", x + 10, y + 6, CLR_NEON_YELLOW, 9, "Consolas Bold");

      int row = 0;
      int rowH = 15;
      int startY = y + 25;
      int col1 = x + 10;
      int col2 = x + 95;
      int col3 = x + 160;
      int col4 = x + 245;

      // Row 1: Trades & Win Rate
      CreateLabel("PERF_TR_L", "Trades:", col1, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("PERF_TR_V", IntegerToString(m_perfStats.executedTrades), col2, startY + row * rowH, CLR_TEXT_BRIGHT, 7, "Consolas Bold");
      CreateLabel("PERF_WR_L", "Win Rate:", col3, startY + row * rowH, CLR_TEXT_DIM, 7);
      color wrColor = m_perfStats.winRate >= 55 ? CLR_NEON_GREEN : (m_perfStats.winRate >= 45 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_WR_V", DoubleToString(m_perfStats.winRate, 1) + "%", col4, startY + row * rowH, wrColor, 7, "Consolas Bold");
      row++;

      // Row 2: Total P&L & Profit Factor
      CreateLabel("PERF_PL_L", "Total P&L:", col1, startY + row * rowH, CLR_TEXT_DIM, 7);
      color plColor = m_perfStats.totalPL >= 0 ? CLR_NEON_GREEN : CLR_NEON_RED;
      string plStr = (m_perfStats.totalPL >= 0 ? "+" : "") + DoubleToString(m_perfStats.totalPL, 2);
      CreateLabel("PERF_PL_V", "$" + plStr, col2, startY + row * rowH, plColor, 7, "Consolas Bold");
      CreateLabel("PERF_PF_L", "PF:", col3, startY + row * rowH, CLR_TEXT_DIM, 7);
      color pfColor = m_perfStats.profitFactor >= 1.5 ? CLR_NEON_GREEN : (m_perfStats.profitFactor >= 1.0 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_PF_V", DoubleToString(m_perfStats.profitFactor, 2), col4, startY + row * rowH, pfColor, 7, "Consolas Bold");
      row++;

      // Row 3: Sharpe & Max DD
      CreateLabel("PERF_SR_L", "Sharpe:", col1, startY + row * rowH, CLR_TEXT_DIM, 7);
      color srColor = m_perfStats.sharpeRatio >= 1.5 ? CLR_NEON_GREEN : (m_perfStats.sharpeRatio >= 0.5 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_SR_V", DoubleToString(m_perfStats.sharpeRatio, 2), col2, startY + row * rowH, srColor, 7, "Consolas Bold");
      CreateLabel("PERF_DD_L", "Max DD:", col3, startY + row * rowH, CLR_TEXT_DIM, 7);
      color ddColor = m_perfStats.maxDrawdown < 100 ? CLR_NEON_GREEN : (m_perfStats.maxDrawdown < 500 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_DD_V", "$" + DoubleToString(m_perfStats.maxDrawdown, 0), col4, startY + row * rowH, ddColor, 7, "Consolas Bold");
      row++;

      // Row 4: Expectancy
      CreateLabel("PERF_EX_L", "Expectancy:", col1, startY + row * rowH, CLR_TEXT_DIM, 7);
      color exColor = m_perfStats.expectancy > 0 ? CLR_NEON_GREEN : CLR_NEON_RED;
      CreateLabel("PERF_EX_V", "$" + DoubleToString(m_perfStats.expectancy, 2) + "/trade", col2, startY + row * rowH, exColor, 7, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Draw Signal History Panel                                         |
   //+------------------------------------------------------------------+
   void DrawSignalHistoryPanel(int x, int y, int w) {
      int h = 120;
      CreateRect("HIST_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("HIST_TITLE", "SIGNAL LOG", x + 10, y + 6, CLR_NEON_MAGENTA, 9, "Consolas Bold");
      CreateLabel("HIST_COUNT", IntegerToString(m_historyCount) + " signals", x + w - 70, y + 7, CLR_TEXT_DIM, 7);

      // Column headers
      int headerY = y + 24;
      CreateLabel("HIST_H_T", "TIME", x + 10, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("HIST_H_P", "PAIR", x + 65, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("HIST_H_S", "SIGNAL", x + 180, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("HIST_H_Z", "Z", x + 240, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("HIST_H_E", "EXEC", x + 280, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");

      // Draw last 5 signals
      int rowY = y + 38;
      int rowH = 15;
      int displayCount = MathMin(5, m_historyCount);

      for(int i = 0; i < displayCount; i++) {
         int idx = m_historyCount - 1 - i;  // Most recent first
         if(idx < 0) break;

         string rowPrefix = "HIST_R" + IntegerToString(i);

         // Time (HH:MM)
         string timeStr = TimeToString(m_signalHistory[idx].time, TIME_MINUTES);
         CreateLabel(rowPrefix + "_T", timeStr, x + 10, rowY + i * rowH, CLR_TEXT_DIM, 7);

         // Pair name
         CreateLabel(rowPrefix + "_P", m_signalHistory[idx].pairName, x + 65, rowY + i * rowH, CLR_TEXT_BRIGHT, 7);

         // Signal
         string sigText = "";
         color sigColor = CLR_TEXT_DIM;
         if(m_signalHistory[idx].signal == 2) { sigText = "STRONG LONG"; sigColor = CLR_NEON_GREEN; }
         else if(m_signalHistory[idx].signal == 1) { sigText = "LONG"; sigColor = CLR_NEON_CYAN; }
         else if(m_signalHistory[idx].signal == -1) { sigText = "SHORT"; sigColor = CLR_NEON_ORANGE; }
         else if(m_signalHistory[idx].signal == -2) { sigText = "STRONG SHORT"; sigColor = CLR_NEON_RED; }
         CreateLabel(rowPrefix + "_S", sigText, x + 180, rowY + i * rowH, sigColor, 6);

         // Z-Score
         CreateLabel(rowPrefix + "_Z", DoubleToString(m_signalHistory[idx].zScore, 1), x + 240, rowY + i * rowH, GetZScoreColor(m_signalHistory[idx].zScore), 7);

         // Executed indicator
         string execText = m_signalHistory[idx].executed ? "✓" : "○";
         color execColor = m_signalHistory[idx].executed ? CLR_NEON_GREEN : CLR_TEXT_MUTED;
         CreateLabel(rowPrefix + "_E", execText, x + 285, rowY + i * rowH, execColor, 8);
      }
   }

   //+------------------------------------------------------------------+
   //| DRAW: Main Title Bar                                              |
   //+------------------------------------------------------------------+
   void DrawTitleBar(int x, int y, int w) {
      CreateRect("TITLE_BG", x, y, w, 30, CLR_BG_HEADER, CLR_NEON_CYAN);
      CreateLabel("TITLE", "D-LOGIC QUANT DASHBOARD v4.10", x + 12, y + 7, CLR_TEXT_BRIGHT, 11, "Consolas Bold");
      CreateLabel("SUBTITLE", "Statistical Arbitrage Engine", x + 320, y + 9, CLR_NEON_CYAN, 9);

      // System status indicator
      CreateRect("STATUS_DOT", x + w - 50, y + 10, 10, 10, CLR_NEON_GREEN);
      CreateLabel("STATUS_TXT", "LIVE", x + w - 38, y + 8, CLR_NEON_GREEN, 8);

      CreateButton("BTN_MIN", "-", x + w - 28, y + 5, 22, 20, CLR_BG_PANEL, CLR_TEXT_BRIGHT, 12);
   }

   //+------------------------------------------------------------------+
   //| DRAW: TOP PANEL - Scanner                                         |
   //+------------------------------------------------------------------+
   void DrawTopPanel(int x, int y) {
      int w = SCANNER_WIDTH;
      int h = TOP_PANEL_HEIGHT - 40;

      // Panel background
      CreateRect("TOP_BG", x, y, w, h, CLR_BG_PANEL, CLR_BORDER);

      // Section header
      CreateRect("TOP_HDR", x, y, w, 24, CLR_BG_HEADER, CLR_BORDER);
      CreateLabel("TOP_TITLE", "▼ PAIRS SCANNER", x + 10, y + 5, CLR_NEON_CYAN, 9, "Consolas Bold");
      CreateLabel("TOP_COUNT", IntegerToString(m_resultCount) + " pairs", x + w - 70, y + 6, CLR_TEXT_DIM, 8);

      // Column headers
      int headerY = y + 28;
      CreateRect("SCN_HDR", x, headerY, w, 20, CLR_BG_MAIN, CLR_BORDER);

      int cols[] = {8, 150, 195, 260, 315, 365, 420, 520, 620};
      CreateLabel("H_COINT", "●", x + cols[0], headerY + 3, CLR_TEXT_DIM, 8);
      CreateLabel("H_PAIR", "PAIR", x + cols[1] - 130, headerY + 3, CLR_TEXT_DIM, 8, "Consolas Bold");
      CreateLabel("H_TF", "TF", x + cols[2] - 130, headerY + 3, CLR_TEXT_DIM, 8, "Consolas Bold");
      CreateLabel("H_ZSCORE", "Z-SCORE", x + cols[3] - 130, headerY + 3, CLR_TEXT_DIM, 8, "Consolas Bold");
      CreateLabel("H_R2", "R²", x + cols[4] - 130, headerY + 3, CLR_TEXT_DIM, 8, "Consolas Bold");
      CreateLabel("H_HALF", "HL", x + cols[5] - 130, headerY + 3, CLR_TEXT_DIM, 8, "Consolas Bold");
      CreateLabel("H_HURST", "H", x + cols[6] - 130, headerY + 3, CLR_TEXT_DIM, 8, "Consolas Bold");
      CreateLabel("H_QUAL", "QUALITY", x + cols[7] - 130, headerY + 3, CLR_TEXT_DIM, 8, "Consolas Bold");
      CreateLabel("H_SIGNAL", "SIGNAL", x + cols[8] - 130, headerY + 3, CLR_TEXT_DIM, 8, "Consolas Bold");

      // Draw rows
      int rowY = headerY + 22;
      int displayRows = MathMin(SCANNER_MAX_ROWS, m_resultCount - m_scrollOffset);

      for(int i = 0; i < displayRows; i++) {
         int idx = i + m_scrollOffset;
         if(idx >= m_resultCount) break;

         bool isSelected = (idx == m_selectedRow);
         DrawScannerRow(i, x, rowY + i * SCANNER_ROW_HEIGHT, m_scanResults[idx], isSelected, cols);
      }

      // Signal summary at bottom
      int summaryY = y + h - 22;
      CreateRect("SUMMARY_BG", x, summaryY, w, 22, CLR_BG_HEADER, CLR_BORDER);

      int strongSignals = 0, cointegrated = 0;
      for(int i = 0; i < m_resultCount; i++) {
         if(MathAbs(m_scanResults[i].signal) == 2) strongSignals++;
         if(m_scanResults[i].isCointegrated) cointegrated++;
      }

      CreateLabel("SUM_SIG", "Strong Signals: " + IntegerToString(strongSignals), x + 10, summaryY + 4, CLR_NEON_GREEN, 8);
      CreateLabel("SUM_COINT", "Cointegrated: " + IntegerToString(cointegrated), x + 150, summaryY + 4, CLR_NEON_CYAN, 8);
      CreateLabel("SUM_TIME", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES), x + w - 120, summaryY + 4, CLR_TEXT_DIM, 8);
   }

   //+------------------------------------------------------------------+
   //| Draw Scanner Row                                                  |
   //+------------------------------------------------------------------+
   void DrawScannerRow(int index, int baseX, int y, SPairResult &result, bool isSelected, int &cols[]) {
      int rowH = SCANNER_ROW_HEIGHT;
      string rowName = "ROW_" + IntegerToString(index);

      // Background
      color bgColor = isSelected ? CLR_BG_HOVER : (index % 2 == 0) ? CLR_BG_ROW : CLR_BG_ROW_ALT;
      CreateRect(rowName + "_BG", baseX, y, SCANNER_WIDTH, rowH, bgColor, CLR_BG_MAIN);

      // Cointegration dot
      color dotColor = result.isCointegrated ? CLR_NEON_GREEN : CLR_NEON_RED;
      CreateRect(rowName + "_DOT", baseX + cols[0], y + 5, 8, 8, dotColor);

      // Pair name
      color pairColor = isSelected ? CLR_NEON_CYAN : CLR_TEXT_BRIGHT;
      CreateLabel(rowName + "_PAIR", result.pairName, baseX + cols[1] - 130, y + 2, pairColor, 8);

      // Timeframe
      string tfName = "H4";
      if(result.timeframe == PERIOD_D1) tfName = "D1";
      else if(result.timeframe == PERIOD_H1) tfName = "H1";
      CreateLabel(rowName + "_TF", tfName, baseX + cols[2] - 130, y + 2, CLR_TEXT_DIM, 8);

      // Z-Score
      color zColor = GetZScoreColor(result.zScore);
      string zPrefix = result.zScore > 0 ? "+" : "";
      CreateLabel(rowName + "_Z", zPrefix + DoubleToString(result.zScore, 2), baseX + cols[3] - 130, y + 2, zColor, 8, "Consolas Bold");

      // R²
      color r2Color = result.rSquared >= 0.7 ? CLR_NEON_CYAN : CLR_TEXT_DIM;
      CreateLabel(rowName + "_R2", DoubleToString(result.rSquared * 100, 0) + "%", baseX + cols[4] - 130, y + 2, r2Color, 8);

      // Half-life
      string hlText = result.halfLife < 100 ? DoubleToString(result.halfLife, 1) : "99+";
      color hlColor = result.halfLife < 20 ? CLR_NEON_GREEN : (result.halfLife < 50 ? CLR_NEON_YELLOW : CLR_TEXT_DIM);
      CreateLabel(rowName + "_HL", hlText, baseX + cols[5] - 130, y + 2, hlColor, 8);

      // Hurst Exponent
      color hurstColor = result.hurstExponent < 0.45 ? CLR_NEON_GREEN :
                        (result.hurstExponent < 0.55 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel(rowName + "_HU", DoubleToString(result.hurstExponent, 2), baseX + cols[6] - 130, y + 2, hurstColor, 8);

      // Quality Score
      color qualColor = result.qualityScore >= 70 ? CLR_NEON_GREEN :
                       (result.qualityScore >= 50 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel(rowName + "_QS", IntegerToString(result.qualityScore), baseX + cols[7] - 130, y + 2, qualColor, 8, "Consolas Bold");

      // Signal
      color sigColor = CLR_TEXT_DIM;
      if(MathAbs(result.signal) == 2) sigColor = (result.signal > 0) ? CLR_NEON_GREEN : CLR_NEON_RED;
      else if(MathAbs(result.signal) == 1) sigColor = CLR_NEON_YELLOW;
      CreateLabel(rowName + "_SIG", result.signalText, baseX + cols[8] - 130, y + 2, sigColor, 7);
   }

   //+------------------------------------------------------------------+
   //| DRAW: RIGHT PANEL - Analytics                                     |
   //+------------------------------------------------------------------+
   void DrawRightPanel(int x, int y, SPairResult &result) {
      int w = RIGHT_PANEL_WIDTH - 10;
      int h = MAIN_HEIGHT - 40;

      // Panel background
      CreateRect("RIGHT_BG", x, y, w, h, CLR_BG_PANEL, CLR_BORDER);

      // Split right panel into two columns for compact design
      int col1W = (w - 15) / 2;
      int col2X = x + col1W + 10;

      // === COLUMN 1: Z-Score Gauge + Signal Strength ===
      int gaugeY = y + 5;
      DrawZScoreGauge(x + 5, gaugeY, col1W, 150, result.zScore);

      int strengthY = gaugeY + 158;
      DrawSignalStrength(x + 5, strengthY, col1W, result);

      // === COLUMN 2: Regime + Risk Metrics ===
      int regimeY = y + 5;
      DrawRegimePanel(col2X, regimeY, col1W, result);

      int metricsY = regimeY + 83;
      DrawRiskMetrics(col2X, metricsY, col1W, result);

      // === FULL WIDTH: Position Info ===
      int posY = strengthY + 93;
      DrawPositionInfo(x + 5, posY, w - 10);

      // === FULL WIDTH: Mini Equity Curve ===
      int eqY = posY + 88;
      DrawMiniEquityCurve(x + 5, eqY, w - 10, 100);

      // === FULL WIDTH: Alert Settings ===
      int alertY = eqY + 108;
      DrawAlertSettings(x + 5, alertY, w - 10);
   }

   //+------------------------------------------------------------------+
   //| Draw Z-Score Gauge                                                |
   //+------------------------------------------------------------------+
   void DrawZScoreGauge(int x, int y, int w, int h, double zScore) {
      CreateRect("ZGAUGE_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("ZGAUGE_TITLE", "Z-SCORE METER", x + 10, y + 8, CLR_NEON_CYAN, 9, "Consolas Bold");

      // Gauge area
      int gaugeX = x + 40;
      int gaugeY = y + 35;
      int gaugeW = 50;
      int gaugeH = 100;

      CreateRect("ZGAUGE_FRAME", gaugeX, gaugeY, gaugeW, gaugeH, CLR_BG_CHART, CLR_BORDER);

      // Level markers
      double maxZ = 3.5, minZ = -3.5, range = maxZ - minZ;

      // Draw zone backgrounds
      int zoneTop = gaugeY;
      int zone2Up = gaugeY + gaugeH - (int)((2.0 - minZ) / range * gaugeH);
      int zone0 = gaugeY + gaugeH - (int)((0 - minZ) / range * gaugeH);
      int zone2Dn = gaugeY + gaugeH - (int)((-2.0 - minZ) / range * gaugeH);
      int zoneBot = gaugeY + gaugeH;

      // Stop zone (top)
      CreateRect("ZZONE_STOP_UP", gaugeX, zoneTop, gaugeW, zone2Up - zoneTop, C'60,20,20');
      // Short zone
      CreateRect("ZZONE_SHORT", gaugeX, zone2Up, gaugeW, zone0 - zone2Up, C'40,25,20');
      // Long zone
      CreateRect("ZZONE_LONG", gaugeX, zone0, gaugeW, zone2Dn - zone0, C'20,40,25');
      // Stop zone (bottom)
      CreateRect("ZZONE_STOP_DN", gaugeX, zone2Dn, gaugeW, zoneBot - zone2Dn, C'20,60,20');

      // Level lines and labels
      int lblX = gaugeX + gaugeW + 8;
      CreateRect("ZLVL_P35", gaugeX, zoneTop, gaugeW, 1, CLR_NEON_RED);
      CreateLabel("ZLBL_P35", "+3.5 SL", lblX, zoneTop - 4, CLR_NEON_RED, 7);

      CreateRect("ZLVL_P2", gaugeX, zone2Up, gaugeW, 2, CLR_NEON_ORANGE);
      CreateLabel("ZLBL_P2", "+2.0 SHORT", lblX, zone2Up - 4, CLR_NEON_ORANGE, 7);

      CreateRect("ZLVL_0", gaugeX, zone0, gaugeW, 1, CLR_TEXT_DIM);
      CreateLabel("ZLBL_0", "0 EXIT", lblX, zone0 - 4, CLR_TEXT_DIM, 7);

      CreateRect("ZLVL_M2", gaugeX, zone2Dn, gaugeW, 2, CLR_NEON_CYAN);
      CreateLabel("ZLBL_M2", "-2.0 LONG", lblX, zone2Dn - 4, CLR_NEON_CYAN, 7);

      CreateRect("ZLVL_M35", gaugeX, zoneBot - 1, gaugeW, 1, CLR_NEON_GREEN);
      CreateLabel("ZLBL_M35", "-3.5 SL", lblX, zoneBot - 5, CLR_NEON_GREEN, 7);

      // Current Z indicator
      double clampedZ = MathMax(minZ, MathMin(maxZ, zScore));
      int zPosY = gaugeY + gaugeH - (int)((clampedZ - minZ) / range * gaugeH);
      color zColor = GetZScoreColor(zScore);

      CreateRect("ZCURRENT", gaugeX - 5, zPosY - 3, gaugeW + 10, 6, zColor);
      CreateLabel("ZCURRENT_LBL", "►", gaugeX - 15, zPosY - 6, zColor, 10);

      // Large value display
      string zText = (zScore > 0 ? "+" : "") + DoubleToString(zScore, 2);
      CreateLabel("ZVALUE", zText, x + w - 80, y + h - 30, zColor, 18, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Draw Signal Strength                                              |
   //+------------------------------------------------------------------+
   void DrawSignalStrength(int x, int y, int w, SPairResult &result) {
      int h = 85;
      CreateRect("STRENGTH_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("STRENGTH_TITLE", "SIGNAL STRENGTH", x + 10, y + 8, CLR_NEON_YELLOW, 9, "Consolas Bold");

      double strength = CalcSignalStrength(result);
      m_signalStrength = strength;

      // Progress bar background
      int barX = x + 15;
      int barY = y + 35;
      int barW = w - 30;
      int barH = 20;

      CreateRect("STRENGTH_BAR_BG", barX, barY, barW, barH, CLR_BG_CHART, CLR_BORDER);

      // Progress bar fill
      int fillW = (int)(barW * strength / 100);
      color fillColor = CLR_NEON_RED;
      if(strength >= 70) fillColor = CLR_NEON_GREEN;
      else if(strength >= 50) fillColor = CLR_NEON_YELLOW;
      else if(strength >= 30) fillColor = CLR_NEON_ORANGE;

      if(fillW > 0) {
         CreateRect("STRENGTH_BAR_FILL", barX, barY, fillW, barH, fillColor);
      }

      // Percentage text
      CreateLabel("STRENGTH_PCT", DoubleToString(strength, 0) + "%", barX + barW / 2 - 15, barY + 3, CLR_TEXT_BRIGHT, 10, "Consolas Bold");

      // Confidence label
      string confText = "LOW";
      if(strength >= 70) confText = "HIGH";
      else if(strength >= 50) confText = "MEDIUM";

      CreateLabel("STRENGTH_CONF", "Confidence: " + confText, x + 15, y + 62, fillColor, 8);
   }

   //+------------------------------------------------------------------+
   //| Draw Regime Panel                                                 |
   //+------------------------------------------------------------------+
   void DrawRegimePanel(int x, int y, int w, SPairResult &result) {
      int h = 75;
      CreateRect("REGIME_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("REGIME_TITLE", "MARKET REGIME", x + 10, y + 8, CLR_NEON_MAGENTA, 9, "Consolas Bold");

      ENUM_REGIME regime = DetectRegime(result);
      m_currentRegime = regime;

      string regimeName = GetRegimeName(regime);
      color regimeColor = GetRegimeColor(regime);

      // Regime indicator
      CreateRect("REGIME_IND", x + 15, y + 35, 15, 15, regimeColor);
      CreateLabel("REGIME_NAME", regimeName, x + 40, y + 36, regimeColor, 10, "Consolas Bold");

      // Recommendation
      string recText = "";
      if(regime == REGIME_MEAN_REVERT) recText = "✓ Ideal for pairs trading";
      else if(regime == REGIME_TRENDING) recText = "✗ Avoid - trending market";
      else if(regime == REGIME_VOLATILE) recText = "! Caution - high volatility";
      else recText = "○ Wait for clearer regime";

      color recColor = (regime == REGIME_MEAN_REVERT) ? CLR_NEON_GREEN : CLR_TEXT_DIM;
      CreateLabel("REGIME_REC", recText, x + 15, y + 55, recColor, 7);
   }

   //+------------------------------------------------------------------+
   //| Draw Risk Metrics                                                 |
   //+------------------------------------------------------------------+
   void DrawRiskMetrics(int x, int y, int w, SPairResult &result) {
      int h = 110;
      CreateRect("METRICS_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("METRICS_TITLE", "RISK METRICS", x + 10, y + 8, CLR_NEON_CYAN, 9, "Consolas Bold");

      int row = 0;
      int rowH = 18;
      int startY = y + 30;
      int valX = x + 150;

      // Half-Life
      color hlColor = result.halfLife < 20 ? CLR_NEON_GREEN : (result.halfLife < 50 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("M_HL_LBL", "Half-Life:", x + 15, startY + row * rowH, CLR_TEXT_DIM, 8);
      CreateLabel("M_HL_VAL", DoubleToString(result.halfLife, 1) + " bars", valX, startY + row * rowH, hlColor, 8, "Consolas Bold");
      row++;

      // Zero-Crossings
      color zcColor = result.zeroCrossings >= 10 ? CLR_NEON_GREEN : CLR_NEON_YELLOW;
      CreateLabel("M_ZC_LBL", "Zero-Crossings:", x + 15, startY + row * rowH, CLR_TEXT_DIM, 8);
      CreateLabel("M_ZC_VAL", IntegerToString(result.zeroCrossings), valX, startY + row * rowH, zcColor, 8, "Consolas Bold");
      row++;

      // ADF Statistic
      color adfColor = result.adfStatistic < -2.86 ? CLR_NEON_GREEN : CLR_NEON_RED;
      CreateLabel("M_ADF_LBL", "ADF Statistic:", x + 15, startY + row * rowH, CLR_TEXT_DIM, 8);
      CreateLabel("M_ADF_VAL", DoubleToString(result.adfStatistic, 2), valX, startY + row * rowH, adfColor, 8, "Consolas Bold");
      row++;

      // Hedge Ratio
      CreateLabel("M_BETA_LBL", "Hedge Ratio (β):", x + 15, startY + row * rowH, CLR_TEXT_DIM, 8);
      CreateLabel("M_BETA_VAL", DoubleToString(result.beta, 4), valX, startY + row * rowH, CLR_NEON_CYAN, 8, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Draw Position Info                                                |
   //+------------------------------------------------------------------+
   void DrawPositionInfo(int x, int y, int w) {
      int h = 80;
      CreateRect("POS_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("POS_TITLE", "ACTIVE POSITIONS", x + 10, y + 8, CLR_NEON_ORANGE, 9, "Consolas Bold");

      CreateLabel("POS_COUNT_LBL", "Open Pairs:", x + 15, y + 32, CLR_TEXT_DIM, 8);
      CreateLabel("POS_COUNT_VAL", "0", x + 150, y + 32, CLR_TEXT_BRIGHT, 8, "Consolas Bold");

      CreateLabel("POS_PL_LBL", "Unrealized P&L:", x + 15, y + 50, CLR_TEXT_DIM, 8);
      CreateLabel("POS_PL_VAL", "$0.00", x + 150, y + 50, CLR_NEON_GREEN, 8, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Draw Mini Equity Curve                                            |
   //+------------------------------------------------------------------+
   void DrawMiniEquityCurve(int x, int y, int w, int h) {
      CreateRect("EQ_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("EQ_TITLE", "EQUITY CURVE", x + 10, y + 6, CLR_NEON_CYAN, 8, "Consolas Bold");

      // Chart area
      int chartX = x + 10;
      int chartY = y + 25;
      int chartW = w - 20;
      int chartH = h - 35;

      CreateRect("EQ_CHART", chartX, chartY, chartW, chartH, CLR_BG_CHART, CLR_GRID);

      if(m_equitySize < 2) {
         CreateLabel("EQ_EMPTY", "No data yet", chartX + chartW/2 - 30, chartY + chartH/2 - 5, CLR_TEXT_MUTED, 8);
         return;
      }

      // Find min/max
      double minVal = m_equityCurve[0], maxVal = m_equityCurve[0];
      for(int i = 1; i < m_equitySize; i++) {
         if(m_equityCurve[i] < minVal) minVal = m_equityCurve[i];
         if(m_equityCurve[i] > maxVal) maxVal = m_equityCurve[i];
      }

      double range = maxVal - minVal;
      if(range < 1) range = 1;

      // Draw zero line if visible
      if(minVal < 0 && maxVal > 0) {
         int zeroY = chartY + chartH - (int)((0 - minVal) / range * chartH);
         CreateRect("EQ_ZERO", chartX, zeroY, chartW, 1, CLR_TEXT_MUTED);
      }

      // Draw equity line
      int pointsToShow = MathMin(m_equitySize, chartW / 3);
      int step = MathMax(1, m_equitySize / pointsToShow);

      for(int i = 0; i < pointsToShow; i++) {
         int idx = i * step;
         if(idx >= m_equitySize) break;

         int pointX = chartX + (int)((double)i / pointsToShow * chartW);
         int pointY = chartY + chartH - (int)((m_equityCurve[idx] - minVal) / range * chartH);
         pointY = MathMax(chartY, MathMin(chartY + chartH - 2, pointY));

         color ptColor = m_equityCurve[idx] >= 0 ? CLR_NEON_GREEN : CLR_NEON_RED;

         string ptName = m_prefix + "EQ_PT_" + IntegerToString(i);
         if(ObjectFind(0, ptName) < 0) {
            ObjectCreate(0, ptName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         }
         ObjectSetInteger(0, ptName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, ptName, OBJPROP_XDISTANCE, pointX);
         ObjectSetInteger(0, ptName, OBJPROP_YDISTANCE, pointY);
         ObjectSetInteger(0, ptName, OBJPROP_XSIZE, 3);
         ObjectSetInteger(0, ptName, OBJPROP_YSIZE, 3);
         ObjectSetInteger(0, ptName, OBJPROP_BGCOLOR, ptColor);
         ObjectSetInteger(0, ptName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, ptName, OBJPROP_BORDER_COLOR, ptColor);
         ObjectSetInteger(0, ptName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, ptName, OBJPROP_HIDDEN, true);
      }
   }

   //+------------------------------------------------------------------+
   //| Draw Alert Settings Panel                                         |
   //+------------------------------------------------------------------+
   void DrawAlertSettings(int x, int y, int w) {
      int h = 70;
      CreateRect("ALERT_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("ALERT_TITLE", "ALERT SETTINGS", x + 10, y + 6, CLR_NEON_ORANGE, 8, "Consolas Bold");

      // Alert status
      string statusText = m_alertsEnabled ? "ACTIVE" : "OFF";
      color statusColor = m_alertsEnabled ? CLR_NEON_GREEN : CLR_NEON_RED;
      CreateLabel("ALERT_STATUS_L", "Status:", x + 15, y + 28, CLR_TEXT_DIM, 7);
      CreateLabel("ALERT_STATUS_V", statusText, x + 70, y + 28, statusColor, 7, "Consolas Bold");

      // Thresholds
      CreateLabel("ALERT_TH_L", "Z-Threshold:", x + 15, y + 45, CLR_TEXT_DIM, 7);
      CreateLabel("ALERT_TH_V", DoubleToString(m_alertThresholdZ, 1), x + 95, y + 45, CLR_NEON_CYAN, 7, "Consolas Bold");

      CreateLabel("ALERT_STR_L", "Strength:", x + 150, y + 45, CLR_TEXT_DIM, 7);
      CreateLabel("ALERT_STR_V", DoubleToString(m_alertThresholdStrength, 0) + "%", x + 210, y + 45, CLR_NEON_CYAN, 7, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Draw Advanced Analytics Panel                                      |
   //+------------------------------------------------------------------+
   void DrawAdvancedAnalytics(int x, int y, int w, SPairResult &result) {
      int h = 130;
      CreateRect("ADV_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("ADV_TITLE", "ADVANCED ANALYTICS", x + 10, y + 6, CLR_NEON_MAGENTA, 9, "Consolas Bold");

      int row = 0;
      int rowH = 16;
      int startY = y + 26;
      int valX = x + 140;

      // Hurst Exponent
      color hurstColor = result.hurstExponent < 0.45 ? CLR_NEON_GREEN :
                        (result.hurstExponent < 0.55 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      string hurstText = result.hurstExponent < 0.45 ? "MEAN REVERT" :
                        (result.hurstExponent < 0.55 ? "RANDOM" : "TRENDING");
      CreateLabel("ADV_H_L", "Hurst Exponent:", x + 10, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("ADV_H_V", DoubleToString(result.hurstExponent, 3) + " (" + hurstText + ")", valX, startY + row * rowH, hurstColor, 7, "Consolas Bold");
      row++;

      // Volatility Ratio
      color volColor = (result.volatilityRatio >= 0.7 && result.volatilityRatio <= 1.3) ? CLR_NEON_GREEN :
                       (result.volatilityRatio <= 1.8 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      string volText = result.volatilityRatio < 0.7 ? "LOW VOL" :
                      (result.volatilityRatio > 1.5 ? "HIGH VOL" : "NORMAL");
      CreateLabel("ADV_V_L", "Vol Ratio:", x + 10, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("ADV_V_V", DoubleToString(result.volatilityRatio, 2) + "x (" + volText + ")", valX, startY + row * rowH, volColor, 7, "Consolas Bold");
      row++;

      // Quality Score
      color qualColor = result.qualityScore >= 70 ? CLR_NEON_GREEN :
                       (result.qualityScore >= 50 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      string qualText = result.qualityScore >= 70 ? "EXCELLENT" :
                       (result.qualityScore >= 50 ? "GOOD" : "POOR");
      CreateLabel("ADV_Q_L", "Quality Score:", x + 10, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("ADV_Q_V", IntegerToString(result.qualityScore) + "/100 (" + qualText + ")", valX, startY + row * rowH, qualColor, 7, "Consolas Bold");
      row++;

      // Kelly Fraction
      CreateLabel("ADV_K_L", "Kelly Fraction:", x + 10, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("ADV_K_V", DoubleToString(result.kellyFraction * 100, 1) + "% of capital", valX, startY + row * rowH, CLR_NEON_CYAN, 7, "Consolas Bold");
      row++;

      // Expected Return
      CreateLabel("ADV_E_L", "Exp. Return:", x + 10, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("ADV_E_V", DoubleToString(result.expectedReturn * 10000, 2) + " pips", valX, startY + row * rowH, CLR_NEON_CYAN, 7, "Consolas Bold");
      row++;

      // Trade Recommendation
      row++;
      string recText = "";
      color recColor = CLR_TEXT_DIM;

      if(result.qualityScore >= 70 && MathAbs(result.zScore) >= 2.0 && result.hurstExponent < 0.5) {
         recText = "★★★ STRONG " + (result.zScore > 0 ? "SHORT" : "LONG") + " SIGNAL";
         recColor = result.zScore > 0 ? CLR_NEON_RED : CLR_NEON_GREEN;
      }
      else if(result.qualityScore >= 50 && MathAbs(result.zScore) >= 1.5) {
         recText = "★★ MODERATE " + (result.zScore > 0 ? "SHORT" : "LONG") + " SIGNAL";
         recColor = CLR_NEON_YELLOW;
      }
      else if(result.hurstExponent > 0.55) {
         recText = "⚠ AVOID - Trending Market";
         recColor = CLR_NEON_RED;
      }
      else {
         recText = "○ WAIT - No Clear Signal";
         recColor = CLR_TEXT_DIM;
      }

      CreateLabel("ADV_REC", recText, x + 10, startY + row * rowH, recColor, 8, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| DRAW: BOTTOM PANEL - Charts & Controls                            |
   //+------------------------------------------------------------------+
   void DrawBottomPanel(int x, int y, SPairResult &result) {
      int w = SCANNER_WIDTH;

      // === SPREAD CHART ===
      DrawSpreadChart(x, y, SPREAD_CHART_W, SPREAD_CHART_H, result);

      // === CONTROL PANEL ===
      int ctrlY = y + SPREAD_CHART_H + 5;
      DrawControlPanel(x, ctrlY, w);
   }

   //+------------------------------------------------------------------+
   //| Draw Spread Chart                                                 |
   //+------------------------------------------------------------------+
   void DrawSpreadChart(int x, int y, int w, int h, SPairResult &result) {
      // Background
      CreateRect("SPREAD_BG", x, y, w, h, CLR_BG_PANEL, CLR_BORDER);

      // Header
      CreateRect("SPREAD_HDR", x, y, w, 25, CLR_BG_HEADER, CLR_BORDER);
      CreateLabel("SPREAD_TITLE", "SPREAD: " + result.pairName, x + 10, y + 5, CLR_TEXT_BRIGHT, 9, "Consolas Bold");
      CreateLabel("SPREAD_BETA", "β=" + DoubleToString(result.beta, 4), x + 250, y + 6, CLR_NEON_CYAN, 8);
      CreateLabel("SPREAD_TF", "H4", x + 350, y + 6, CLR_TEXT_DIM, 8);

      // Chart area
      int chartX = x + 50;
      int chartY = y + 30;
      int chartW = w - 70;
      int chartH = h - 55;

      CreateRect("SPREAD_CHART", chartX, chartY, chartW, chartH, CLR_BG_CHART, CLR_GRID);

      // Draw spread line
      if(m_historySize > 10) {
         DrawSpreadLineOnChart(chartX, chartY, chartW, chartH, result);
      }

      // Footer stats
      int footY = y + h - 22;
      CreateLabel("SPREAD_MEAN", "μ=" + DoubleToString(result.spreadMean, 6), x + 10, footY, CLR_TEXT_DIM, 7);
      CreateLabel("SPREAD_STD", "σ=" + DoubleToString(result.spreadStdDev, 6), x + 140, footY, CLR_TEXT_DIM, 7);
      CreateLabel("SPREAD_CUR", "Current=" + DoubleToString(result.currentSpread, 6), x + 280, footY, CLR_TEXT_BRIGHT, 7);
   }

   //+------------------------------------------------------------------+
   //| Draw spread line on chart                                         |
   //+------------------------------------------------------------------+
   void DrawSpreadLineOnChart(int chartX, int chartY, int chartW, int chartH, SPairResult &result) {
      if(m_historySize < 2) return;

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

      // Bollinger Bands
      int bbUpperY = chartY + chartH - (int)((mean + 2 * stdDev - minVal) / range * chartH);
      int bbMiddleY = chartY + chartH - (int)((mean - minVal) / range * chartH);
      int bbLowerY = chartY + chartH - (int)((mean - 2 * stdDev - minVal) / range * chartH);

      bbUpperY = MathMax(chartY, MathMin(chartY + chartH - 1, bbUpperY));
      bbMiddleY = MathMax(chartY, MathMin(chartY + chartH - 1, bbMiddleY));
      bbLowerY = MathMax(chartY, MathMin(chartY + chartH - 1, bbLowerY));

      CreateRect("BB_UPPER", chartX, bbUpperY, chartW, 2, CLR_BB_UPPER);
      CreateRect("BB_MIDDLE", chartX, bbMiddleY, chartW, 1, CLR_BB_MIDDLE);
      CreateRect("BB_LOWER", chartX, bbLowerY, chartW, 2, CLR_BB_LOWER);

      // Y-axis labels
      int lblX = chartX - 45;
      CreateLabel("BB_LBL_U", "+2σ SELL", lblX, bbUpperY - 5, CLR_BB_UPPER, 7);
      CreateLabel("BB_LBL_M", "μ EXIT", lblX, bbMiddleY - 5, CLR_BB_MIDDLE, 7);
      CreateLabel("BB_LBL_L", "-2σ BUY", lblX, bbLowerY - 5, CLR_BB_LOWER, 7);

      // Spread points
      int pointW = MathMax(2, chartW / m_historySize);
      int displayPoints = MathMin(m_historySize, chartW / pointW);

      for(int i = 0; i < displayPoints; i++) {
         if(i >= m_historySize) continue;

         int pointX = chartX + chartW - (i + 1) * pointW;
         int pointY = chartY + chartH - (int)((m_spreadHistory[i] - minVal) / range * chartH);
         pointY = MathMax(chartY, MathMin(chartY + chartH - 2, pointY));

         string pointName = m_prefix + "SPT_" + IntegerToString(i);
         if(ObjectFind(0, pointName) < 0) {
            ObjectCreate(0, pointName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         }
         ObjectSetInteger(0, pointName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, pointName, OBJPROP_XDISTANCE, pointX);
         ObjectSetInteger(0, pointName, OBJPROP_YDISTANCE, pointY);
         ObjectSetInteger(0, pointName, OBJPROP_XSIZE, MathMax(2, pointW - 1));
         ObjectSetInteger(0, pointName, OBJPROP_YSIZE, 3);
         ObjectSetInteger(0, pointName, OBJPROP_BGCOLOR, CLR_SPREAD_LINE);
         ObjectSetInteger(0, pointName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, pointName, OBJPROP_BORDER_COLOR, CLR_SPREAD_LINE);
         ObjectSetInteger(0, pointName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, pointName, OBJPROP_HIDDEN, true);
      }
   }

   //+------------------------------------------------------------------+
   //| Draw Control Panel                                                |
   //+------------------------------------------------------------------+
   void DrawControlPanel(int x, int y, int w) {
      int h = CONTROL_HEIGHT;

      CreateRect("CTRL_BG", x, y, w, h, CLR_BG_PANEL, CLR_BORDER);
      CreateRect("CTRL_HDR", x, y, w, 22, CLR_BG_HEADER, CLR_BORDER);
      CreateLabel("CTRL_TITLE", "▼ TRADE EXECUTION", x + 10, y + 4, CLR_NEON_CYAN, 8, "Consolas Bold");

      // Buttons
      int btnY = y + 28;
      int btnH = 30;

      CreateButton("BTN_SCAN", "SCAN MARKET", x + 10, btnY, 120, btnH, C'15,60,30', CLR_NEON_GREEN, 9);
      CreateButton("BTN_EXEC", "EXECUTE HEDGE", x + 140, btnY, 130, btnH, C'15,40,80', CLR_NEON_CYAN, 9);
      CreateButton("BTN_CLOSE", "CLOSE ALL", x + 280, btnY, 100, btnH, C'80,25,25', CLR_NEON_RED, 9);

      // Risk info
      int infoX = x + 400;
      CreateLabel("CTRL_DD_LBL", "Max DD:", infoX, btnY + 2, CLR_TEXT_DIM, 8);
      CreateLabel("CTRL_DD_VAL", "0.00%", infoX + 55, btnY + 2, CLR_TEXT_BRIGHT, 8, "Consolas Bold");

      CreateLabel("CTRL_RISK_LBL", "Risk/Trade:", infoX, btnY + 18, CLR_TEXT_DIM, 8);
      CreateLabel("CTRL_RISK_VAL", "1.0%", infoX + 70, btnY + 18, CLR_NEON_YELLOW, 8, "Consolas Bold");

      // Footer instructions
      CreateLabel("CTRL_HELP", "Keys: Q=Toggle | R=Refresh | X=Close All", x + 10, y + h - 18, CLR_TEXT_MUTED, 7);
   }

   //+------------------------------------------------------------------+
   //| Delete all content objects (for minimize)                         |
   //+------------------------------------------------------------------+
   void DeleteAllContent() {
      int total = ObjectsTotal(0, 0, -1);
      for(int i = total - 1; i >= 0; i--) {
         string name = ObjectName(0, i, 0, -1);
         if(StringFind(name, m_prefix) != 0) continue;
         if(StringFind(name, m_prefix + "TITLE") == 0 && StringFind(name, "TITLE_BG") < 0) continue;
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
      m_startY = 25;
      m_isVisible = true;
      m_isMinimized = false;
      m_resultCount = 0;
      m_selectedRow = -1;
      m_scrollOffset = 0;
      m_historySize = 0;
      m_signalStrength = 0;
      m_estimatedSharpe = 0;
      m_signalCount = 0;
      m_winCount = 0;
      m_currentRegime = REGIME_CONSOLIDATION;

      // Signal History initialization
      m_maxHistory = 100;
      m_historyCount = 0;
      ArrayResize(m_signalHistory, m_maxHistory);

      // Performance Stats initialization
      ZeroMemory(m_perfStats);
      m_perfStats.profitFactor = 1.0;
      m_equitySize = 0;

      // Correlation Matrix initialization
      for(int i = 0; i < 6; i++) {
         m_corrPairs[i] = "";
         for(int j = 0; j < 6; j++) {
            m_correlationMatrix[i][j] = (i == j) ? 1.0 : 0.0;
         }
      }

      // Alert System initialization
      m_alertThresholdZ = 2.0;
      m_alertThresholdStrength = 60;
      m_alertsEnabled = true;
      m_lastAlertTime = 0;
      m_alertCooldown = 300;  // 5 minutes cooldown
   }

   ~CDashboard() { ObjectsDeleteAll(0, m_prefix); }

   void SetPosition(int x, int y) { m_startX = x; m_startY = y; }

   void UpdateResults(SPairResult &results[], int count) {
      m_resultCount = count;
      ArrayResize(m_scanResults, count);
      for(int i = 0; i < count; i++) m_scanResults[i] = results[i];
   }

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
   //| Draw Full Dashboard - 3 SEPARATE PANELS Layout                    |
   //| TOP = Header with Scanner (full width at top)                     |
   //| RIGHT = Analytics panel (vertical on right side)                  |
   //| BOTTOM = Spread Chart + Performance (full width at bottom)        |
   //+------------------------------------------------------------------+
   void Draw() {
      if(!m_isVisible) return;

      // Get chart dimensions
      int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

      if(m_isMinimized) {
         DeleteAllContent();
         // Minimized bar at top
         CreateRect("TITLE_BG", 5, 25, chartWidth - 10, 28, CLR_BG_MAIN, CLR_NEON_CYAN);
         CreateLabel("TITLE", "D-LOGIC QUANT v4.20 [MINIMIZED] - Press Q to expand", 15, 30, CLR_TEXT_BRIGHT, 9, "Consolas Bold");
         CreateButton("BTN_MIN", "+", chartWidth - 35, 28, 22, 20, CLR_BG_PANEL, CLR_TEXT_BRIGHT, 12);
         ChartRedraw(0);
         return;
      }

      // Get selected pair data
      SPairResult displayResult;
      if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
         displayResult = m_scanResults[m_selectedRow];
      } else if(m_resultCount > 0) {
         displayResult = m_scanResults[0];
      } else {
         ZeroMemory(displayResult);
         displayResult.pairName = "NO DATA";
         displayResult.signalText = "NO DATA";
         displayResult.hurstExponent = 0.5;
         displayResult.volatilityRatio = 1.0;
         displayResult.qualityScore = 0;
      }

      // ================================================================
      // PANEL 1: TOP PANEL (Header + Scanner) - Full width at top
      // ================================================================
      int topPanelX = CHART_MARGIN;
      int topPanelY = TOP_PANEL_Y;
      int topPanelW = chartWidth - RIGHT_PANEL_WIDTH - CHART_MARGIN * 3;
      int topPanelH = TOP_PANEL_HEIGHT;

      DrawSeparateTopPanel(topPanelX, topPanelY, topPanelW, topPanelH);

      // ================================================================
      // PANEL 2: RIGHT PANEL (Analytics) - Vertical on right side
      // ================================================================
      int rightPanelX = chartWidth - RIGHT_PANEL_WIDTH - CHART_MARGIN;
      int rightPanelY = TOP_PANEL_Y;
      int rightPanelW = RIGHT_PANEL_WIDTH;
      int rightPanelH = chartHeight - TOP_PANEL_Y - CHART_MARGIN - 25;

      DrawSeparateRightPanel(rightPanelX, rightPanelY, rightPanelW, rightPanelH, displayResult);

      // ================================================================
      // PANEL 3: BOTTOM PANEL (Spread + Performance) - At bottom
      // ================================================================
      int bottomPanelX = CHART_MARGIN;
      int bottomPanelY = chartHeight - BOTTOM_PANEL_HEIGHT - CHART_MARGIN;
      int bottomPanelW = chartWidth - RIGHT_PANEL_WIDTH - CHART_MARGIN * 3;
      int bottomPanelH = BOTTOM_PANEL_HEIGHT;

      DrawSeparateBottomPanel(bottomPanelX, bottomPanelY, bottomPanelW, bottomPanelH, displayResult);

      // Process alerts
      ProcessAlerts();

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Draw TOP Panel (Header + Scanner)                                 |
   //+------------------------------------------------------------------+
   void DrawSeparateTopPanel(int x, int y, int w, int h) {
      // Panel background
      CreateRect("TOP_BG", x, y, w, h, CLR_BG_PANEL, CLR_NEON_CYAN);

      // Title bar
      CreateRect("TOP_TITLE_BG", x, y, w, 28, CLR_BG_HEADER, CLR_NEON_CYAN);
      CreateLabel("TOP_TITLE", "D-LOGIC QUANT DASHBOARD v4.20", x + 10, y + 6, CLR_TEXT_BRIGHT, 10, "Consolas Bold");
      CreateLabel("TOP_SUBTITLE", "Statistical Arbitrage Engine", x + 280, y + 8, CLR_NEON_CYAN, 8);

      // Status indicator
      CreateRect("TOP_STATUS_DOT", x + w - 55, y + 9, 10, 10, CLR_NEON_GREEN);
      CreateLabel("TOP_STATUS_TXT", "LIVE", x + w - 42, y + 7, CLR_NEON_GREEN, 8);

      // Minimize button
      CreateButton("BTN_MIN", "-", x + w - 25, y + 4, 20, 20, CLR_BG_PANEL, CLR_TEXT_BRIGHT, 12);

      // Scanner section
      int scanY = y + 32;
      int scanH = h - 36;

      CreateRect("SCAN_HDR", x, scanY, w, 22, CLR_BG_MAIN, CLR_BORDER);
      CreateLabel("SCAN_TITLE", "▼ PAIRS SCANNER", x + 10, scanY + 4, CLR_NEON_CYAN, 8, "Consolas Bold");
      CreateLabel("SCAN_COUNT", IntegerToString(m_resultCount) + " pairs", x + w - 70, scanY + 5, CLR_TEXT_DIM, 7);

      // Column headers
      int headerY = scanY + 24;
      int cols[] = {10, 140, 185, 250, 305, 355, 400, 480, 580};

      CreateLabel("H_COINT", "●", x + cols[0], headerY, CLR_TEXT_DIM, 7);
      CreateLabel("H_PAIR", "PAIR", x + cols[1] - 120, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("H_TF", "TF", x + cols[2] - 120, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("H_ZSCORE", "Z-SCORE", x + cols[3] - 120, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("H_R2", "R²", x + cols[4] - 120, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("H_HALF", "HL", x + cols[5] - 120, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("H_HURST", "H", x + cols[6] - 120, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("H_QUAL", "QUAL", x + cols[7] - 120, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");
      CreateLabel("H_SIGNAL", "SIGNAL", x + cols[8] - 120, headerY, CLR_TEXT_DIM, 7, "Consolas Bold");

      // Draw rows
      int rowY = headerY + 18;
      int displayRows = MathMin(SCANNER_MAX_ROWS, m_resultCount - m_scrollOffset);

      for(int i = 0; i < displayRows; i++) {
         int idx = i + m_scrollOffset;
         if(idx >= m_resultCount) break;

         bool isSelected = (idx == m_selectedRow);
         DrawCompactScannerRow(i, x, rowY + i * SCANNER_ROW_HEIGHT, m_scanResults[idx], isSelected, cols);
      }

      // Summary bar
      int summaryY = y + h - 20;
      CreateRect("SUM_BG", x, summaryY, w, 20, CLR_BG_HEADER, CLR_BORDER);

      int strongSignals = 0, cointegrated = 0;
      for(int i = 0; i < m_resultCount; i++) {
         if(MathAbs(m_scanResults[i].signal) == 2) strongSignals++;
         if(m_scanResults[i].isCointegrated) cointegrated++;
      }

      CreateLabel("SUM_SIG", "Strong: " + IntegerToString(strongSignals), x + 10, summaryY + 4, CLR_NEON_GREEN, 7);
      CreateLabel("SUM_COINT", "Coint: " + IntegerToString(cointegrated), x + 100, summaryY + 4, CLR_NEON_CYAN, 7);
      CreateLabel("SUM_TIME", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES), x + w - 110, summaryY + 4, CLR_TEXT_DIM, 7);
   }

   //+------------------------------------------------------------------+
   //| Draw Compact Scanner Row                                          |
   //+------------------------------------------------------------------+
   void DrawCompactScannerRow(int index, int baseX, int y, SPairResult &result, bool isSelected, int &cols[]) {
      string rowName = "ROW_" + IntegerToString(index);
      int rowH = SCANNER_ROW_HEIGHT;

      // Background
      color bgColor = isSelected ? CLR_BG_HOVER : (index % 2 == 0) ? CLR_BG_ROW : CLR_BG_ROW_ALT;
      CreateRect(rowName + "_BG", baseX, y, cols[8] + 50, rowH, bgColor, CLR_BG_MAIN);

      // Cointegration dot
      color dotColor = result.isCointegrated ? CLR_NEON_GREEN : CLR_NEON_RED;
      CreateRect(rowName + "_DOT", baseX + cols[0], y + 4, 6, 6, dotColor);

      // Pair name
      color pairColor = isSelected ? CLR_NEON_CYAN : CLR_TEXT_BRIGHT;
      CreateLabel(rowName + "_PAIR", result.pairName, baseX + cols[1] - 120, y + 1, pairColor, 7);

      // Timeframe
      string tfName = result.timeframe == PERIOD_D1 ? "D1" : (result.timeframe == PERIOD_H1 ? "H1" : "H4");
      CreateLabel(rowName + "_TF", tfName, baseX + cols[2] - 120, y + 1, CLR_TEXT_DIM, 7);

      // Z-Score
      color zColor = GetZScoreColor(result.zScore);
      string zPrefix = result.zScore > 0 ? "+" : "";
      CreateLabel(rowName + "_Z", zPrefix + DoubleToString(result.zScore, 2), baseX + cols[3] - 120, y + 1, zColor, 7, "Consolas Bold");

      // R²
      color r2Color = result.rSquared >= 0.7 ? CLR_NEON_CYAN : CLR_TEXT_DIM;
      CreateLabel(rowName + "_R2", DoubleToString(result.rSquared * 100, 0) + "%", baseX + cols[4] - 120, y + 1, r2Color, 7);

      // Half-life
      string hlText = result.halfLife < 100 ? DoubleToString(result.halfLife, 1) : "99+";
      color hlColor = result.halfLife < 20 ? CLR_NEON_GREEN : (result.halfLife < 50 ? CLR_NEON_YELLOW : CLR_TEXT_DIM);
      CreateLabel(rowName + "_HL", hlText, baseX + cols[5] - 120, y + 1, hlColor, 7);

      // Hurst
      color hurstColor = result.hurstExponent < 0.45 ? CLR_NEON_GREEN :
                        (result.hurstExponent < 0.55 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel(rowName + "_HU", DoubleToString(result.hurstExponent, 2), baseX + cols[6] - 120, y + 1, hurstColor, 7);

      // Quality
      color qualColor = result.qualityScore >= 70 ? CLR_NEON_GREEN :
                       (result.qualityScore >= 50 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel(rowName + "_QS", IntegerToString(result.qualityScore), baseX + cols[7] - 120, y + 1, qualColor, 7, "Consolas Bold");

      // Signal
      color sigColor = CLR_TEXT_DIM;
      if(MathAbs(result.signal) == 2) sigColor = (result.signal > 0) ? CLR_NEON_GREEN : CLR_NEON_RED;
      else if(MathAbs(result.signal) == 1) sigColor = CLR_NEON_YELLOW;
      CreateLabel(rowName + "_SIG", result.signalText, baseX + cols[8] - 120, y + 1, sigColor, 6);
   }

   //+------------------------------------------------------------------+
   //| Draw RIGHT Panel (Analytics) - Vertical                           |
   //+------------------------------------------------------------------+
   void DrawSeparateRightPanel(int x, int y, int w, int h, SPairResult &result) {
      // Panel background
      CreateRect("RIGHT_BG", x, y, w, h, CLR_BG_PANEL, CLR_NEON_MAGENTA);

      // Title
      CreateRect("RIGHT_HDR", x, y, w, 24, CLR_BG_HEADER, CLR_NEON_MAGENTA);
      CreateLabel("RIGHT_TITLE", "▶ ANALYTICS", x + 10, y + 5, CLR_NEON_MAGENTA, 9, "Consolas Bold");

      int panelY = y + 28;
      int panelW = w - 10;

      // Z-Score Gauge (compact)
      DrawCompactZScoreGauge(x + 5, panelY, panelW, 110, result.zScore);
      panelY += 118;

      // Signal Strength
      DrawSignalStrength(x + 5, panelY, panelW, result);
      panelY += 85;

      // Regime Panel
      DrawRegimePanel(x + 5, panelY, panelW, result);
      panelY += 80;

      // Risk Metrics
      DrawRiskMetrics(x + 5, panelY, panelW, result);
      panelY += 115;

      // Advanced Analytics
      DrawCompactAdvancedAnalytics(x + 5, panelY, panelW, result);
      panelY += 120;

      // Position Info
      DrawPositionInfo(x + 5, panelY, panelW);
      panelY += 85;

      // Alerts
      DrawAlertSettings(x + 5, panelY, panelW);
   }

   //+------------------------------------------------------------------+
   //| Draw Compact Z-Score Gauge                                        |
   //+------------------------------------------------------------------+
   void DrawCompactZScoreGauge(int x, int y, int w, int h, double zScore) {
      CreateRect("ZGAUGE_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("ZGAUGE_TITLE", "Z-SCORE", x + 10, y + 5, CLR_NEON_CYAN, 8, "Consolas Bold");

      // Large Z value
      color zColor = GetZScoreColor(zScore);
      string zText = (zScore > 0 ? "+" : "") + DoubleToString(zScore, 2);
      CreateLabel("ZVALUE_BIG", zText, x + w/2 - 40, y + 30, zColor, 20, "Consolas Bold");

      // Zone indicator
      string zoneText = "NEUTRAL";
      color zoneColor = CLR_TEXT_DIM;
      if(zScore >= 2.5) { zoneText = "STOP LOSS"; zoneColor = CLR_NEON_RED; }
      else if(zScore >= 2.0) { zoneText = "SHORT ZONE"; zoneColor = CLR_NEON_ORANGE; }
      else if(zScore <= -2.5) { zoneText = "STOP LOSS"; zoneColor = CLR_NEON_RED; }
      else if(zScore <= -2.0) { zoneText = "LONG ZONE"; zoneColor = CLR_NEON_GREEN; }
      else if(MathAbs(zScore) <= 0.5) { zoneText = "EXIT ZONE"; zoneColor = CLR_NEON_YELLOW; }

      CreateLabel("ZZONE_TXT", zoneText, x + w/2 - 35, y + 70, zoneColor, 9, "Consolas Bold");

      // Mini bar
      int barX = x + 10;
      int barY = y + 90;
      int barW = w - 20;
      int barH = 12;

      CreateRect("ZBAR_BG", barX, barY, barW, barH, CLR_BG_CHART, CLR_BORDER);

      // Z position on bar
      double clampedZ = MathMax(-3.5, MathMin(3.5, zScore));
      int zPosX = barX + (int)((clampedZ + 3.5) / 7.0 * barW);
      CreateRect("ZBAR_POS", zPosX - 3, barY - 2, 6, barH + 4, zColor);
   }

   //+------------------------------------------------------------------+
   //| Draw Compact Advanced Analytics                                   |
   //+------------------------------------------------------------------+
   void DrawCompactAdvancedAnalytics(int x, int y, int w, SPairResult &result) {
      int h = 115;
      CreateRect("ADV_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("ADV_TITLE", "QUANT METRICS", x + 10, y + 5, CLR_NEON_MAGENTA, 8, "Consolas Bold");

      int row = 0;
      int rowH = 15;
      int startY = y + 22;
      int valX = x + 120;

      // Hurst
      color hurstColor = result.hurstExponent < 0.45 ? CLR_NEON_GREEN :
                        (result.hurstExponent < 0.55 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("ADV_H_L", "Hurst:", x + 8, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("ADV_H_V", DoubleToString(result.hurstExponent, 3), valX, startY + row * rowH, hurstColor, 7, "Consolas Bold");
      row++;

      // Vol Ratio
      color volColor = (result.volatilityRatio >= 0.7 && result.volatilityRatio <= 1.3) ? CLR_NEON_GREEN : CLR_NEON_YELLOW;
      CreateLabel("ADV_V_L", "Vol Ratio:", x + 8, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("ADV_V_V", DoubleToString(result.volatilityRatio, 2) + "x", valX, startY + row * rowH, volColor, 7, "Consolas Bold");
      row++;

      // Quality
      color qualColor = result.qualityScore >= 70 ? CLR_NEON_GREEN :
                       (result.qualityScore >= 50 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("ADV_Q_L", "Quality:", x + 8, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("ADV_Q_V", IntegerToString(result.qualityScore) + "/100", valX, startY + row * rowH, qualColor, 7, "Consolas Bold");
      row++;

      // Kelly
      CreateLabel("ADV_K_L", "Kelly:", x + 8, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("ADV_K_V", DoubleToString(result.kellyFraction * 100, 1) + "%", valX, startY + row * rowH, CLR_NEON_CYAN, 7, "Consolas Bold");
      row++;

      // Recommendation
      row++;
      string recText = "";
      color recColor = CLR_TEXT_DIM;

      if(result.qualityScore >= 70 && MathAbs(result.zScore) >= 2.0 && result.hurstExponent < 0.5) {
         recText = "★★★ STRONG";
         recColor = result.zScore > 0 ? CLR_NEON_RED : CLR_NEON_GREEN;
      }
      else if(result.qualityScore >= 50 && MathAbs(result.zScore) >= 1.5) {
         recText = "★★ MODERATE";
         recColor = CLR_NEON_YELLOW;
      }
      else if(result.hurstExponent > 0.55) {
         recText = "⚠ TRENDING";
         recColor = CLR_NEON_RED;
      }
      else {
         recText = "○ WAIT";
         recColor = CLR_TEXT_DIM;
      }

      CreateLabel("ADV_REC", recText, x + 8, startY + row * rowH, recColor, 8, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Draw BOTTOM Panel (Spread Chart + Performance + Signal Log)       |
   //+------------------------------------------------------------------+
   void DrawSeparateBottomPanel(int x, int y, int w, int h, SPairResult &result) {
      // Panel background
      CreateRect("BOTTOM_BG", x, y, w, h, CLR_BG_PANEL, CLR_NEON_YELLOW);

      // Title
      CreateRect("BOTTOM_HDR", x, y, w, 22, CLR_BG_HEADER, CLR_NEON_YELLOW);
      CreateLabel("BOTTOM_TITLE", "▼ SPREAD ANALYSIS & PERFORMANCE", x + 10, y + 4, CLR_NEON_YELLOW, 8, "Consolas Bold");

      // Control buttons
      CreateButton("BTN_SCAN", "SCAN", x + w - 220, y + 2, 50, 18, C'15,60,30', CLR_NEON_GREEN, 7);
      CreateButton("BTN_EXEC", "EXECUTE", x + w - 160, y + 2, 60, 18, C'15,40,80', CLR_NEON_CYAN, 7);
      CreateButton("BTN_CLOSE", "CLOSE ALL", x + w - 90, y + 2, 70, 18, C'80,25,25', CLR_NEON_RED, 7);

      int contentY = y + 26;
      int contentH = h - 30;

      // Split into 3 sections
      int section1W = (int)(w * 0.45);  // Spread Chart
      int section2W = (int)(w * 0.28);  // Performance
      int section3W = w - section1W - section2W - 10;  // Signal Log

      // Section 1: Spread Chart
      DrawCompactSpreadChart(x + 2, contentY, section1W, contentH - 4, result);

      // Section 2: Performance
      DrawCompactPerformance(x + section1W + 5, contentY, section2W, contentH - 4);

      // Section 3: Signal Log
      DrawCompactSignalLog(x + section1W + section2W + 8, contentY, section3W - 2, contentH - 4);
   }

   //+------------------------------------------------------------------+
   //| Draw Compact Spread Chart                                         |
   //+------------------------------------------------------------------+
   void DrawCompactSpreadChart(int x, int y, int w, int h, SPairResult &result) {
      CreateRect("SPREAD_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("SPREAD_TITLE", "SPREAD: " + result.pairName, x + 8, y + 4, CLR_TEXT_BRIGHT, 8, "Consolas Bold");
      CreateLabel("SPREAD_BETA", "β=" + DoubleToString(result.beta, 4), x + w - 100, y + 5, CLR_NEON_CYAN, 7);

      // Chart area
      int chartX = x + 45;
      int chartY = y + 22;
      int chartW = w - 55;
      int chartH = h - 45;

      CreateRect("SPREAD_CHART", chartX, chartY, chartW, chartH, CLR_BG_CHART, CLR_GRID);

      // Draw spread line
      if(m_historySize > 10) {
         DrawSpreadLineOnChart(chartX, chartY, chartW, chartH, result);
      }

      // Stats
      CreateLabel("SPREAD_STATS", "μ=" + DoubleToString(result.spreadMean, 5) + "  σ=" + DoubleToString(result.spreadStdDev, 5),
                  x + 8, y + h - 15, CLR_TEXT_DIM, 6);
   }

   //+------------------------------------------------------------------+
   //| Draw Compact Performance                                          |
   //+------------------------------------------------------------------+
   void DrawCompactPerformance(int x, int y, int w, int h) {
      CreateRect("PERF_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("PERF_TITLE", "PERFORMANCE", x + 8, y + 4, CLR_NEON_YELLOW, 8, "Consolas Bold");

      int row = 0;
      int rowH = 18;
      int startY = y + 24;
      int valX = x + 90;

      // Trades
      CreateLabel("PERF_TR_L", "Trades:", x + 8, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("PERF_TR_V", IntegerToString(m_perfStats.executedTrades), valX, startY + row * rowH, CLR_TEXT_BRIGHT, 7, "Consolas Bold");
      row++;

      // Win Rate
      color wrColor = m_perfStats.winRate >= 55 ? CLR_NEON_GREEN : (m_perfStats.winRate >= 45 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_WR_L", "Win Rate:", x + 8, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("PERF_WR_V", DoubleToString(m_perfStats.winRate, 1) + "%", valX, startY + row * rowH, wrColor, 7, "Consolas Bold");
      row++;

      // P&L
      color plColor = m_perfStats.totalPL >= 0 ? CLR_NEON_GREEN : CLR_NEON_RED;
      string plStr = (m_perfStats.totalPL >= 0 ? "+" : "") + DoubleToString(m_perfStats.totalPL, 2);
      CreateLabel("PERF_PL_L", "Total P&L:", x + 8, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("PERF_PL_V", "$" + plStr, valX, startY + row * rowH, plColor, 7, "Consolas Bold");
      row++;

      // PF
      color pfColor = m_perfStats.profitFactor >= 1.5 ? CLR_NEON_GREEN : (m_perfStats.profitFactor >= 1.0 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_PF_L", "PF:", x + 8, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("PERF_PF_V", DoubleToString(m_perfStats.profitFactor, 2), valX, startY + row * rowH, pfColor, 7, "Consolas Bold");
      row++;

      // Sharpe
      color srColor = m_perfStats.sharpeRatio >= 1.5 ? CLR_NEON_GREEN : (m_perfStats.sharpeRatio >= 0.5 ? CLR_NEON_YELLOW : CLR_NEON_RED);
      CreateLabel("PERF_SR_L", "Sharpe:", x + 8, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("PERF_SR_V", DoubleToString(m_perfStats.sharpeRatio, 2), valX, startY + row * rowH, srColor, 7, "Consolas Bold");
      row++;

      // Max DD
      color ddColor = m_perfStats.maxDrawdown < 100 ? CLR_NEON_GREEN : CLR_NEON_YELLOW;
      CreateLabel("PERF_DD_L", "Max DD:", x + 8, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("PERF_DD_V", "$" + DoubleToString(m_perfStats.maxDrawdown, 0), valX, startY + row * rowH, ddColor, 7, "Consolas Bold");
      row++;

      // Expectancy
      color exColor = m_perfStats.expectancy > 0 ? CLR_NEON_GREEN : CLR_NEON_RED;
      CreateLabel("PERF_EX_L", "Expect:", x + 8, startY + row * rowH, CLR_TEXT_DIM, 7);
      CreateLabel("PERF_EX_V", "$" + DoubleToString(m_perfStats.expectancy, 2), valX, startY + row * rowH, exColor, 7, "Consolas Bold");

      // Equity Curve mini
      DrawMiniEquityCurve(x + 2, y + h - 70, w - 4, 65);
   }

   //+------------------------------------------------------------------+
   //| Draw Compact Signal Log                                           |
   //+------------------------------------------------------------------+
   void DrawCompactSignalLog(int x, int y, int w, int h) {
      CreateRect("LOG_BG", x, y, w, h, CLR_BG_MAIN, CLR_BORDER_ACCENT);
      CreateLabel("LOG_TITLE", "SIGNAL LOG", x + 8, y + 4, CLR_NEON_MAGENTA, 8, "Consolas Bold");
      CreateLabel("LOG_COUNT", IntegerToString(m_historyCount), x + w - 25, y + 5, CLR_TEXT_DIM, 7);

      int rowY = y + 22;
      int rowH = 16;
      int displayCount = MathMin(10, m_historyCount);

      for(int i = 0; i < displayCount; i++) {
         int idx = m_historyCount - 1 - i;
         if(idx < 0) break;

         string rowPrefix = "LOG_R" + IntegerToString(i);

         // Time
         string timeStr = TimeToString(m_signalHistory[idx].time, TIME_MINUTES);
         CreateLabel(rowPrefix + "_T", timeStr, x + 5, rowY + i * rowH, CLR_TEXT_DIM, 6);

         // Pair (short)
         string shortPair = m_signalHistory[idx].pairName;
         if(StringLen(shortPair) > 12) shortPair = StringSubstr(shortPair, 0, 11) + "..";
         CreateLabel(rowPrefix + "_P", shortPair, x + 45, rowY + i * rowH, CLR_TEXT_BRIGHT, 6);

         // Signal indicator
         color sigColor = CLR_TEXT_DIM;
         string sigIcon = "○";
         if(m_signalHistory[idx].signal == 2) { sigIcon = "▲"; sigColor = CLR_NEON_GREEN; }
         else if(m_signalHistory[idx].signal == 1) { sigIcon = "△"; sigColor = CLR_NEON_CYAN; }
         else if(m_signalHistory[idx].signal == -1) { sigIcon = "▽"; sigColor = CLR_NEON_ORANGE; }
         else if(m_signalHistory[idx].signal == -2) { sigIcon = "▼"; sigColor = CLR_NEON_RED; }
         CreateLabel(rowPrefix + "_S", sigIcon, x + w - 25, rowY + i * rowH, sigColor, 8);

         // Executed
         string execIcon = m_signalHistory[idx].executed ? "✓" : "";
         CreateLabel(rowPrefix + "_E", execIcon, x + w - 12, rowY + i * rowH, CLR_NEON_GREEN, 7);
      }
   }

   //+------------------------------------------------------------------+
   //| Update Info Display                                               |
   //+------------------------------------------------------------------+
   void UpdateInfo(double unrealizedPL, int positions, double drawdown, double activeBeta) {
      color plColor = unrealizedPL >= 0 ? CLR_NEON_GREEN : CLR_NEON_RED;
      string plText = (unrealizedPL >= 0 ? "+" : "") + DoubleToString(unrealizedPL, 2);

      ObjectSetString(0, m_prefix + "POS_COUNT_VAL", OBJPROP_TEXT, IntegerToString(positions));
      ObjectSetString(0, m_prefix + "POS_PL_VAL", OBJPROP_TEXT, "$" + plText);
      ObjectSetInteger(0, m_prefix + "POS_PL_VAL", OBJPROP_COLOR, plColor);
      ObjectSetString(0, m_prefix + "CTRL_DD_VAL", OBJPROP_TEXT, DoubleToString(drawdown, 2) + "%");
   }

   //+------------------------------------------------------------------+
   //| Handle Click Events                                               |
   //+------------------------------------------------------------------+
   int HandleClick(string sparam, string &symbolA, string &symbolB, double &beta) {
      if(sparam == m_prefix + "BTN_MIN") {
         m_isMinimized = !m_isMinimized;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Draw();
         return -1;
      }

      if(sparam == m_prefix + "BTN_SCAN") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         return 1;
      }

      if(sparam == m_prefix + "BTN_EXEC") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(m_selectedRow >= 0 && m_selectedRow < m_resultCount) {
            symbolA = m_scanResults[m_selectedRow].symbolA;
            symbolB = m_scanResults[m_selectedRow].symbolB;
            beta = m_scanResults[m_selectedRow].beta;
            return 2;
         }
         return 0;
      }

      if(sparam == m_prefix + "BTN_CLOSE") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         return 3;
      }

      // Row selection
      for(int i = 0; i < SCANNER_MAX_ROWS; i++) {
         if(StringFind(sparam, m_prefix + "ROW_" + IntegerToString(i)) == 0) {
            m_selectedRow = i + m_scrollOffset;
            if(m_selectedRow < m_resultCount) {
               symbolA = m_scanResults[m_selectedRow].symbolA;
               symbolB = m_scanResults[m_selectedRow].symbolB;
               beta = m_scanResults[m_selectedRow].beta;
               Draw();
               return 4;
            }
            return 0;
         }
      }

      return 0;
   }

   void ToggleVisibility() {
      m_isVisible = !m_isVisible;
      if(!m_isVisible) ObjectsDeleteAll(0, m_prefix);
      else { m_isMinimized = false; Draw(); }
   }

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
   double GetSignalStrength() { return m_signalStrength; }
   ENUM_REGIME GetCurrentRegime() { return m_currentRegime; }

   //+------------------------------------------------------------------+
   //| Public: Record Signal for History                                 |
   //+------------------------------------------------------------------+
   void RecordSignal(string pairName, int signal, double zScore, double strength) {
      if(signal != 0) {
         AddSignalToHistory(pairName, signal, zScore, strength);
         m_perfStats.totalSignals++;
      }
   }

   //+------------------------------------------------------------------+
   //| Public: Record Trade Result                                       |
   //+------------------------------------------------------------------+
   void RecordTradeResult(double pnl) {
      bool isWin = (pnl > 0);
      UpdatePerformanceStats(pnl, isWin);

      // Mark last non-executed signal as executed
      for(int i = m_historyCount - 1; i >= 0; i--) {
         if(!m_signalHistory[i].executed) {
            m_signalHistory[i].executed = true;
            m_signalHistory[i].entryPL = pnl;
            break;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Public: Get Performance Stats                                     |
   //+------------------------------------------------------------------+
   void GetPerformanceStats(int &trades, double &winRate, double &pnl, double &sharpe) {
      trades = m_perfStats.executedTrades;
      winRate = m_perfStats.winRate;
      pnl = m_perfStats.totalPL;
      sharpe = m_perfStats.sharpeRatio;
   }

   //+------------------------------------------------------------------+
   //| Public: Configure Alerts                                          |
   //+------------------------------------------------------------------+
   void ConfigureAlerts(bool enabled, double zThreshold = 2.0, double strengthThreshold = 60) {
      m_alertsEnabled = enabled;
      m_alertThresholdZ = zThreshold;
      m_alertThresholdStrength = strengthThreshold;
   }

   //+------------------------------------------------------------------+
   //| Public: Process Alerts for all results                            |
   //+------------------------------------------------------------------+
   void ProcessAlerts() {
      if(!m_alertsEnabled) return;

      for(int i = 0; i < m_resultCount; i++) {
         if(CheckAlerts(m_scanResults[i])) {
            break;  // Only one alert per cycle
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Public: Get Top Pairs for analysis                                |
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
   //| Public: Reset Performance Stats                                   |
   //+------------------------------------------------------------------+
   void ResetStats() {
      ZeroMemory(m_perfStats);
      m_perfStats.profitFactor = 1.0;
      m_historyCount = 0;
      m_equitySize = 0;
      ArrayResize(m_equityCurve, 0);
   }

   //+------------------------------------------------------------------+
   //| Public: Get Signal History Count                                  |
   //+------------------------------------------------------------------+
   int GetSignalHistoryCount() { return m_historyCount; }

   //+------------------------------------------------------------------+
   //| Public: Check if alerts are enabled                               |
   //+------------------------------------------------------------------+
   bool AreAlertsEnabled() { return m_alertsEnabled; }
};

//+------------------------------------------------------------------+
