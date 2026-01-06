//+------------------------------------------------------------------+
//|                                            DLogic_PairsDash.mqh |
//|                          Project: D-LOGIC Pairs Trading Scanner |
//|                                        Author: RafaB Dembski    |
//|                     Dashboard: Visual Interface for Pairs Data  |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"
#property strict

#include "DLogic_PairsCore.mqh"

// --- COLOR SCHEME ---
#define CLR_BG_DARK        C'18,18,22'
#define CLR_BG_ROW1        C'25,25,30'
#define CLR_BG_ROW2        C'30,30,38'
#define CLR_BG_HEADER      C'40,45,55'
#define CLR_BG_HIGHLIGHT   C'50,55,70'
#define CLR_TEXT           C'220,220,225'
#define CLR_TEXT_DIM       C'140,140,150'
#define CLR_UP             C'0,230,118'
#define CLR_DN             C'255,82,82'
#define CLR_WARN           C'255,193,7'
#define CLR_ACCENT         C'100,181,246'
#define CLR_PURPLE         C'186,104,200'
#define CLR_CYAN           C'0,229,255'
#define CLR_NEUT           C'100,100,110'

// --- LAYOUT CONSTANTS ---
#define ROW_HEIGHT         18
#define HEADER_HEIGHT      22
#define COL_PAIR1          80
#define COL_PAIR2          80
#define COL_CORR           60
#define COL_ZSCORE         65
#define COL_SPREAD         70
#define COL_STAT           50
#define COL_HALFLIFE       55
#define COL_RSI            50
#define COL_SIGNAL         110

//+------------------------------------------------------------------+
//| Pairs Trading Dashboard                                           |
//+------------------------------------------------------------------+
class C_PairsDashboard {
private:
   string         m_prefix;
   int            m_startX;
   int            m_startY;
   int            m_maxRows;
   int            m_currentRows;

   PairResult     m_results[];
   string         m_selectedPair1;
   string         m_selectedPair2;

   // --- Drawing Helpers ---
   void CreateRect(string name, int x, int y, int w, int h, color bg) {
      if(ObjectFind(0, name) < 0) {
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'45,45,55');
   }

   void CreateLabel(string name, string text, int x, int y, color clr, int size=8, bool bold=false) {
      if(ObjectFind(0, name) < 0) {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
      ObjectSetString(0, name, OBJPROP_FONT, bold ? "Consolas Bold" : "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }

   void CreateButton(string name, string text, int x, int y, int w, int h, color bg, color textClr) {
      if(ObjectFind(0, name) < 0) {
         ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      }
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textClr);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'60,60,70');
   }

   // --- Color Helpers ---
   color GetCorrColor(double corr) {
      double absCorr = MathAbs(corr);
      if(absCorr >= 0.9) return CLR_UP;
      if(absCorr >= 0.8) return CLR_ACCENT;
      if(absCorr >= 0.7) return CLR_WARN;
      return CLR_NEUT;
   }

   color GetZScoreColor(double zscore) {
      double absZ = MathAbs(zscore);
      if(absZ >= 2.5) return CLR_DN;
      if(absZ >= 2.0) return CLR_WARN;
      if(absZ >= 1.5) return CLR_ACCENT;
      return CLR_TEXT_DIM;
   }

   color GetStatColor(bool isStationary) {
      return isStationary ? CLR_UP : CLR_DN;
   }

   color GetSignalColor(int signal) {
      if(signal > 0) return CLR_UP;
      if(signal < 0) return CLR_DN;
      return CLR_NEUT;
   }

   color GetRSIColor(double rsi) {
      if(rsi > 70) return CLR_DN;
      if(rsi < 30) return CLR_UP;
      return CLR_TEXT_DIM;
   }

   // --- Calculate total width ---
   int GetTotalWidth() {
      return COL_PAIR1 + COL_PAIR2 + COL_CORR + COL_ZSCORE + COL_SPREAD +
             COL_STAT + COL_HALFLIFE + COL_RSI + COL_SIGNAL + 10;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   C_PairsDashboard() {
      m_prefix = "DL_PAIRS_";
      m_startX = 10;
      m_startY = 30;
      m_maxRows = 20;
      m_currentRows = 0;
      m_selectedPair1 = "";
      m_selectedPair2 = "";
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~C_PairsDashboard() {
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
   //| Draw Header                                                       |
   //+------------------------------------------------------------------+
   void DrawHeader() {
      int x = m_startX;
      int y = m_startY;
      int totalW = GetTotalWidth();

      // Title bar
      CreateRect(m_prefix + "TITLE_BG", x, y - 25, totalW, 22, C'30,90,150');
      CreateLabel(m_prefix + "TITLE", "D-LOGIC PAIRS TRADING SCANNER", x + 5, y - 23, CLR_TEXT, 9, true);

      // Scan button
      CreateButton(m_prefix + "BTN_SCAN", "SCAN", x + totalW - 55, y - 24, 50, 18, C'0,120,180', clrWhite);

      // Header row
      CreateRect(m_prefix + "HDR_BG", x, y, totalW, HEADER_HEIGHT, CLR_BG_HEADER);

      int colX = x + 5;

      CreateLabel(m_prefix + "H_P1", "PAIR 1", colX, y + 4, CLR_CYAN, 7, true);
      colX += COL_PAIR1;

      CreateLabel(m_prefix + "H_P2", "PAIR 2", colX, y + 4, CLR_CYAN, 7, true);
      colX += COL_PAIR2;

      CreateLabel(m_prefix + "H_CORR", "CORR", colX, y + 4, CLR_CYAN, 7, true);
      colX += COL_CORR;

      CreateLabel(m_prefix + "H_Z", "Z-SCORE", colX, y + 4, CLR_CYAN, 7, true);
      colX += COL_ZSCORE;

      CreateLabel(m_prefix + "H_SPR", "SPREAD", colX, y + 4, CLR_CYAN, 7, true);
      colX += COL_SPREAD;

      CreateLabel(m_prefix + "H_STAT", "STAT", colX, y + 4, CLR_CYAN, 7, true);
      colX += COL_STAT;

      CreateLabel(m_prefix + "H_HL", "H-LIFE", colX, y + 4, CLR_CYAN, 7, true);
      colX += COL_HALFLIFE;

      CreateLabel(m_prefix + "H_RSI", "RSI", colX, y + 4, CLR_CYAN, 7, true);
      colX += COL_RSI;

      CreateLabel(m_prefix + "H_SIG", "SIGNAL", colX, y + 4, CLR_CYAN, 7, true);
   }

   //+------------------------------------------------------------------+
   //| Draw Single Row                                                   |
   //+------------------------------------------------------------------+
   void DrawRow(int rowIndex, PairResult &result) {
      int x = m_startX;
      int y = m_startY + HEADER_HEIGHT + (rowIndex * ROW_HEIGHT);
      int totalW = GetTotalWidth();
      string rowId = IntegerToString(rowIndex);

      // Row background (alternating)
      color bgColor = (rowIndex % 2 == 0) ? CLR_BG_ROW1 : CLR_BG_ROW2;

      // Highlight if selected
      if(result.symbol1 == m_selectedPair1 && result.symbol2 == m_selectedPair2) {
         bgColor = CLR_BG_HIGHLIGHT;
      }

      // Row button (clickable area)
      CreateButton(m_prefix + "ROW_" + rowId, "", x, y, totalW, ROW_HEIGHT, bgColor, clrNONE);

      int colX = x + 5;
      int textY = y + 3;

      // Pair 1
      CreateLabel(m_prefix + "P1_" + rowId, result.symbol1, colX, textY, CLR_TEXT, 7);
      colX += COL_PAIR1;

      // Pair 2
      CreateLabel(m_prefix + "P2_" + rowId, result.symbol2, colX, textY, CLR_TEXT, 7);
      colX += COL_PAIR2;

      // Correlation
      string corrStr = DoubleToString(result.correlation, 3);
      color corrClr = GetCorrColor(result.correlation);
      CreateLabel(m_prefix + "CORR_" + rowId, corrStr, colX, textY, corrClr, 7, true);
      colX += COL_CORR;

      // Z-Score
      string zStr = DoubleToString(result.zscore, 2);
      color zClr = GetZScoreColor(result.zscore);
      CreateLabel(m_prefix + "Z_" + rowId, zStr, colX, textY, zClr, 7, true);
      colX += COL_ZSCORE;

      // Spread
      string sprStr = DoubleToString(result.spread * 100, 2) + "%";
      CreateLabel(m_prefix + "SPR_" + rowId, sprStr, colX, textY, CLR_TEXT_DIM, 7);
      colX += COL_SPREAD;

      // Stationarity
      string statStr = result.isStationary ? "YES" : "NO";
      color statClr = GetStatColor(result.isStationary);
      CreateLabel(m_prefix + "STAT_" + rowId, statStr, colX, textY, statClr, 7, true);
      colX += COL_STAT;

      // Half-Life
      string hlStr = (result.halfLife > 0) ? DoubleToString(result.halfLife, 1) : "-";
      color hlClr = (result.halfLife > 0 && result.halfLife < 20) ? CLR_UP : CLR_TEXT_DIM;
      CreateLabel(m_prefix + "HL_" + rowId, hlStr, colX, textY, hlClr, 7);
      colX += COL_HALFLIFE;

      // RSI (show pair1's RSI)
      string rsiStr = DoubleToString(result.rsi1, 0);
      color rsiClr = GetRSIColor(result.rsi1);
      CreateLabel(m_prefix + "RSI_" + rowId, rsiStr, colX, textY, rsiClr, 7);
      colX += COL_RSI;

      // Signal
      color sigClr = GetSignalColor(result.signal);
      CreateLabel(m_prefix + "SIG_" + rowId, result.signalText, colX, textY, sigClr, 7, true);
   }

   //+------------------------------------------------------------------+
   //| Update Dashboard with Results                                     |
   //+------------------------------------------------------------------+
   void UpdateResults(PairResult &results[], int count) {
      // Store results
      ArrayResize(m_results, count);
      for(int i = 0; i < count; i++) {
         m_results[i] = results[i];
      }
      m_currentRows = count;

      // Clear old rows
      for(int i = count; i < m_maxRows; i++) {
         string rowId = IntegerToString(i);
         ObjectDelete(0, m_prefix + "ROW_" + rowId);
         ObjectDelete(0, m_prefix + "P1_" + rowId);
         ObjectDelete(0, m_prefix + "P2_" + rowId);
         ObjectDelete(0, m_prefix + "CORR_" + rowId);
         ObjectDelete(0, m_prefix + "Z_" + rowId);
         ObjectDelete(0, m_prefix + "SPR_" + rowId);
         ObjectDelete(0, m_prefix + "STAT_" + rowId);
         ObjectDelete(0, m_prefix + "HL_" + rowId);
         ObjectDelete(0, m_prefix + "RSI_" + rowId);
         ObjectDelete(0, m_prefix + "SIG_" + rowId);
      }

      // Draw header
      DrawHeader();

      // Draw rows
      for(int i = 0; i < MathMin(count, m_maxRows); i++) {
         DrawRow(i, results[i]);
      }

      // Draw footer
      DrawFooter(count);

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Draw Footer with Statistics                                       |
   //+------------------------------------------------------------------+
   void DrawFooter(int count) {
      int x = m_startX;
      int y = m_startY + HEADER_HEIGHT + (MathMin(count, m_maxRows) * ROW_HEIGHT) + 5;
      int totalW = GetTotalWidth();

      // Stats background
      CreateRect(m_prefix + "FOOTER_BG", x, y, totalW, 35, C'25,28,35');

      // Count signals
      int buySignals = 0, sellSignals = 0, stationaryCount = 0;
      double avgCorr = 0;

      for(int i = 0; i < ArraySize(m_results); i++) {
         if(m_results[i].signal > 0) buySignals++;
         if(m_results[i].signal < 0) sellSignals++;
         if(m_results[i].isStationary) stationaryCount++;
         avgCorr += MathAbs(m_results[i].correlation);
      }

      if(count > 0) avgCorr /= count;

      // Statistics line 1
      string stats1 = "Pairs: " + IntegerToString(count) +
                     " | Avg |Corr|: " + DoubleToString(avgCorr, 2) +
                     " | Stationary: " + IntegerToString(stationaryCount);
      CreateLabel(m_prefix + "STATS1", stats1, x + 5, y + 5, CLR_TEXT_DIM, 7);

      // Statistics line 2
      string stats2 = "BUY Signals: " + IntegerToString(buySignals) +
                     " | SELL Signals: " + IntegerToString(sellSignals) +
                     " | Last Update: " + TimeToString(TimeCurrent(), TIME_SECONDS);
      CreateLabel(m_prefix + "STATS2", stats2, x + 5, y + 20, CLR_TEXT_DIM, 7);

      // Info label
      CreateLabel(m_prefix + "INFO", "Click row to open chart | Click SCAN to refresh",
                  x + totalW - 250, y + 12, CLR_NEUT, 7);
   }

   //+------------------------------------------------------------------+
   //| Handle Click Event                                                |
   //+------------------------------------------------------------------+
   bool HandleClick(string sparam, string &pair1, string &pair2) {
      // Check if clicked on a row
      if(StringFind(sparam, m_prefix + "ROW_") >= 0) {
         // Extract row index
         string rowStr = StringSubstr(sparam, StringLen(m_prefix + "ROW_"));
         int rowIndex = (int)StringToInteger(rowStr);

         if(rowIndex >= 0 && rowIndex < ArraySize(m_results)) {
            pair1 = m_results[rowIndex].symbol1;
            pair2 = m_results[rowIndex].symbol2;
            m_selectedPair1 = pair1;
            m_selectedPair2 = pair2;

            // Refresh display to show selection
            for(int i = 0; i < m_currentRows; i++) {
               DrawRow(i, m_results[i]);
            }
            ChartRedraw(0);

            return true;
         }
      }

      // Check scan button
      if(sparam == m_prefix + "BTN_SCAN") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         return false; // Signal to rescan
      }

      pair1 = "";
      pair2 = "";
      return false;
   }

   //+------------------------------------------------------------------+
   //| Check if Scan Button Clicked                                      |
   //+------------------------------------------------------------------+
   bool IsScanClicked(string sparam) {
      return (sparam == m_prefix + "BTN_SCAN");
   }

   //+------------------------------------------------------------------+
   //| Get Selected Pair Info                                            |
   //+------------------------------------------------------------------+
   bool GetSelectedPair(string &pair1, string &pair2) {
      if(m_selectedPair1 != "" && m_selectedPair2 != "") {
         pair1 = m_selectedPair1;
         pair2 = m_selectedPair2;
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Sort Results by Correlation                                       |
   //+------------------------------------------------------------------+
   void SortByCorrelation(PairResult &results[], int count, bool descending=true) {
      for(int i = 0; i < count - 1; i++) {
         for(int j = i + 1; j < count; j++) {
            bool swap = descending ?
               (MathAbs(results[j].correlation) > MathAbs(results[i].correlation)) :
               (MathAbs(results[j].correlation) < MathAbs(results[i].correlation));

            if(swap) {
               PairResult temp = results[i];
               results[i] = results[j];
               results[j] = temp;
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Sort Results by Z-Score (extremes first)                          |
   //+------------------------------------------------------------------+
   void SortByZScore(PairResult &results[], int count) {
      for(int i = 0; i < count - 1; i++) {
         for(int j = i + 1; j < count; j++) {
            if(MathAbs(results[j].zscore) > MathAbs(results[i].zscore)) {
               PairResult temp = results[i];
               results[i] = results[j];
               results[j] = temp;
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Sort Results by Signal (active signals first)                     |
   //+------------------------------------------------------------------+
   void SortBySignal(PairResult &results[], int count) {
      for(int i = 0; i < count - 1; i++) {
         for(int j = i + 1; j < count; j++) {
            if(MathAbs(results[j].signal) > MathAbs(results[i].signal)) {
               PairResult temp = results[i];
               results[i] = results[j];
               results[j] = temp;
            }
         }
      }
   }
};
