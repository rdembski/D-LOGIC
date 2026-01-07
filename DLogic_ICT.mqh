//+------------------------------------------------------------------+
//|                                                 DLogic_ICT.mqh  |
//|                          Project: D-LOGIC Trading Dashboard      |
//|                                        Author: RafaB Dembski    |
//|      ICT Concepts: Kill Zones, Sessions, FVG, Order Blocks       |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"
#property strict

// ============================================================
// COLOR SCHEME
// ============================================================
#define ICT_BG_MAIN        C'15,15,20'
#define ICT_BG_HEADER      C'150,80,0'
#define ICT_LONDON         C'0,100,200'
#define ICT_NEWYORK        C'200,50,50'
#define ICT_ASIA           C'150,100,50'
#define ICT_KILLZONE       C'255,50,50'
#define ICT_FVG_BULL       C'0,150,80'
#define ICT_FVG_BEAR       C'150,50,80'
#define ICT_OB_BULL        C'0,100,180'
#define ICT_OB_BEAR        C'180,80,0'
#define ICT_BORDER         C'50,55,65'
#define ICT_TEXT           C'220,220,225'
#define ICT_TEXT_DIM       C'130,130,145'
#define ICT_POSITIVE       C'0,230,118'
#define ICT_NEGATIVE       C'255,82,82'
#define ICT_WARNING        C'255,193,7'

// ============================================================
// SESSION TIMES (GMT/UTC)
// ============================================================
#define ASIA_OPEN_HOUR     0
#define ASIA_CLOSE_HOUR    9
#define LONDON_OPEN_HOUR   7
#define LONDON_CLOSE_HOUR  16
#define NY_OPEN_HOUR       12
#define NY_CLOSE_HOUR      21

// Kill Zones (most volatile periods)
#define LONDON_KILLZONE_START   7
#define LONDON_KILLZONE_END     10
#define NY_KILLZONE_START       12
#define NY_KILLZONE_END         15
#define ASIA_KILLZONE_START     0
#define ASIA_KILLZONE_END       3

// ============================================================
// STRUCTURES
// ============================================================

// Fair Value Gap structure
struct FVG {
   datetime time;
   double   high;
   double   low;
   bool     isBullish;
   bool     isFilled;
   int      barIndex;
};

// Order Block structure
struct OrderBlock {
   datetime time;
   double   high;
   double   low;
   double   open;
   double   close;
   bool     isBullish;
   bool     isMitigated;
   int      barIndex;
};

// Session info
struct SessionInfo {
   string   name;
   int      startHour;
   int      endHour;
   bool     isActive;
   bool     isKillZone;
   color    sessionColor;
};

//+------------------------------------------------------------------+
//| ICT Analysis Class                                                |
//+------------------------------------------------------------------+
class C_ICTAnalysis {
private:
   string         m_prefix;
   int            m_startX;
   int            m_startY;
   int            m_width;
   int            m_height;
   bool           m_isVisible;
   bool           m_isMinimized;

   string         m_symbol;
   int            m_gmtOffset;

   // Detected patterns
   FVG            m_fvgList[];
   int            m_fvgCount;
   OrderBlock     m_obList[];
   int            m_obCount;

   // Session data
   SessionInfo    m_sessions[3];

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
      ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, (border == clrNONE) ? ICT_BORDER : border);
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
   //| Get current GMT hour                                              |
   //+------------------------------------------------------------------+
   int GetGMTHour() {
      datetime gmtTime = TimeGMT();
      MqlDateTime dt;
      TimeToStruct(gmtTime, dt);
      return dt.hour;
   }

   //+------------------------------------------------------------------+
   //| Check if hour is within range (handles overnight)                 |
   //+------------------------------------------------------------------+
   bool IsHourInRange(int hour, int start, int end) {
      if(start <= end) {
         return (hour >= start && hour < end);
      } else {
         // Overnight session (e.g., Asia: 22-7)
         return (hour >= start || hour < end);
      }
   }

   //+------------------------------------------------------------------+
   //| Initialize sessions                                               |
   //+------------------------------------------------------------------+
   void InitSessions() {
      // Asia Session
      m_sessions[0].name = "ASIA";
      m_sessions[0].startHour = ASIA_OPEN_HOUR;
      m_sessions[0].endHour = ASIA_CLOSE_HOUR;
      m_sessions[0].sessionColor = ICT_ASIA;

      // London Session
      m_sessions[1].name = "LONDON";
      m_sessions[1].startHour = LONDON_OPEN_HOUR;
      m_sessions[1].endHour = LONDON_CLOSE_HOUR;
      m_sessions[1].sessionColor = ICT_LONDON;

      // New York Session
      m_sessions[2].name = "NEW YORK";
      m_sessions[2].startHour = NY_OPEN_HOUR;
      m_sessions[2].endHour = NY_CLOSE_HOUR;
      m_sessions[2].sessionColor = ICT_NEWYORK;
   }

   //+------------------------------------------------------------------+
   //| Update session status                                             |
   //+------------------------------------------------------------------+
   void UpdateSessions() {
      int gmtHour = GetGMTHour();

      for(int i = 0; i < 3; i++) {
         m_sessions[i].isActive = IsHourInRange(gmtHour, m_sessions[i].startHour, m_sessions[i].endHour);
      }

      // Check Kill Zones
      m_sessions[0].isKillZone = IsHourInRange(gmtHour, ASIA_KILLZONE_START, ASIA_KILLZONE_END);
      m_sessions[1].isKillZone = IsHourInRange(gmtHour, LONDON_KILLZONE_START, LONDON_KILLZONE_END);
      m_sessions[2].isKillZone = IsHourInRange(gmtHour, NY_KILLZONE_START, NY_KILLZONE_END);
   }

   //+------------------------------------------------------------------+
   //| Detect Fair Value Gaps                                            |
   //+------------------------------------------------------------------+
   void DetectFVG(ENUM_TIMEFRAMES tf, int lookback = 50) {
      m_fvgCount = 0;
      ArrayResize(m_fvgList, 20);

      double high[], low[], open[], close[];
      datetime time[];

      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(time, true);

      if(CopyHigh(m_symbol, tf, 0, lookback, high) < lookback) return;
      if(CopyLow(m_symbol, tf, 0, lookback, low) < lookback) return;
      if(CopyOpen(m_symbol, tf, 0, lookback, open) < lookback) return;
      if(CopyClose(m_symbol, tf, 0, lookback, close) < lookback) return;
      if(CopyTime(m_symbol, tf, 0, lookback, time) < lookback) return;

      // FVG: Gap between candle 0's low and candle 2's high (bullish)
      //      or candle 0's high and candle 2's low (bearish)
      for(int i = 2; i < lookback - 1 && m_fvgCount < 20; i++) {
         // Bullish FVG: Gap up - current candle's low > 2 bars ago high
         if(low[i-2] > high[i]) {
            FVG fvg;
            fvg.time = time[i-1];
            fvg.high = low[i-2];
            fvg.low = high[i];
            fvg.isBullish = true;
            fvg.barIndex = i-1;

            // Check if filled
            fvg.isFilled = false;
            for(int j = i-2; j >= 0; j--) {
               if(low[j] <= fvg.high) {
                  fvg.isFilled = true;
                  break;
               }
            }

            m_fvgList[m_fvgCount] = fvg;
            m_fvgCount++;
         }

         // Bearish FVG: Gap down - current candle's high < 2 bars ago low
         if(high[i-2] < low[i]) {
            FVG fvg;
            fvg.time = time[i-1];
            fvg.high = low[i];
            fvg.low = high[i-2];
            fvg.isBullish = false;
            fvg.barIndex = i-1;

            // Check if filled
            fvg.isFilled = false;
            for(int j = i-2; j >= 0; j--) {
               if(high[j] >= fvg.low) {
                  fvg.isFilled = true;
                  break;
               }
            }

            m_fvgList[m_fvgCount] = fvg;
            m_fvgCount++;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Detect Order Blocks                                               |
   //+------------------------------------------------------------------+
   void DetectOrderBlocks(ENUM_TIMEFRAMES tf, int lookback = 50) {
      m_obCount = 0;
      ArrayResize(m_obList, 20);

      double high[], low[], open[], close[];
      datetime time[];

      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(time, true);

      if(CopyHigh(m_symbol, tf, 0, lookback, high) < lookback) return;
      if(CopyLow(m_symbol, tf, 0, lookback, low) < lookback) return;
      if(CopyOpen(m_symbol, tf, 0, lookback, open) < lookback) return;
      if(CopyClose(m_symbol, tf, 0, lookback, close) < lookback) return;
      if(CopyTime(m_symbol, tf, 0, lookback, time) < lookback) return;

      // Order Block: Last opposite candle before a strong move
      for(int i = 3; i < lookback - 1 && m_obCount < 20; i++) {
         // Bullish OB: Last bearish candle before strong bullish move
         bool isBearishCandle = close[i] < open[i];
         bool isStrongBullishMove = (close[i-1] > open[i-1]) &&
                                    (close[i-1] - open[i-1] > (high[i] - low[i]) * 1.5);

         if(isBearishCandle && isStrongBullishMove) {
            OrderBlock ob;
            ob.time = time[i];
            ob.high = high[i];
            ob.low = low[i];
            ob.open = open[i];
            ob.close = close[i];
            ob.isBullish = true;
            ob.barIndex = i;

            // Check if mitigated (price returned to OB)
            ob.isMitigated = false;
            for(int j = i-1; j >= 0; j--) {
               if(low[j] <= ob.high) {
                  ob.isMitigated = true;
                  break;
               }
            }

            m_obList[m_obCount] = ob;
            m_obCount++;
         }

         // Bearish OB: Last bullish candle before strong bearish move
         bool isBullishCandle = close[i] > open[i];
         bool isStrongBearishMove = (close[i-1] < open[i-1]) &&
                                    (open[i-1] - close[i-1] > (high[i] - low[i]) * 1.5);

         if(isBullishCandle && isStrongBearishMove) {
            OrderBlock ob;
            ob.time = time[i];
            ob.high = high[i];
            ob.low = low[i];
            ob.open = open[i];
            ob.close = close[i];
            ob.isBullish = false;
            ob.barIndex = i;

            // Check if mitigated
            ob.isMitigated = false;
            for(int j = i-1; j >= 0; j--) {
               if(high[j] >= ob.low) {
                  ob.isMitigated = true;
                  break;
               }
            }

            m_obList[m_obCount] = ob;
            m_obCount++;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Draw FVG zones on chart                                           |
   //+------------------------------------------------------------------+
   void DrawFVGOnChart() {
      // Remove old FVG rectangles
      ObjectsDeleteAll(0, m_prefix + "FVG_ZONE_");

      for(int i = 0; i < m_fvgCount; i++) {
         if(m_fvgList[i].isFilled) continue;  // Skip filled FVGs

         string rectName = m_prefix + "FVG_ZONE_" + IntegerToString(i);

         if(ObjectFind(0, rectName) < 0) {
            ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, 0, 0, 0, 0);
         }

         datetime startTime = m_fvgList[i].time;
         datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_H1) * 24;

         ObjectSetInteger(0, rectName, OBJPROP_TIME, 0, startTime);
         ObjectSetDouble(0, rectName, OBJPROP_PRICE, 0, m_fvgList[i].high);
         ObjectSetInteger(0, rectName, OBJPROP_TIME, 1, endTime);
         ObjectSetDouble(0, rectName, OBJPROP_PRICE, 1, m_fvgList[i].low);

         color fvgColor = m_fvgList[i].isBullish ? ICT_FVG_BULL : ICT_FVG_BEAR;
         ObjectSetInteger(0, rectName, OBJPROP_COLOR, fvgColor);
         ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
         ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
         ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
      }
   }

   //+------------------------------------------------------------------+
   //| Draw Order Blocks on chart                                        |
   //+------------------------------------------------------------------+
   void DrawOBOnChart() {
      // Remove old OB rectangles
      ObjectsDeleteAll(0, m_prefix + "OB_ZONE_");

      for(int i = 0; i < m_obCount; i++) {
         if(m_obList[i].isMitigated) continue;  // Skip mitigated OBs

         string rectName = m_prefix + "OB_ZONE_" + IntegerToString(i);

         if(ObjectFind(0, rectName) < 0) {
            ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, 0, 0, 0, 0);
         }

         datetime startTime = m_obList[i].time;
         datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_H1) * 24;

         ObjectSetInteger(0, rectName, OBJPROP_TIME, 0, startTime);
         ObjectSetDouble(0, rectName, OBJPROP_PRICE, 0, m_obList[i].high);
         ObjectSetInteger(0, rectName, OBJPROP_TIME, 1, endTime);
         ObjectSetDouble(0, rectName, OBJPROP_PRICE, 1, m_obList[i].low);

         color obColor = m_obList[i].isBullish ? ICT_OB_BULL : ICT_OB_BEAR;
         ObjectSetInteger(0, rectName, OBJPROP_COLOR, obColor);
         ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
         ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
         ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 2);
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   C_ICTAnalysis() {
      m_prefix = "DL_ICT_";
      m_startX = 10;
      m_startY = 620;
      m_width = 350;
      m_height = 180;
      m_isVisible = true;
      m_isMinimized = false;
      m_symbol = _Symbol;
      m_gmtOffset = 0;
      m_fvgCount = 0;
      m_obCount = 0;

      InitSessions();
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~C_ICTAnalysis() {
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
   //| Set symbol                                                        |
   //+------------------------------------------------------------------+
   void SetSymbol(string symbol) {
      m_symbol = symbol;
   }

   //+------------------------------------------------------------------+
   //| Full analysis update                                              |
   //+------------------------------------------------------------------+
   void Update(ENUM_TIMEFRAMES tf = PERIOD_H1) {
      if(!m_isVisible) return;

      UpdateSessions();
      DetectFVG(tf);
      DetectOrderBlocks(tf);
      Draw();
   }

   //+------------------------------------------------------------------+
   //| Draw on chart (zones)                                             |
   //+------------------------------------------------------------------+
   void DrawOnChart() {
      DrawFVGOnChart();
      DrawOBOnChart();
   }

   //+------------------------------------------------------------------+
   //| Draw panel                                                        |
   //+------------------------------------------------------------------+
   void Draw() {
      if(!m_isVisible) return;

      int x = m_startX;
      int y = m_startY;
      int w = m_width;

      // Main background
      CreateRect("BG", x, y, w, m_isMinimized ? 24 : m_height, ICT_BG_MAIN, ICT_WARNING);

      // Title bar
      CreateRect("TITLE_BG", x, y, w, 24, ICT_BG_HEADER, ICT_WARNING);
      CreateLabel("TITLE", "ICT Analysis - " + m_symbol, x + 8, y + 5, ICT_TEXT, 9, "Consolas Bold");

      // Minimize button
      CreateButton("BTN_MIN", m_isMinimized ? "+" : "-", x + w - 25, y + 3, 20, 18, C'60,65,75', ICT_TEXT, 10);

      // Draw on chart button
      CreateButton("BTN_DRAW", "Draw", x + w - 70, y + 3, 40, 18, C'80,60,20', ICT_TEXT, 7);

      if(m_isMinimized) {
         ChartRedraw(0);
         return;
      }

      int row = 0;
      int rowH = 20;
      int startY = y + 30;

      // ===== SESSIONS SECTION =====
      CreateLabel("LBL_SESS", "--- SESSIONS ---", x + 8, startY + row * rowH, ICT_WARNING, 8);
      row++;

      for(int i = 0; i < 3; i++) {
         string sessName = m_sessions[i].name;
         string status = m_sessions[i].isActive ? "ACTIVE" : "Closed";
         string killzone = m_sessions[i].isKillZone ? " [KILL ZONE]" : "";

         color statusColor = m_sessions[i].isActive ? ICT_POSITIVE : ICT_TEXT_DIM;
         color kzColor = ICT_KILLZONE;

         // Session indicator
         CreateRect("SESS_IND_" + IntegerToString(i), x + 8, startY + row * rowH + 3, 8, 8, m_sessions[i].sessionColor);
         CreateLabel("SESS_" + IntegerToString(i), sessName + ": " + status,
                     x + 22, startY + row * rowH, statusColor, 8);

         if(m_sessions[i].isKillZone) {
            CreateLabel("KZ_" + IntegerToString(i), killzone, x + 140, startY + row * rowH, kzColor, 8, "Consolas Bold");
         } else {
            CreateLabel("KZ_" + IntegerToString(i), "", x + 140, startY + row * rowH, kzColor, 8);
         }
         row++;
      }

      row++;

      // ===== ICT PATTERNS =====
      CreateLabel("LBL_PATT", "--- ICT PATTERNS ---", x + 8, startY + row * rowH, ICT_WARNING, 8);
      row++;

      // FVG Count
      int activeFVG = 0;
      for(int i = 0; i < m_fvgCount; i++) {
         if(!m_fvgList[i].isFilled) activeFVG++;
      }
      CreateLabel("LBL_FVG", "Fair Value Gaps:", x + 8, startY + row * rowH, ICT_TEXT_DIM, 8);
      CreateLabel("VAL_FVG", IntegerToString(activeFVG) + " active", x + 140, startY + row * rowH,
                  activeFVG > 0 ? ICT_POSITIVE : ICT_TEXT_DIM, 8);
      row++;

      // Order Blocks Count
      int activeOB = 0;
      for(int i = 0; i < m_obCount; i++) {
         if(!m_obList[i].isMitigated) activeOB++;
      }
      CreateLabel("LBL_OB", "Order Blocks:", x + 8, startY + row * rowH, ICT_TEXT_DIM, 8);
      CreateLabel("VAL_OB", IntegerToString(activeOB) + " active", x + 140, startY + row * rowH,
                  activeOB > 0 ? ICT_POSITIVE : ICT_TEXT_DIM, 8);
      row++;

      // Signal recommendation
      row++;
      string recommendation = GetRecommendation();
      color recColor = ICT_TEXT_DIM;

      if(StringFind(recommendation, "BUY") >= 0) recColor = ICT_POSITIVE;
      else if(StringFind(recommendation, "SELL") >= 0) recColor = ICT_NEGATIVE;
      else if(StringFind(recommendation, "WAIT") >= 0) recColor = ICT_WARNING;

      CreateLabel("LBL_REC", "Signal:", x + 8, startY + row * rowH, ICT_TEXT, 8);
      CreateLabel("VAL_REC", recommendation, x + 70, startY + row * rowH, recColor, 8, "Consolas Bold");

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Get trading recommendation                                        |
   //+------------------------------------------------------------------+
   string GetRecommendation() {
      // Check if in Kill Zone
      bool inKillZone = false;
      string activeSession = "";

      for(int i = 0; i < 3; i++) {
         if(m_sessions[i].isKillZone) {
            inKillZone = true;
            activeSession = m_sessions[i].name;
            break;
         }
      }

      if(!inKillZone) {
         return "WAIT - No Kill Zone";
      }

      // Check for unfilled FVGs
      int bullFVG = 0, bearFVG = 0;
      for(int i = 0; i < m_fvgCount; i++) {
         if(!m_fvgList[i].isFilled) {
            if(m_fvgList[i].isBullish) bullFVG++;
            else bearFVG++;
         }
      }

      // Check for unmitigated OBs
      int bullOB = 0, bearOB = 0;
      for(int i = 0; i < m_obCount; i++) {
         if(!m_obList[i].isMitigated) {
            if(m_obList[i].isBullish) bullOB++;
            else bearOB++;
         }
      }

      // Generate recommendation
      if(bullFVG > 0 && bullOB > 0) {
         return "BUY Setup (" + activeSession + ")";
      } else if(bearFVG > 0 && bearOB > 0) {
         return "SELL Setup (" + activeSession + ")";
      } else if(bullFVG > bearFVG || bullOB > bearOB) {
         return "Lean LONG (" + activeSession + ")";
      } else if(bearFVG > bullFVG || bearOB > bullOB) {
         return "Lean SHORT (" + activeSession + ")";
      }

      return "WAIT - Analyzing...";
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

      if(sparam == m_prefix + "BTN_DRAW") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         DrawOnChart();
         Print("[ICT] Drew ", m_fvgCount, " FVGs and ", m_obCount, " Order Blocks on chart");
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
   //| Check if in Kill Zone                                             |
   //+------------------------------------------------------------------+
   bool IsInKillZone() {
      for(int i = 0; i < 3; i++) {
         if(m_sessions[i].isKillZone) return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Get active session name                                           |
   //+------------------------------------------------------------------+
   string GetActiveSession() {
      for(int i = 0; i < 3; i++) {
         if(m_sessions[i].isActive) return m_sessions[i].name;
      }
      return "NONE";
   }
};

//+------------------------------------------------------------------+
