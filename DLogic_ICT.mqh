//+------------------------------------------------------------------+
//|                                                 DLogic_ICT.mqh  |
//|                          Project: D-LOGIC Trading Dashboard      |
//|                                        Author: Rafał Dembski    |
//|      ICT Concepts: Kill Zones, Sessions, FVG, Order Blocks       |
//+------------------------------------------------------------------+
#property copyright "Rafał Dembski"
#property strict

// ============================================================
// COLOR SCHEME - BRIGHT
// ============================================================
#define ICT_BG_MAIN        C'25,28,35'
#define ICT_BG_HEADER      C'200,120,30'
#define ICT_LONDON         C'50,150,255'
#define ICT_NEWYORK        C'255,80,80'
#define ICT_ASIA           C'220,180,80'
#define ICT_KILLZONE       C'255,50,50'
#define ICT_FVG_BULL       C'0,180,100'
#define ICT_FVG_BEAR       C'180,60,100'
#define ICT_OB_BULL        C'30,130,220'
#define ICT_OB_BEAR        C'220,100,30'
#define ICT_BORDER         C'80,85,100'
#define ICT_TEXT           C'255,255,255'
#define ICT_TEXT_DIM       C'160,160,180'
#define ICT_POSITIVE       C'0,255,120'
#define ICT_NEGATIVE       C'255,80,80'
#define ICT_WARNING        C'255,220,50'

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
   //| Create Rectangle Label (for panel)                               |
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
   //| Delete ALL content objects (for minimize) - FIXED                 |
   //+------------------------------------------------------------------+
   void DeleteAllContent() {
      int total = ObjectsTotal(0, 0, -1);

      for(int i = total - 1; i >= 0; i--) {
         string name = ObjectName(0, i, 0, -1);

         // Skip if not our panel object
         if(StringFind(name, m_prefix) != 0) continue;

         // Keep title bar objects
         if(StringFind(name, m_prefix + "BG") == 0) continue;
         if(StringFind(name, m_prefix + "TITLE") == 0) continue;
         if(StringFind(name, m_prefix + "BTN_") == 0) continue;

         // Delete content objects (but not chart zones)
         if(StringFind(name, "ZONE_") < 0 && StringFind(name, "LBL_ZONE") < 0) {
            ObjectDelete(0, name);
         }
      }
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
   //| Check if hour is within range                                     |
   //+------------------------------------------------------------------+
   bool IsHourInRange(int hour, int start, int end) {
      if(start <= end) {
         return (hour >= start && hour < end);
      } else {
         return (hour >= start || hour < end);
      }
   }

   //+------------------------------------------------------------------+
   //| Initialize sessions                                               |
   //+------------------------------------------------------------------+
   void InitSessions() {
      m_sessions[0].name = "ASIA";
      m_sessions[0].startHour = ASIA_OPEN_HOUR;
      m_sessions[0].endHour = ASIA_CLOSE_HOUR;
      m_sessions[0].sessionColor = ICT_ASIA;

      m_sessions[1].name = "LONDON";
      m_sessions[1].startHour = LONDON_OPEN_HOUR;
      m_sessions[1].endHour = LONDON_CLOSE_HOUR;
      m_sessions[1].sessionColor = ICT_LONDON;

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

      m_sessions[0].isKillZone = IsHourInRange(gmtHour, ASIA_KILLZONE_START, ASIA_KILLZONE_END);
      m_sessions[1].isKillZone = IsHourInRange(gmtHour, LONDON_KILLZONE_START, LONDON_KILLZONE_END);
      m_sessions[2].isKillZone = IsHourInRange(gmtHour, NY_KILLZONE_START, NY_KILLZONE_END);
   }

   //+------------------------------------------------------------------+
   //| Detect Fair Value Gaps - IMPROVED ALGORITHM                       |
   //+------------------------------------------------------------------+
   void DetectFVG(ENUM_TIMEFRAMES tf, int lookback = 50) {
      m_fvgCount = 0;
      ArrayResize(m_fvgList, 50);

      double high[], low[], open[], close[];
      datetime time[];

      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(time, true);

      int copied = CopyHigh(m_symbol, tf, 0, lookback, high);
      if(copied < lookback) {
         Print("[ICT] Not enough data for FVG detection, got ", copied, " bars");
         return;
      }
      CopyLow(m_symbol, tf, 0, lookback, low);
      CopyOpen(m_symbol, tf, 0, lookback, open);
      CopyClose(m_symbol, tf, 0, lookback, close);
      CopyTime(m_symbol, tf, 0, lookback, time);

      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double minGap = point * 3;  // Minimum 3 points gap (lowered for more detection)

      Print("[ICT] Scanning for FVG on ", m_symbol, " ", EnumToString(tf), ", min gap: ", minGap);

      for(int i = 2; i < lookback - 1 && m_fvgCount < 50; i++) {
         // Bullish FVG: Gap UP - bar[i+1].high < bar[i-1].low
         // bar[i] is the impulse candle creating the gap
         double gapUp = low[i-1] - high[i+1];

         if(gapUp > minGap) {
            FVG fvg;
            fvg.time = time[i];
            fvg.high = low[i-1];      // Top of gap
            fvg.low = high[i+1];      // Bottom of gap
            fvg.isBullish = true;
            fvg.barIndex = i;
            fvg.isFilled = false;

            // Check if filled by price coming back into gap
            for(int j = i-1; j >= 0; j--) {
               if(low[j] <= fvg.low) {
                  fvg.isFilled = true;
                  break;
               }
            }

            // Only keep unfilled recent gaps
            if(!fvg.isFilled && i < 30) {
               m_fvgList[m_fvgCount] = fvg;
               m_fvgCount++;
               Print("[ICT] Found Bullish FVG at bar ", i, ", gap size: ", gapUp / point, " points");
            }
         }

         // Bearish FVG: Gap DOWN - bar[i+1].low > bar[i-1].high
         double gapDown = low[i+1] - high[i-1];

         if(gapDown > minGap) {
            FVG fvg;
            fvg.time = time[i];
            fvg.high = low[i+1];      // Top of gap
            fvg.low = high[i-1];      // Bottom of gap
            fvg.isBullish = false;
            fvg.barIndex = i;
            fvg.isFilled = false;

            // Check if filled
            for(int j = i-1; j >= 0; j--) {
               if(high[j] >= fvg.high) {
                  fvg.isFilled = true;
                  break;
               }
            }

            if(!fvg.isFilled && i < 30) {
               m_fvgList[m_fvgCount] = fvg;
               m_fvgCount++;
               Print("[ICT] Found Bearish FVG at bar ", i, ", gap size: ", gapDown / point, " points");
            }
         }
      }

      Print("[ICT] Total FVG found: ", m_fvgCount);
   }

   //+------------------------------------------------------------------+
   //| Detect Order Blocks - IMPROVED ALGORITHM                          |
   //+------------------------------------------------------------------+
   void DetectOrderBlocks(ENUM_TIMEFRAMES tf, int lookback = 50) {
      m_obCount = 0;
      ArrayResize(m_obList, 50);

      double high[], low[], open[], close[];
      datetime time[];

      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(time, true);

      int copied = CopyHigh(m_symbol, tf, 0, lookback, high);
      if(copied < lookback) {
         Print("[ICT] Not enough data for OB detection");
         return;
      }
      CopyLow(m_symbol, tf, 0, lookback, low);
      CopyOpen(m_symbol, tf, 0, lookback, open);
      CopyClose(m_symbol, tf, 0, lookback, close);
      CopyTime(m_symbol, tf, 0, lookback, time);

      // Calculate average range for comparison
      double avgRange = 0;
      for(int i = 0; i < 20; i++) {
         avgRange += high[i] - low[i];
      }
      avgRange /= 20;

      Print("[ICT] Scanning for Order Blocks, avg range: ", avgRange);

      for(int i = 3; i < lookback - 2 && m_obCount < 50; i++) {
         double candleRange = high[i] - low[i];
         double bodySize = MathAbs(close[i] - open[i]);
         bool isBearishCandle = close[i] < open[i];
         bool isBullishCandle = close[i] > open[i];

         // Bullish Order Block: Last bearish candle before strong bullish move
         if(isBearishCandle && bodySize > avgRange * 0.3) {
            // Check for strong bullish continuation
            double moveUp = close[i-2] - close[i];

            if(moveUp > avgRange * 1.0) {  // Lowered threshold
               OrderBlock ob;
               ob.time = time[i];
               ob.high = high[i];
               ob.low = low[i];
               ob.open = open[i];
               ob.close = close[i];
               ob.isBullish = true;
               ob.barIndex = i;
               ob.isMitigated = false;

               // Check if price has come back to OB (mitigated)
               for(int j = i-1; j >= 0; j--) {
                  if(low[j] <= ob.low) {
                     ob.isMitigated = true;
                     break;
                  }
               }

               if(!ob.isMitigated && i < 30) {
                  m_obList[m_obCount] = ob;
                  m_obCount++;
                  Print("[ICT] Found Bullish OB at bar ", i);
               }
            }
         }

         // Bearish Order Block: Last bullish candle before strong bearish move
         if(isBullishCandle && bodySize > avgRange * 0.3) {
            double moveDown = close[i] - close[i-2];

            if(moveDown > avgRange * 1.0) {
               OrderBlock ob;
               ob.time = time[i];
               ob.high = high[i];
               ob.low = low[i];
               ob.open = open[i];
               ob.close = close[i];
               ob.isBullish = false;
               ob.barIndex = i;
               ob.isMitigated = false;

               // Check mitigation
               for(int j = i-1; j >= 0; j--) {
                  if(high[j] >= ob.high) {
                     ob.isMitigated = true;
                     break;
                  }
               }

               if(!ob.isMitigated && i < 30) {
                  m_obList[m_obCount] = ob;
                  m_obCount++;
                  Print("[ICT] Found Bearish OB at bar ", i);
               }
            }
         }
      }

      Print("[ICT] Total Order Blocks found: ", m_obCount);
   }

   //+------------------------------------------------------------------+
   //| Draw FVG zones on chart                                           |
   //+------------------------------------------------------------------+
   void DrawFVGOnChart() {
      // Clear existing FVG zones
      ObjectsDeleteAll(0, m_prefix + "FVG_ZONE_");
      ObjectsDeleteAll(0, m_prefix + "FVG_LBL_");

      datetime futureTime = TimeCurrent() + PeriodSeconds(PERIOD_H4) * 20;

      for(int i = 0; i < m_fvgCount; i++) {
         string rectName = m_prefix + "FVG_ZONE_" + IntegerToString(i);

         // Create rectangle on chart
         if(!ObjectCreate(0, rectName, OBJ_RECTANGLE, 0,
                         m_fvgList[i].time, m_fvgList[i].high,
                         futureTime, m_fvgList[i].low)) {
            Print("[ICT] Failed to create FVG rectangle: ", GetLastError());
            continue;
         }

         color fvgColor = m_fvgList[i].isBullish ? C'0,180,80' : C'180,50,80';

         ObjectSetInteger(0, rectName, OBJPROP_COLOR, fvgColor);
         ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
         ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
         ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, rectName, OBJPROP_HIDDEN, false);
         ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);

         // Add text label
         string labelName = m_prefix + "FVG_LBL_" + IntegerToString(i);
         double midPrice = (m_fvgList[i].high + m_fvgList[i].low) / 2;

         ObjectCreate(0, labelName, OBJ_TEXT, 0, m_fvgList[i].time, midPrice);
         ObjectSetString(0, labelName, OBJPROP_TEXT, m_fvgList[i].isBullish ? "FVG+" : "FVG-");
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }

      Print("[ICT] Drew ", m_fvgCount, " FVG zones on chart");
   }

   //+------------------------------------------------------------------+
   //| Draw Order Blocks on chart                                        |
   //+------------------------------------------------------------------+
   void DrawOBOnChart() {
      // Clear existing OB zones
      ObjectsDeleteAll(0, m_prefix + "OB_ZONE_");
      ObjectsDeleteAll(0, m_prefix + "OB_LBL_");

      datetime futureTime = TimeCurrent() + PeriodSeconds(PERIOD_H4) * 20;

      for(int i = 0; i < m_obCount; i++) {
         string rectName = m_prefix + "OB_ZONE_" + IntegerToString(i);

         if(!ObjectCreate(0, rectName, OBJ_RECTANGLE, 0,
                         m_obList[i].time, m_obList[i].high,
                         futureTime, m_obList[i].low)) {
            Print("[ICT] Failed to create OB rectangle: ", GetLastError());
            continue;
         }

         color obColor = m_obList[i].isBullish ? C'30,120,200' : C'200,100,30';

         ObjectSetInteger(0, rectName, OBJPROP_COLOR, obColor);
         ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
         ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
         ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, rectName, OBJPROP_HIDDEN, false);
         ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 2);

         // Add label
         string labelName = m_prefix + "OB_LBL_" + IntegerToString(i);
         double midPrice = (m_obList[i].high + m_obList[i].low) / 2;

         ObjectCreate(0, labelName, OBJ_TEXT, 0, m_obList[i].time, midPrice);
         ObjectSetString(0, labelName, OBJPROP_TEXT, m_obList[i].isBullish ? "OB+" : "OB-");
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }

      Print("[ICT] Drew ", m_obCount, " Order Block zones on chart");
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   C_ICTAnalysis() {
      m_prefix = "DL_ICT_";
      m_startX = 10;
      m_startY = 600;
      m_width = 280;
      m_height = 175;
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
      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Clear chart zones                                                 |
   //+------------------------------------------------------------------+
   void ClearChartZones() {
      ObjectsDeleteAll(0, m_prefix + "FVG_ZONE_");
      ObjectsDeleteAll(0, m_prefix + "FVG_LBL_");
      ObjectsDeleteAll(0, m_prefix + "OB_ZONE_");
      ObjectsDeleteAll(0, m_prefix + "OB_LBL_");
      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Draw panel                                                        |
   //+------------------------------------------------------------------+
   void Draw() {
      if(!m_isVisible) return;

      int x = m_startX;
      int y = m_startY;
      int w = m_width;

      // Delete content if minimized
      if(m_isMinimized) {
         DeleteAllContent();
      }

      // Main background
      CreateRect("BG", x, y, w, m_isMinimized ? 26 : m_height, ICT_BG_MAIN, ICT_BG_HEADER);

      // Title bar
      CreateRect("TITLE_BG", x, y, w, 26, ICT_BG_HEADER, ICT_BG_HEADER);
      CreateLabel("TITLE", "ICT Analysis - " + m_symbol, x + 10, y + 6, ICT_TEXT, 9, "Consolas Bold");

      // Buttons
      CreateButton("BTN_MIN", m_isMinimized ? "+" : "-", x + w - 25, y + 4, 20, 18, C'150,100,20', ICT_TEXT, 10);
      CreateButton("BTN_DRAW", "Draw", x + w - 70, y + 4, 40, 18, C'120,80,20', ICT_TEXT, 7);

      if(m_isMinimized) {
         ChartRedraw(0);
         return;
      }

      int row = 0;
      int rowH = 18;
      int startY = y + 30;

      // ===== SESSIONS SECTION =====
      CreateLabel("SEC_SESS", "--- SESSIONS ---", x + 10, startY + row * rowH, ICT_WARNING, 8, "Consolas Bold");
      row++;

      for(int i = 0; i < 3; i++) {
         string status = m_sessions[i].isActive ? "ACTIVE" : "Closed";
         string killzone = m_sessions[i].isKillZone ? " [KILL ZONE]" : " Label";

         color statusColor = m_sessions[i].isActive ? ICT_POSITIVE : ICT_TEXT_DIM;

         // Session indicator square
         CreateRect("SESS_IND_" + IntegerToString(i), x + 10, startY + row * rowH + 4, 10, 10, m_sessions[i].sessionColor);

         // Session text
         CreateLabel("SESS_" + IntegerToString(i), m_sessions[i].name + ": " + status,
                     x + 25, startY + row * rowH + 2, statusColor, 8);

         // Kill zone indicator
         if(m_sessions[i].isKillZone) {
            CreateLabel("KZ_" + IntegerToString(i), "[KILL ZONE]", x + 140, startY + row * rowH + 2, ICT_KILLZONE, 8, "Consolas Bold");
         } else {
            CreateLabel("KZ_" + IntegerToString(i), "", x + 140, startY + row * rowH + 2, ICT_TEXT_DIM, 8);
         }

         row++;
      }

      row++;

      // ===== ICT PATTERNS =====
      CreateLabel("SEC_PATT", "--- ICT PATTERNS ---", x + 10, startY + row * rowH, ICT_WARNING, 8, "Consolas Bold");
      row++;

      // FVG Count
      CreateLabel("LBL_FVG", "Fair Value Gaps:", x + 10, startY + row * rowH + 2, ICT_TEXT_DIM, 8);
      color fvgColor = m_fvgCount > 0 ? ICT_POSITIVE : ICT_TEXT_DIM;
      CreateLabel("VAL_FVG", IntegerToString(m_fvgCount) + " active", x + 140, startY + row * rowH + 2, fvgColor, 8, "Consolas Bold");
      row++;

      // Order Blocks Count
      CreateLabel("LBL_OB", "Order Blocks:", x + 10, startY + row * rowH + 2, ICT_TEXT_DIM, 8);
      color obColor = m_obCount > 0 ? ICT_POSITIVE : ICT_TEXT_DIM;
      CreateLabel("VAL_OB", IntegerToString(m_obCount) + " active", x + 140, startY + row * rowH + 2, obColor, 8, "Consolas Bold");
      row++;

      // ===== SIGNAL =====
      row++;
      string recommendation = GetRecommendation();
      color recColor = ICT_TEXT_DIM;

      if(StringFind(recommendation, "BUY") >= 0) recColor = ICT_POSITIVE;
      else if(StringFind(recommendation, "SELL") >= 0) recColor = ICT_NEGATIVE;
      else if(StringFind(recommendation, "WAIT") >= 0) recColor = ICT_WARNING;

      CreateLabel("LBL_SIG", "Signal:", x + 10, startY + row * rowH + 2, ICT_TEXT, 8);
      CreateLabel("VAL_SIG", recommendation, x + 65, startY + row * rowH + 2, recColor, 8, "Consolas Bold");

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Get trading recommendation                                        |
   //+------------------------------------------------------------------+
   string GetRecommendation() {
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

      int bullSignals = 0;
      int bearSignals = 0;

      for(int i = 0; i < m_fvgCount; i++) {
         if(m_fvgList[i].isBullish) bullSignals++;
         else bearSignals++;
      }

      for(int i = 0; i < m_obCount; i++) {
         if(m_obList[i].isBullish) bullSignals++;
         else bearSignals++;
      }

      if(bullSignals > bearSignals && bullSignals >= 1) {
         return "BUY (" + activeSession + ")";
      } else if(bearSignals > bullSignals && bearSignals >= 1) {
         return "SELL (" + activeSession + ")";
      } else if(bullSignals > 0 || bearSignals > 0) {
         return "MIXED - Check zones";
      }

      return "WAIT - No pattern";
   }

   //+------------------------------------------------------------------+
   //| Handle click events                                               |
   //+------------------------------------------------------------------+
   bool HandleClick(string sparam) {
      if(sparam == m_prefix + "BTN_MIN") {
         m_isMinimized = !m_isMinimized;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

         if(m_isMinimized) {
            DeleteAllContent();
         }

         Draw();
         return true;
      }

      if(sparam == m_prefix + "BTN_DRAW") {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Print("[ICT] Drawing zones on chart...");
         DrawOnChart();
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
         ClearChartZones();
      } else {
         m_isMinimized = false;
         Draw();
      }
   }

   bool IsVisible() { return m_isVisible; }

   bool IsInKillZone() {
      for(int i = 0; i < 3; i++) {
         if(m_sessions[i].isKillZone) return true;
      }
      return false;
   }

   string GetActiveSession() {
      for(int i = 0; i < 3; i++) {
         if(m_sessions[i].isActive) return m_sessions[i].name;
      }
      return "NONE";
   }

   int GetFVGCount() { return m_fvgCount; }
   int GetOBCount() { return m_obCount; }
};

//+------------------------------------------------------------------+
