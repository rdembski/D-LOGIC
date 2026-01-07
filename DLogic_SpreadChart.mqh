//+------------------------------------------------------------------+
//|                                          DLogic_SpreadChart.mqh |
//|                          Project: D-LOGIC Trading Dashboard      |
//|                                        Author: RafaB Dembski    |
//|                    Spread Visualization for Pairs Trading        |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"
#property strict

// ============================================================
// COLOR SCHEME
// ============================================================
#define SPREAD_BG_MAIN     C'15,15,20'
#define SPREAD_BG_HEADER   C'80,0,120'
#define SPREAD_LINE_UP     C'0,230,118'
#define SPREAD_LINE_DOWN   C'255,82,82'
#define SPREAD_LINE_MEAN   C'255,193,7'
#define SPREAD_LINE_STD1   C'0,150,200'
#define SPREAD_LINE_STD2   C'150,100,255'
#define SPREAD_BORDER      C'50,55,65'
#define SPREAD_TEXT        C'220,220,225'
#define SPREAD_TEXT_DIM    C'130,130,145'
#define SPREAD_CYAN        C'0,229,255'

//+------------------------------------------------------------------+
//| Spread Chart Class                                                |
//+------------------------------------------------------------------+
class C_SpreadChart {
private:
   string         m_prefix;
   int            m_startX;
   int            m_startY;
   int            m_width;
   int            m_height;
   bool           m_isVisible;
   bool           m_isMinimized;

   string         m_symbol1;
   string         m_symbol2;
   double         m_hedgeRatio;
   int            m_lookback;

   // Spread data
   double         m_spreadValues[];
   double         m_spreadMean;
   double         m_spreadStd;
   double         m_currentZScore;

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
      ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, (border == clrNONE) ? SPREAD_BORDER : border);
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
      ObjectSetString(0, objName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   }

   //+------------------------------------------------------------------+
   //| Calculate spread values                                           |
   //+------------------------------------------------------------------+
   void CalculateSpread(ENUM_TIMEFRAMES tf) {
      if(m_symbol1 == "" || m_symbol2 == "") return;

      double prices1[], prices2[];
      ArraySetAsSeries(prices1, true);
      ArraySetAsSeries(prices2, true);

      if(CopyClose(m_symbol1, tf, 0, m_lookback, prices1) < m_lookback) return;
      if(CopyClose(m_symbol2, tf, 0, m_lookback, prices2) < m_lookback) return;

      // Calculate hedge ratio using OLS
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for(int i = 0; i < m_lookback; i++) {
         sumX += prices2[i];
         sumY += prices1[i];
         sumXY += prices1[i] * prices2[i];
         sumX2 += prices2[i] * prices2[i];
      }

      double denom = m_lookback * sumX2 - sumX * sumX;
      if(MathAbs(denom) > 1e-10) {
         m_hedgeRatio = (m_lookback * sumXY - sumX * sumY) / denom;
      } else {
         m_hedgeRatio = 1.0;
      }

      // Calculate spread series
      ArrayResize(m_spreadValues, m_lookback);
      double sum = 0;

      for(int i = 0; i < m_lookback; i++) {
         m_spreadValues[i] = prices1[i] - m_hedgeRatio * prices2[i];
         sum += m_spreadValues[i];
      }

      m_spreadMean = sum / m_lookback;

      // Calculate standard deviation
      double sumSq = 0;
      for(int i = 0; i < m_lookback; i++) {
         sumSq += MathPow(m_spreadValues[i] - m_spreadMean, 2);
      }
      m_spreadStd = MathSqrt(sumSq / (m_lookback - 1));

      // Current Z-Score
      if(m_spreadStd > 1e-10) {
         m_currentZScore = (m_spreadValues[0] - m_spreadMean) / m_spreadStd;
      } else {
         m_currentZScore = 0;
      }
   }

   //+------------------------------------------------------------------+
   //| Draw spread line chart                                            |
   //+------------------------------------------------------------------+
   void DrawSpreadLine() {
      int chartX = m_startX + 5;
      int chartY = m_startY + 50;
      int chartW = m_width - 10;
      int chartH = m_height - 100;

      // Chart background
      CreateRect("CHART_BG", chartX, chartY, chartW, chartH, C'20,22,28');

      // Find min/max for scaling
      double minVal = m_spreadMean - 3 * m_spreadStd;
      double maxVal = m_spreadMean + 3 * m_spreadStd;

      for(int i = 0; i < m_lookback; i++) {
         if(m_spreadValues[i] < minVal) minVal = m_spreadValues[i];
         if(m_spreadValues[i] > maxVal) maxVal = m_spreadValues[i];
      }

      double range = maxVal - minVal;
      if(range < 1e-10) range = 1;

      // Draw standard deviation bands
      int meanY = chartY + chartH - (int)((m_spreadMean - minVal) / range * chartH);
      int std1UpY = chartY + chartH - (int)((m_spreadMean + m_spreadStd - minVal) / range * chartH);
      int std1DnY = chartY + chartH - (int)((m_spreadMean - m_spreadStd - minVal) / range * chartH);
      int std2UpY = chartY + chartH - (int)((m_spreadMean + 2 * m_spreadStd - minVal) / range * chartH);
      int std2DnY = chartY + chartH - (int)((m_spreadMean - 2 * m_spreadStd - minVal) / range * chartH);

      // Mean line
      string meanLine = m_prefix + "MEAN_LINE";
      if(ObjectFind(0, meanLine) < 0) {
         ObjectCreate(0, meanLine, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      }
      ObjectSetInteger(0, meanLine, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, meanLine, OBJPROP_XDISTANCE, chartX);
      ObjectSetInteger(0, meanLine, OBJPROP_YDISTANCE, meanY);
      ObjectSetInteger(0, meanLine, OBJPROP_XSIZE, chartW);
      ObjectSetInteger(0, meanLine, OBJPROP_YSIZE, 1);
      ObjectSetInteger(0, meanLine, OBJPROP_BGCOLOR, SPREAD_LINE_MEAN);
      ObjectSetInteger(0, meanLine, OBJPROP_BORDER_TYPE, BORDER_FLAT);

      // Draw spread points as small rectangles
      int pointW = MathMax(1, chartW / m_lookback);
      int displayPoints = MathMin(m_lookback, chartW / pointW);

      for(int i = 0; i < displayPoints; i++) {
         int idx = i;
         if(idx >= ArraySize(m_spreadValues)) continue;

         int pointX = chartX + chartW - (i + 1) * pointW;
         int pointY = chartY + chartH - (int)((m_spreadValues[idx] - minVal) / range * chartH);

         // Clamp to chart bounds
         if(pointY < chartY) pointY = chartY;
         if(pointY > chartY + chartH - 2) pointY = chartY + chartH - 2;

         string pointName = m_prefix + "PT_" + IntegerToString(i);

         if(ObjectFind(0, pointName) < 0) {
            ObjectCreate(0, pointName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         }
         ObjectSetInteger(0, pointName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, pointName, OBJPROP_XDISTANCE, pointX);
         ObjectSetInteger(0, pointName, OBJPROP_YDISTANCE, pointY);
         ObjectSetInteger(0, pointName, OBJPROP_XSIZE, MathMax(2, pointW - 1));
         ObjectSetInteger(0, pointName, OBJPROP_YSIZE, 3);

         // Color based on position relative to mean
         color pointColor;
         if(m_spreadValues[idx] > m_spreadMean + m_spreadStd) {
            pointColor = SPREAD_LINE_DOWN;  // Overbought
         } else if(m_spreadValues[idx] < m_spreadMean - m_spreadStd) {
            pointColor = SPREAD_LINE_UP;    // Oversold
         } else {
            pointColor = SPREAD_CYAN;       // Normal
         }

         ObjectSetInteger(0, pointName, OBJPROP_BGCOLOR, pointColor);
         ObjectSetInteger(0, pointName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, pointName, OBJPROP_BORDER_COLOR, pointColor);
      }

      // Labels for std levels
      CreateLabel("LBL_STD2U", "+2\317\203", chartX + chartW + 3, std2UpY - 5, SPREAD_LINE_STD2, 7);
      CreateLabel("LBL_STD1U", "+1\317\203", chartX + chartW + 3, std1UpY - 5, SPREAD_LINE_STD1, 7);
      CreateLabel("LBL_MEAN", "Mean", chartX + chartW + 3, meanY - 5, SPREAD_LINE_MEAN, 7);
      CreateLabel("LBL_STD1D", "-1\317\203", chartX + chartW + 3, std1DnY - 5, SPREAD_LINE_STD1, 7);
      CreateLabel("LBL_STD2D", "-2\317\203", chartX + chartW + 3, std2DnY - 5, SPREAD_LINE_STD2, 7);
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   C_SpreadChart() {
      m_prefix = "DL_SPREAD_";
      m_startX = 10;
      m_startY = 400;
      m_width = 350;
      m_height = 200;
      m_isVisible = true;
      m_isMinimized = false;
      m_symbol1 = "";
      m_symbol2 = "";
      m_hedgeRatio = 1.0;
      m_lookback = 100;
      m_spreadMean = 0;
      m_spreadStd = 0;
      m_currentZScore = 0;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~C_SpreadChart() {
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
   //| Set pair symbols                                                  |
   //+------------------------------------------------------------------+
   void SetPair(string sym1, string sym2) {
      m_symbol1 = sym1;
      m_symbol2 = sym2;
   }

   //+------------------------------------------------------------------+
   //| Update and draw                                                   |
   //+------------------------------------------------------------------+
   void Update(ENUM_TIMEFRAMES tf = PERIOD_H1) {
      if(!m_isVisible) return;
      if(m_symbol1 == "" || m_symbol2 == "") return;

      CalculateSpread(tf);
      Draw();
   }

   //+------------------------------------------------------------------+
   //| Draw the spread chart panel                                       |
   //+------------------------------------------------------------------+
   void Draw() {
      if(!m_isVisible) return;

      int x = m_startX;
      int y = m_startY;
      int w = m_width;

      // Main background
      CreateRect("BG", x, y, w, m_isMinimized ? 24 : m_height, SPREAD_BG_MAIN, C'150,50,200');

      // Title bar
      CreateRect("TITLE_BG", x, y, w, 24, SPREAD_BG_HEADER, C'150,50,200');

      string title = "Spread: " + m_symbol1 + " / " + m_symbol2;
      if(m_symbol1 == "") title = "Spread Chart - Select Pair";
      CreateLabel("TITLE", title, x + 8, y + 5, SPREAD_TEXT, 9, "Consolas Bold");

      // Minimize button
      CreateButton("BTN_MIN", m_isMinimized ? "+" : "-", x + w - 25, y + 3, 20, 18, C'60,65,75', SPREAD_TEXT, 10);

      if(m_isMinimized) {
         ChartRedraw(0);
         return;
      }

      // Stats row
      int statsY = y + 28;
      string statsText = "Z: " + DoubleToString(m_currentZScore, 2) +
                        " | HR: " + DoubleToString(m_hedgeRatio, 4) +
                        " | \317\203: " + DoubleToString(m_spreadStd, 6);
      CreateLabel("STATS", statsText, x + 8, statsY, SPREAD_TEXT_DIM, 7);

      // Signal indicator
      string signal = "";
      color sigColor = SPREAD_TEXT_DIM;

      if(m_currentZScore >= 2.0) {
         signal = "SELL SPREAD";
         sigColor = SPREAD_LINE_DOWN;
      } else if(m_currentZScore <= -2.0) {
         signal = "BUY SPREAD";
         sigColor = SPREAD_LINE_UP;
      } else if(MathAbs(m_currentZScore) < 0.5) {
         signal = "NEUTRAL";
         sigColor = SPREAD_LINE_MEAN;
      }

      CreateLabel("SIGNAL", signal, x + w - 90, statsY, sigColor, 8, "Consolas Bold");

      // Draw spread line chart
      if(m_symbol1 != "" && m_symbol2 != "") {
         DrawSpreadLine();
      }

      // Footer with interpretation
      int footerY = y + m_height - 20;
      string footerText = "Green=Oversold | Yellow=Mean | Red=Overbought";
      CreateLabel("FOOTER", footerText, x + 8, footerY, SPREAD_TEXT_DIM, 7);

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Handle click events                                               |
   //+------------------------------------------------------------------+
   bool HandleClick(string sparam) {
      if(sparam == m_prefix + "BTN_MIN") {
         m_isMinimized = !m_isMinimized;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Draw();
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Toggle visibility                                                 |
   //+------------------------------------------------------------------+
   void ToggleVisibility() {
      m_isVisible = !m_isVisible;
      if(!m_isVisible) {
         ObjectsDeleteAll(0, m_prefix);
      } else {
         Draw();
      }
   }

   //+------------------------------------------------------------------+
   //| Get visibility                                                    |
   //+------------------------------------------------------------------+
   bool IsVisible() { return m_isVisible; }

   //+------------------------------------------------------------------+
   //| Get current Z-Score                                               |
   //+------------------------------------------------------------------+
   double GetZScore() { return m_currentZScore; }

   //+------------------------------------------------------------------+
   //| Get hedge ratio                                                   |
   //+------------------------------------------------------------------+
   double GetHedgeRatio() { return m_hedgeRatio; }
};

//+------------------------------------------------------------------+
