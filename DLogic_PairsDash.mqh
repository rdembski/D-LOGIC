//+------------------------------------------------------------------+
//|                                            DLogic_PairsDash.mqh |
//|                          Project: D-LOGIC Pairs Trading Scanner |
//|                                        Author: RafaB Dembski    |
//|                   Professional Dashboard - Alpha Trader Style   |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"
#property strict

#include "DLogic_PairsCore.mqh"

// ============================================================
// COLOR SCHEME - Professional Dark Theme
// ============================================================
#define CLR_BG_MAIN        C'15,15,20'
#define CLR_BG_HEADER      C'30,35,45'
#define CLR_BG_ROW1        C'22,22,30'
#define CLR_BG_ROW2        C'28,28,38'
#define CLR_BG_SIGNAL      C'20,60,20'
#define CLR_BG_SELECTED    C'40,50,70'
#define CLR_BORDER         C'50,55,65'
#define CLR_TEXT           C'220,220,225'
#define CLR_TEXT_DIM       C'130,130,145'
#define CLR_HEADER         C'0,200,255'
#define CLR_POSITIVE       C'0,230,118'
#define CLR_NEGATIVE       C'255,82,82'
#define CLR_WARNING        C'255,193,7'
#define CLR_CYAN           C'0,229,255'
#define CLR_MAGENTA        C'255,0,255'
#define CLR_PURPLE         C'180,100,255'

// ============================================================
// LAYOUT CONSTANTS
// ============================================================
#define DASH_TITLE_H       24
#define DASH_HEADER_H      20
#define DASH_ROW_H         18
#define DASH_FOOTER_H      22

#define COL_PAIR           145
#define COL_TF             35
#define COL_SPEARMAN       70
#define COL_ZSCORE         60
#define COL_TYPE           35
#define COL_SIGNAL         130

//+------------------------------------------------------------------+
//| Pairs Trading Dashboard Class                                     |
//+------------------------------------------------------------------+
class C_PairsDashboard {
private:
   string         m_prefix;
   int            m_startX;
   int            m_startY;
   int            m_maxRows;
   int            m_visibleRows;

   PairResult     m_results[];
   int            m_resultCount;
   int            m_selectedRow;
   string         m_version;

   // Symbol buttons for filtering
   string         m_symbolButtons[];
   int            m_symbolButtonCount;
   string         m_selectedSymbol;

   //+------------------------------------------------------------------+
   //| Create Rectangle                                                  |
   //+------------------------------------------------------------------+
   void CreateRect(string name, int x, int y, int w, int h, color bg, color border = clrNONE) {
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
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, (border == clrNONE) ? CLR_BORDER : border);
   }

   //+------------------------------------------------------------------+
   //| Create Label                                                      |
   //+------------------------------------------------------------------+
   void CreateLabel(string name, string text, int x, int y, color clr, int size = 8, string font = "Consolas") {
      if(ObjectFind(0, name) < 0) {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }

   //+------------------------------------------------------------------+
   //| Create Button                                                     |
   //+------------------------------------------------------------------+
   void CreateButton(string name, string text, int x, int y, int w, int h,
                     color bg, color textClr, int fontSize = 7) {
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
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, CLR_BORDER);
   }

   //+------------------------------------------------------------------+
   //| Get total width                                                   |
   //+------------------------------------------------------------------+
   int GetTotalWidth() {
      return COL_PAIR + COL_TF + COL_SPEARMAN + COL_ZSCORE + COL_TYPE + COL_SIGNAL + 12;
   }

   //+------------------------------------------------------------------+
   //| Get color for correlation value                                   |
   //+------------------------------------------------------------------+
   color GetCorrColor(double corr) {
      double absCorr = MathAbs(corr);
      if(absCorr >= 0.90) return CLR_POSITIVE;
      if(absCorr >= 0.80) return CLR_CYAN;
      if(absCorr >= 0.70) return CLR_WARNING;
      return CLR_TEXT_DIM;
   }

   //+------------------------------------------------------------------+
   //| Get color for Z-Score value                                       |
   //+------------------------------------------------------------------+
   color GetZScoreColor(double zscore) {
      double absZ = MathAbs(zscore);
      if(absZ >= 2.5) return CLR_NEGATIVE;
      if(absZ >= 2.0) return CLR_WARNING;
      if(absZ >= 1.5) return CLR_CYAN;
      return CLR_TEXT_DIM;
   }

   //+------------------------------------------------------------------+
   //| Get color for signal                                              |
   //+------------------------------------------------------------------+
   color GetSignalColor(int signal, string signalText) {
      if(signal != 0) return CLR_POSITIVE;
      return CLR_TEXT_DIM;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   C_PairsDashboard() {
      m_prefix = "DL_PAIRS_";
      m_startX = 10;
      m_startY = 20;
      m_maxRows = 25;
      m_visibleRows = 0;
      m_resultCount = 0;
      m_selectedRow = -1;
      m_version = "1.00";
      m_selectedSymbol = "";
      m_symbolButtonCount = 0;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~C_PairsDashboard() {
      ObjectsDeleteAll(0, m_prefix);
   }

   //+------------------------------------------------------------------+
   //| Set position                                                      |
   //+------------------------------------------------------------------+
   void SetPosition(int x, int y) {
      m_startX = x;
      m_startY = y;
   }

   //+------------------------------------------------------------------+
   //| Draw Title Bar                                                    |
   //+------------------------------------------------------------------+
   void DrawTitle() {
      int x = m_startX;
      int y = m_startY;
      int w = GetTotalWidth();

      // Title background
      CreateRect(m_prefix + "TITLE_BG", x, y, w, DASH_TITLE_H, C'0,80,150', CLR_CYAN);

      // Title text
      string title = "Pairs Trading Dashboard - D-LOGIC " + m_version;
      CreateLabel(m_prefix + "TITLE", title, x + 8, y + 5, CLR_TEXT, 9, "Consolas Bold");

      // SCAN button
      CreateButton(m_prefix + "BTN_SCAN", "SCAN", x + w - 50, y + 3, 45, 18, C'0,120,80', clrWhite, 8);
   }

   //+------------------------------------------------------------------+
   //| Draw Column Headers                                               |
   //+------------------------------------------------------------------+
   void DrawHeaders() {
      int x = m_startX;
      int y = m_startY + DASH_TITLE_H;
      int w = GetTotalWidth();

      // Header background
      CreateRect(m_prefix + "HDR_BG", x, y, w, DASH_HEADER_H, CLR_BG_HEADER);

      int colX = x + 5;

      // Column headers
      CreateLabel(m_prefix + "H_PAIR", "Pair", colX, y + 4, CLR_HEADER, 8, "Consolas Bold");
      colX += COL_PAIR;

      CreateLabel(m_prefix + "H_TF", "TF", colX, y + 4, CLR_HEADER, 8, "Consolas Bold");
      colX += COL_TF;

      CreateLabel(m_prefix + "H_SPEAR", "Spearman", colX, y + 4, CLR_HEADER, 8, "Consolas Bold");
      colX += COL_SPEARMAN;

      CreateLabel(m_prefix + "H_ZSCORE", "Z-Score", colX, y + 4, CLR_HEADER, 8, "Consolas Bold");
      colX += COL_ZSCORE;

      CreateLabel(m_prefix + "H_TYPE", "Type", colX, y + 4, CLR_HEADER, 8, "Consolas Bold");
      colX += COL_TYPE;

      CreateLabel(m_prefix + "H_SIGNAL", "Signal", colX, y + 4, CLR_HEADER, 8, "Consolas Bold");
   }

   //+------------------------------------------------------------------+
   //| Draw Single Row                                                   |
   //+------------------------------------------------------------------+
   void DrawRow(int rowIndex, PairResult &result) {
      int x = m_startX;
      int y = m_startY + DASH_TITLE_H + DASH_HEADER_H + (rowIndex * DASH_ROW_H);
      int w = GetTotalWidth();
      string rowId = IntegerToString(rowIndex);

      // Row background color
      color bgColor;
      if(rowIndex == m_selectedRow) {
         bgColor = CLR_BG_SELECTED;
      } else if(result.signal != 0) {
         bgColor = CLR_BG_SIGNAL;
      } else {
         bgColor = (rowIndex % 2 == 0) ? CLR_BG_ROW1 : CLR_BG_ROW2;
      }

      // Clickable row button
      CreateButton(m_prefix + "ROW_" + rowId, "", x, y, w, DASH_ROW_H, bgColor, clrNONE, 1);

      int colX = x + 5;
      int textY = y + 3;

      // Pair name with timeframe suffix (e.g., GBPUSD-EURUSD|240)
      string pairDisplay = result.pairName + "|" + result.tfName;
      color pairColor = (result.signal != 0) ? CLR_POSITIVE : CLR_TEXT;
      CreateLabel(m_prefix + "PAIR_" + rowId, pairDisplay, colX, textY, pairColor, 7);
      colX += COL_PAIR;

      // Timeframe
      CreateLabel(m_prefix + "TF_" + rowId, result.tfName, colX, textY, CLR_TEXT_DIM, 7);
      colX += COL_TF;

      // Spearman correlation
      string spearStr = DoubleToString(result.spearman, 2);
      color spearColor = GetCorrColor(result.spearman);
      CreateLabel(m_prefix + "SPEAR_" + rowId, spearStr, colX, textY, spearColor, 7);
      colX += COL_SPEARMAN;

      // Z-Score
      string zStr = DoubleToString(result.zscore, 2);
      color zColor = GetZScoreColor(result.zscore);
      CreateLabel(m_prefix + "Z_" + rowId, zStr, colX, textY, zColor, 7);
      colX += COL_ZSCORE;

      // Type (Pos/Neg)
      color typeColor = (result.corrType == "Pos") ? CLR_CYAN : CLR_MAGENTA;
      CreateLabel(m_prefix + "TYPE_" + rowId, result.corrType, colX, textY, typeColor, 7);
      colX += COL_TYPE;

      // Signal
      color sigColor = GetSignalColor(result.signal, result.signalText);
      string sigDisplay = result.signalText;
      if(StringLen(sigDisplay) > 20) sigDisplay = StringSubstr(sigDisplay, 0, 20);
      CreateLabel(m_prefix + "SIG_" + rowId, sigDisplay, colX, textY, sigColor, 7);
   }

   //+------------------------------------------------------------------+
   //| Draw Symbol Filter Buttons                                        |
   //+------------------------------------------------------------------+
   void DrawSymbolButtons(string &symbols[], int count) {
      int x = m_startX + GetTotalWidth() + 10;
      int y = m_startY + DASH_TITLE_H;

      // Background for symbol panel
      int panelH = MathMin(count, 8) * 22 + 30;
      CreateRect(m_prefix + "SYM_BG", x, y, 85, panelH, CLR_BG_MAIN);
      CreateLabel(m_prefix + "SYM_TITLE", "Symbols", x + 5, y + 5, CLR_HEADER, 8);

      // Symbol buttons
      m_symbolButtonCount = MathMin(count, 8);
      ArrayResize(m_symbolButtons, m_symbolButtonCount);

      for(int i = 0; i < m_symbolButtonCount; i++) {
         string symName = symbols[i];
         // Shorten symbol name for display
         if(StringLen(symName) > 6) symName = StringSubstr(symName, 0, 6);

         string btnName = m_prefix + "SYM_" + IntegerToString(i);
         m_symbolButtons[i] = symbols[i];

         color btnBg = (symbols[i] == m_selectedSymbol) ? C'0,100,150' : C'40,45,55';
         CreateButton(btnName, symName, x + 5, y + 25 + (i * 22), 75, 20, btnBg, CLR_TEXT, 7);
      }
   }

   //+------------------------------------------------------------------+
   //| Draw Footer with Statistics                                       |
   //+------------------------------------------------------------------+
   void DrawFooter() {
      int x = m_startX;
      int y = m_startY + DASH_TITLE_H + DASH_HEADER_H + (m_visibleRows * DASH_ROW_H);
      int w = GetTotalWidth();

      // Footer background
      CreateRect(m_prefix + "FOOTER_BG", x, y, w, DASH_FOOTER_H, C'25,28,38');

      // Count statistics
      int signalCount = 0;
      int posCount = 0;
      int negCount = 0;

      for(int i = 0; i < m_resultCount; i++) {
         if(m_results[i].signal != 0) signalCount++;
         if(m_results[i].corrType == "Pos") posCount++;
         else negCount++;
      }

      string stats = "Pairs: " + IntegerToString(m_resultCount) +
                    " | Signals: " + IntegerToString(signalCount) +
                    " | Pos: " + IntegerToString(posCount) +
                    " | Neg: " + IntegerToString(negCount);

      CreateLabel(m_prefix + "STATS", stats, x + 5, y + 5, CLR_TEXT_DIM, 7);

      // Timestamp
      string timeStr = TimeToString(TimeCurrent(), TIME_SECONDS);
      CreateLabel(m_prefix + "TIME", timeStr, x + w - 70, y + 5, CLR_TEXT_DIM, 7);
   }

   //+------------------------------------------------------------------+
   //| Clear old rows                                                    |
   //+------------------------------------------------------------------+
   void ClearRows(int fromRow) {
      for(int i = fromRow; i < m_maxRows; i++) {
         string rowId = IntegerToString(i);
         ObjectDelete(0, m_prefix + "ROW_" + rowId);
         ObjectDelete(0, m_prefix + "PAIR_" + rowId);
         ObjectDelete(0, m_prefix + "TF_" + rowId);
         ObjectDelete(0, m_prefix + "SPEAR_" + rowId);
         ObjectDelete(0, m_prefix + "Z_" + rowId);
         ObjectDelete(0, m_prefix + "TYPE_" + rowId);
         ObjectDelete(0, m_prefix + "SIG_" + rowId);
      }
   }

   //+------------------------------------------------------------------+
   //| Update Dashboard with Results                                     |
   //+------------------------------------------------------------------+
   void UpdateResults(PairResult &results[], int count) {
      // Store results
      m_resultCount = count;
      ArrayResize(m_results, count);

      for(int i = 0; i < count; i++) {
         m_results[i] = results[i];
      }

      // Calculate visible rows
      m_visibleRows = MathMin(count, m_maxRows);

      // Clear old rows
      ClearRows(m_visibleRows);

      // Draw components
      DrawTitle();
      DrawHeaders();

      // Draw rows
      for(int i = 0; i < m_visibleRows; i++) {
         DrawRow(i, m_results[i]);
      }

      // Draw footer
      DrawFooter();

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Sort by Correlation (descending absolute value)                   |
   //+------------------------------------------------------------------+
   void SortByCorrelation(PairResult &results[], int count) {
      for(int i = 0; i < count - 1; i++) {
         for(int j = i + 1; j < count; j++) {
            if(MathAbs(results[j].spearman) > MathAbs(results[i].spearman)) {
               PairResult temp = results[i];
               results[i] = results[j];
               results[j] = temp;
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Sort by Z-Score (extreme values first)                            |
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
   //| Sort by Signal (active signals first)                             |
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

   //+------------------------------------------------------------------+
   //| Handle Click Event                                                |
   //+------------------------------------------------------------------+
   int HandleClick(string sparam, string &pair1, string &pair2, ENUM_TIMEFRAMES &tf) {
      pair1 = "";
      pair2 = "";
      tf = PERIOD_CURRENT;

      // Check SCAN button
      if(sparam == m_prefix + "BTN_SCAN") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         return 1;  // Signal to rescan
      }

      // Check row clicks
      if(StringFind(sparam, m_prefix + "ROW_") >= 0) {
         string rowStr = StringSubstr(sparam, StringLen(m_prefix + "ROW_"));
         int rowIndex = (int)StringToInteger(rowStr);

         if(rowIndex >= 0 && rowIndex < m_resultCount) {
            m_selectedRow = rowIndex;
            pair1 = m_results[rowIndex].pair1;
            pair2 = m_results[rowIndex].pair2;
            tf = m_results[rowIndex].timeframe;

            // Redraw to show selection
            for(int i = 0; i < m_visibleRows; i++) {
               DrawRow(i, m_results[i]);
            }
            ChartRedraw(0);

            return 2;  // Signal to open charts
         }
      }

      // Check symbol filter buttons
      if(StringFind(sparam, m_prefix + "SYM_") >= 0) {
         string symIdxStr = StringSubstr(sparam, StringLen(m_prefix + "SYM_"));
         int symIdx = (int)StringToInteger(symIdxStr);

         if(symIdx >= 0 && symIdx < m_symbolButtonCount) {
            if(m_selectedSymbol == m_symbolButtons[symIdx]) {
               m_selectedSymbol = "";  // Deselect
            } else {
               m_selectedSymbol = m_symbolButtons[symIdx];
            }
            return 3;  // Signal to filter
         }
      }

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Get selected symbol for filtering                                 |
   //+------------------------------------------------------------------+
   string GetSelectedSymbol() {
      return m_selectedSymbol;
   }

   //+------------------------------------------------------------------+
   //| Check if scan button was clicked                                  |
   //+------------------------------------------------------------------+
   bool IsScanClicked(string sparam) {
      return (sparam == m_prefix + "BTN_SCAN");
   }

   //+------------------------------------------------------------------+
   //| Generate Alert Message                                            |
   //+------------------------------------------------------------------+
   string GenerateAlertMessage(PairResult &result) {
      return "Signal " + result.signalText + " (" +
             result.corrType + " - " + result.tfName + "): " +
             result.pair1 + " @ " + DoubleToString(result.price1, 5) + ", " +
             result.pair2 + " @ " + DoubleToString(result.price2, 5) + ", " +
             "Spearman = " + DoubleToString(result.spearman, 4) + ", " +
             "Z-Score = " + DoubleToString(result.zscore, 2) + ", " +
             (result.isStationary ? "Stationary" : "Non-Stationary");
   }
};
