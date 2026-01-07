//+------------------------------------------------------------------+
//|                                              D-LOGIC_Pairs.mq5  |
//|                          Professional Pairs Trading Dashboard    |
//|                                        Author: RafaB Dembski    |
//|     Features: Spearman, Cointegration, Z-Score, Multi-Timeframe |
//|               + Position Calculator + Spread Chart + ICT        |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"
#property description "D-LOGIC Professional Trading Dashboard - Pairs + ICT + Risk Management"
#property version   "3.00"
#property strict

#include "DLogic_PairsDash.mqh"
#include "DLogic_Calculator.mqh"
#include "DLogic_SpreadChart.mqh"
#include "DLogic_ICT.mqh"

// ============================================================
// INPUT PARAMETERS
// ============================================================

input group "=== SYMBOL CONFIGURATION ==="
input string   Inp_Pairs = "";                   // Custom symbols (empty = auto-load from broker)
input bool     Inp_AutoLoadSymbols = true;       // Auto-load Forex pairs from broker

input group "=== ANALYSIS SETTINGS ==="
input int      Inp_Lookback = 100;               // Lookback period (bars)
input double   Inp_CorrThreshold = 0.75;         // Correlation threshold (0.0-1.0)
input double   Inp_ZScoreEntry = 2.0;            // Z-Score for entry signal
input double   Inp_ZScoreExit = 0.5;             // Z-Score for exit signal

input group "=== TIMEFRAME SETTINGS ==="
input ENUM_TIMEFRAMES Inp_TF1 = PERIOD_H1;       // Primary timeframe
input ENUM_TIMEFRAMES Inp_TF2 = PERIOD_H4;       // Secondary timeframe
input ENUM_TIMEFRAMES Inp_TF3 = PERIOD_D1;       // Tertiary timeframe
input bool     Inp_MultiTF = true;               // Scan multiple timeframes

input group "=== DISPLAY SETTINGS ==="
input int      Inp_MaxPairs = 20;                // Maximum pairs to display
input int      Inp_DashX = 10;                   // Dashboard X position
input int      Inp_DashY = 30;                   // Dashboard Y position
input bool     Inp_SortBySignal = true;          // Sort by signal strength first

input group "=== POSITION CALCULATOR ==="
input bool     Inp_ShowCalculator = true;        // Show Position Calculator
input double   Inp_DefaultRisk = 1.0;            // Default Risk % (0.1-10)
input double   Inp_DefaultSL = 50;               // Default Stop Loss (pips)
input double   Inp_DefaultTP = 100;              // Default Take Profit (pips)

input group "=== SPREAD CHART ==="
input bool     Inp_ShowSpreadChart = true;       // Show Spread Chart

input group "=== ICT ANALYSIS ==="
input bool     Inp_ShowICT = true;               // Show ICT Panel
input bool     Inp_DrawICTZones = false;         // Auto-draw ICT zones on chart

input group "=== ALERTS ==="
input bool     Inp_AlertsEnabled = true;         // Enable sound alerts
input bool     Inp_PushEnabled = false;          // Enable push notifications
input bool     Inp_EmailEnabled = false;         // Enable email alerts

// ============================================================
// GLOBAL OBJECTS
// ============================================================

C_PairsCore           *PairsEngine;
C_PairsDashboard      *Dashboard;
C_PositionCalculator  *Calculator;
C_SpreadChart         *SpreadChart;
C_ICTAnalysis         *ICTPanel;

string           g_symbols[];
int              g_symbolCount;
PairResult       g_results[];
int              g_resultCount;
datetime         g_lastScan;
int              g_scanInterval = 60;            // Seconds between auto-scans

// Currently selected pair for spread chart
string           g_selectedPair1 = "";
string           g_selectedPair2 = "";

// Timeframes to scan
ENUM_TIMEFRAMES  g_timeframes[];
int              g_tfCount;

//+------------------------------------------------------------------+
//| Parse custom symbols from input string                           |
//+------------------------------------------------------------------+
void ParseCustomSymbols() {
   if(StringLen(Inp_Pairs) < 3) {
      g_symbolCount = 0;
      return;
   }

   string pairs = Inp_Pairs;
   StringReplace(pairs, " ", "");

   string parts[];
   g_symbolCount = StringSplit(pairs, ',', parts);

   ArrayResize(g_symbols, g_symbolCount);
   int validCount = 0;

   for(int i = 0; i < g_symbolCount; i++) {
      if(SymbolSelect(parts[i], true)) {
         double bid = SymbolInfoDouble(parts[i], SYMBOL_BID);
         if(bid > 0) {
            g_symbols[validCount] = parts[i];
            validCount++;
         }
      } else {
         Print("[PAIRS] Symbol not available: ", parts[i]);
      }
   }

   g_symbolCount = validCount;
   ArrayResize(g_symbols, g_symbolCount);
}

//+------------------------------------------------------------------+
//| Initialize symbols - auto-load or custom                          |
//+------------------------------------------------------------------+
void InitializeSymbols() {
   if(Inp_AutoLoadSymbols && StringLen(Inp_Pairs) < 3) {
      int loaded = PairsEngine.LoadSymbolsFromBroker();
      PairsEngine.GetSymbols(g_symbols, g_symbolCount);
      Print("[PAIRS] Auto-loaded ", g_symbolCount, " symbols from broker");
   } else {
      ParseCustomSymbols();
      Print("[PAIRS] Loaded ", g_symbolCount, " custom symbols");
   }

   if(g_symbolCount > 0) {
      string symList = "";
      int showMax = MathMin(10, g_symbolCount);
      for(int i = 0; i < showMax; i++) {
         symList += g_symbols[i];
         if(i < showMax - 1) symList += ", ";
      }
      if(g_symbolCount > showMax) symList += "...";
      Print("[PAIRS] Symbols: ", symList);
   }
}

//+------------------------------------------------------------------+
//| Initialize timeframes for scanning                                |
//+------------------------------------------------------------------+
void InitializeTimeframes() {
   if(Inp_MultiTF) {
      g_tfCount = 3;
      ArrayResize(g_timeframes, g_tfCount);
      g_timeframes[0] = Inp_TF1;
      g_timeframes[1] = Inp_TF2;
      g_timeframes[2] = Inp_TF3;
   } else {
      g_tfCount = 1;
      ArrayResize(g_timeframes, g_tfCount);
      g_timeframes[0] = Inp_TF1;
   }
   Print("[PAIRS] Scanning ", g_tfCount, " timeframe(s)");
}

//+------------------------------------------------------------------+
//| Get timeframe name for display                                    |
//+------------------------------------------------------------------+
string GetTFName(ENUM_TIMEFRAMES tf) {
   switch(tf) {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default: return "??";
   }
}

//+------------------------------------------------------------------+
//| Calculate panel positions based on chart size                     |
//+------------------------------------------------------------------+
void CalculatePanelPositions() {
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   // Dashboard is on the left (fixed position from input)
   // Other panels positioned to the right

   // Calculator - right side, top
   if(Calculator != NULL) {
      int calcX = MathMax(400, chartWidth - 300);
      Calculator.SetPosition(calcX, 30);
   }

   // Spread Chart - below dashboard on left
   if(SpreadChart != NULL) {
      SpreadChart.SetPosition(10, 420);
   }

   // ICT Panel - below spread chart
   if(ICTPanel != NULL) {
      ICTPanel.SetPosition(10, 640);
   }
}

//+------------------------------------------------------------------+
//| Run full scan of all pairs                                        |
//+------------------------------------------------------------------+
void RunScan() {
   Print("[PAIRS] Starting scan of ", g_symbolCount, " symbols across ", g_tfCount, " timeframe(s)...");

   uint startTime = GetTickCount();

   int maxPairsPerTF = g_symbolCount * (g_symbolCount - 1) / 2;
   int maxTotal = maxPairsPerTF * g_tfCount;
   ArrayResize(g_results, maxTotal);
   g_resultCount = 0;

   string filterSymbol = Dashboard.GetSelectedSymbol();

   for(int tf = 0; tf < g_tfCount; tf++) {
      for(int i = 0; i < g_symbolCount - 1; i++) {
         if(filterSymbol != "" && g_symbols[i] != filterSymbol) {
            bool hasMatch = false;
            for(int j = i + 1; j < g_symbolCount; j++) {
               if(g_symbols[j] == filterSymbol) {
                  hasMatch = true;
                  break;
               }
            }
            if(!hasMatch) continue;
         }

         for(int j = i + 1; j < g_symbolCount; j++) {
            if(filterSymbol != "" && g_symbols[i] != filterSymbol && g_symbols[j] != filterSymbol) {
               continue;
            }

            PairResult result;

            if(PairsEngine.AnalyzePair(g_symbols[i], g_symbols[j], g_timeframes[tf], result)) {
               if(MathAbs(result.spearman) >= Inp_CorrThreshold * 0.8) {
                  g_results[g_resultCount] = result;
                  g_resultCount++;
               }
            }
         }
      }
   }

   ArrayResize(g_results, g_resultCount);

   if(Inp_SortBySignal) {
      Dashboard.SortBySignal(g_results, g_resultCount);
   } else {
      Dashboard.SortByCorrelation(g_results, g_resultCount);
   }

   int displayCount = MathMin(g_resultCount, Inp_MaxPairs);

   Dashboard.UpdateResults(g_results, displayCount);
   Dashboard.DrawSymbolButtons(g_symbols, g_symbolCount);

   g_lastScan = TimeCurrent();

   uint endTime = GetTickCount();
   Print("[PAIRS] Scan complete: ", g_resultCount, " pairs found in ", (endTime - startTime), "ms");

   if(Inp_AlertsEnabled || Inp_PushEnabled || Inp_EmailEnabled) {
      CheckAndAlert();
   }
}

//+------------------------------------------------------------------+
//| Check for signals and send alerts                                 |
//+------------------------------------------------------------------+
void CheckAndAlert() {
   static datetime lastAlertTime = 0;
   static string lastAlertPair = "";

   for(int i = 0; i < g_resultCount; i++) {
      if(g_results[i].signal != 0) {
         string pairKey = g_results[i].pairName + "|" + g_results[i].tfName;

         if(pairKey == lastAlertPair && TimeCurrent() - lastAlertTime < 300) {
            continue;
         }

         string msg = Dashboard.GenerateAlertMessage(g_results[i]);

         // Check ICT Kill Zone for better signals
         if(ICTPanel != NULL && ICTPanel.IsInKillZone()) {
            msg = "[KILL ZONE] " + msg;
         }

         if(Inp_AlertsEnabled) {
            Alert(msg);
         }

         if(Inp_PushEnabled) {
            SendNotification(msg);
         }

         if(Inp_EmailEnabled) {
            SendMail("D-LOGIC Pairs Signal", msg);
         }

         Print("[SIGNAL] ", msg);

         lastAlertTime = TimeCurrent();
         lastAlertPair = pairKey;
      }
   }
}

//+------------------------------------------------------------------+
//| Open charts for selected pair                                     |
//+------------------------------------------------------------------+
void OpenPairCharts(string sym1, string sym2, ENUM_TIMEFRAMES tf) {
   long chart1 = ChartOpen(sym1, tf);
   if(chart1 > 0) {
      ChartSetInteger(chart1, CHART_BRING_TO_TOP, true);
      Print("[PAIRS] Opened chart: ", sym1, " ", GetTFName(tf));
   }

   long chart2 = ChartOpen(sym2, tf);
   if(chart2 > 0) {
      ChartSetInteger(chart2, CHART_BRING_TO_TOP, true);
      Print("[PAIRS] Opened chart: ", sym2, " ", GetTFName(tf));
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
   Print("==============================================");
   Print("   D-LOGIC PROFESSIONAL DASHBOARD v3.00");
   Print("   Pairs Trading + ICT + Risk Management");
   Print("   Author: RafaB Dembski");
   Print("==============================================");

   // Initialize pairs engine
   PairsEngine = new C_PairsCore();
   PairsEngine.Configure(Inp_Lookback, Inp_CorrThreshold, Inp_ZScoreEntry, Inp_ZScoreExit);

   // Initialize dashboard
   Dashboard = new C_PairsDashboard();
   Dashboard.SetPosition(Inp_DashX, Inp_DashY);

   // Initialize position calculator
   Calculator = new C_PositionCalculator();
   Calculator.SetSymbol(_Symbol);
   Calculator.SetRiskParams(Inp_DefaultRisk, Inp_DefaultSL, Inp_DefaultTP);

   // Initialize spread chart
   SpreadChart = new C_SpreadChart();

   // Initialize ICT analysis
   ICTPanel = new C_ICTAnalysis();
   ICTPanel.SetSymbol(_Symbol);

   // Calculate panel positions
   CalculatePanelPositions();

   // Initialize timeframes and symbols
   InitializeTimeframes();
   InitializeSymbols();

   if(g_symbolCount < 2) {
      Alert("Error: Need at least 2 symbols to scan pairs. Check broker connection.");
      return INIT_FAILED;
   }

   Print("[PAIRS] Total possible pairs: ", g_symbolCount * (g_symbolCount - 1) / 2 * g_tfCount);

   // Initial scan
   RunScan();

   // Draw optional panels
   if(Inp_ShowCalculator) {
      Calculator.Calculate();
      Calculator.Draw();
      Print("[CALC] Position Calculator ready");
   }

   if(Inp_ShowSpreadChart && g_resultCount > 0) {
      // Set first pair as default for spread chart
      SpreadChart.SetPair(g_results[0].pair1, g_results[0].pair2);
      SpreadChart.Update(Inp_TF1);
      Print("[SPREAD] Spread Chart ready");
   }

   if(Inp_ShowICT) {
      ICTPanel.Update(Inp_TF1);
      if(Inp_DrawICTZones) {
         ICTPanel.DrawOnChart();
      }
      Print("[ICT] ICT Analysis ready - Session: ", ICTPanel.GetActiveSession());
   }

   EventSetTimer(g_scanInterval);

   Print("[SYSTEM] Initialization complete - Dashboard ready");
   Print("[SYSTEM] Keyboard shortcuts: C=Calculator, S=Spread, I=ICT");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();

   if(CheckPointer(ICTPanel) == POINTER_DYNAMIC) delete ICTPanel;
   if(CheckPointer(SpreadChart) == POINTER_DYNAMIC) delete SpreadChart;
   if(CheckPointer(Calculator) == POINTER_DYNAMIC) delete Calculator;
   if(CheckPointer(Dashboard) == POINTER_DYNAMIC) delete Dashboard;
   if(CheckPointer(PairsEngine) == POINTER_DYNAMIC) delete PairsEngine;

   ObjectsDeleteAll(0, "DL_PAIRS_");
   ObjectsDeleteAll(0, "DL_CALC_");
   ObjectsDeleteAll(0, "DL_SPREAD_");
   ObjectsDeleteAll(0, "DL_ICT_");

   string reasonText;
   switch(reason) {
      case REASON_PROGRAM:     reasonText = "Expert removed"; break;
      case REASON_REMOVE:      reasonText = "Expert removed from chart"; break;
      case REASON_RECOMPILE:   reasonText = "Recompiled"; break;
      case REASON_CHARTCHANGE: reasonText = "Symbol/timeframe changed"; break;
      case REASON_CHARTCLOSE:  reasonText = "Chart closed"; break;
      case REASON_PARAMETERS:  reasonText = "Inputs changed"; break;
      case REASON_ACCOUNT:     reasonText = "Account changed"; break;
      case REASON_TEMPLATE:    reasonText = "Template applied"; break;
      case REASON_INITFAILED:  reasonText = "Init failed"; break;
      case REASON_CLOSE:       reasonText = "Terminal closed"; break;
      default: reasonText = "Unknown";
   }

   Print("[SYSTEM] Shutdown: ", reasonText);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, Inp_TF1, 0);

   if(lastBar != currentBar) {
      lastBar = currentBar;

      // Update ICT on new bar
      if(ICTPanel != NULL && Inp_ShowICT) {
         ICTPanel.Update(Inp_TF1);
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer() {
   RunScan();

   // Update spread chart if visible
   if(SpreadChart != NULL && Inp_ShowSpreadChart && g_selectedPair1 != "") {
      SpreadChart.Update(Inp_TF1);
   }

   // Update ICT panel
   if(ICTPanel != NULL && Inp_ShowICT) {
      ICTPanel.Update(Inp_TF1);
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   // Handle object clicks
   if(id == CHARTEVENT_OBJECT_CLICK) {
      // Check Calculator clicks
      if(Calculator != NULL && Calculator.HandleClick(sparam)) {
         return;
      }

      // Check Spread Chart clicks
      if(SpreadChart != NULL && SpreadChart.HandleClick(sparam)) {
         return;
      }

      // Check ICT Panel clicks
      if(ICTPanel != NULL && ICTPanel.HandleClick(sparam)) {
         return;
      }

      // Check Dashboard clicks
      string pair1, pair2;
      ENUM_TIMEFRAMES tf;

      int action = Dashboard.HandleClick(sparam, pair1, pair2, tf);

      switch(action) {
         case 1:  // Scan button
            Print("[PAIRS] Manual scan triggered");
            RunScan();
            break;

         case 2:  // Row clicked - open charts and update panels
            Print("[PAIRS] Selected: ", pair1, " / ", pair2, " on ", GetTFName(tf));
            OpenPairCharts(pair1, pair2, tf);

            // Update selected pair
            g_selectedPair1 = pair1;
            g_selectedPair2 = pair2;

            // Update calculator with first symbol
            if(Calculator != NULL && Inp_ShowCalculator) {
               Calculator.SetSymbol(pair1);
               Calculator.Calculate();
               Calculator.Draw();
            }

            // Update spread chart with selected pair
            if(SpreadChart != NULL && Inp_ShowSpreadChart) {
               SpreadChart.SetPair(pair1, pair2);
               SpreadChart.Update(tf);
            }

            // Update ICT for first symbol
            if(ICTPanel != NULL && Inp_ShowICT) {
               ICTPanel.SetSymbol(pair1);
               ICTPanel.Update(tf);
            }
            break;

         case 3:  // Symbol filter changed
            Print("[PAIRS] Filter: ", Dashboard.GetSelectedSymbol());
            RunScan();
            break;
      }
   }

   // Handle edit box Enter key
   if(id == CHARTEVENT_OBJECT_ENDEDIT) {
      if(Calculator != NULL) {
         Calculator.HandleEndEdit(sparam);
      }
   }

   // Handle chart resize
   if(id == CHARTEVENT_CHART_CHANGE) {
      CalculatePanelPositions();

      if(g_resultCount > 0) {
         int displayCount = MathMin(g_resultCount, Inp_MaxPairs);
         Dashboard.UpdateResults(g_results, displayCount);
         Dashboard.DrawSymbolButtons(g_symbols, g_symbolCount);
      }

      if(Calculator != NULL && Inp_ShowCalculator) {
         Calculator.Calculate();
         Calculator.Draw();
      }

      if(SpreadChart != NULL && Inp_ShowSpreadChart) {
         SpreadChart.Draw();
      }

      if(ICTPanel != NULL && Inp_ShowICT) {
         ICTPanel.Draw();
      }
   }

   // Handle keyboard shortcuts
   if(id == CHARTEVENT_KEYDOWN) {
      // 'C' key to toggle calculator
      if(lparam == 'C' || lparam == 'c') {
         if(Calculator != NULL) {
            Calculator.ToggleVisibility();
            Print("[CALC] Calculator ", Calculator.IsVisible() ? "shown" : "hidden");
         }
      }

      // 'S' key to toggle spread chart
      if(lparam == 'S' || lparam == 's') {
         if(SpreadChart != NULL) {
            SpreadChart.ToggleVisibility();
            Print("[SPREAD] Spread Chart ", SpreadChart.IsVisible() ? "shown" : "hidden");
         }
      }

      // 'I' key to toggle ICT panel
      if(lparam == 'I' || lparam == 'i') {
         if(ICTPanel != NULL) {
            ICTPanel.ToggleVisibility();
            Print("[ICT] ICT Panel ", ICTPanel.IsVisible() ? "shown" : "hidden");
         }
      }

      // 'D' key to draw ICT zones on chart
      if(lparam == 'D' || lparam == 'd') {
         if(ICTPanel != NULL) {
            ICTPanel.DrawOnChart();
            Print("[ICT] Drew FVG and Order Block zones on chart");
         }
      }

      // 'R' key to refresh/rescan
      if(lparam == 'R' || lparam == 'r') {
         Print("[SYSTEM] Manual refresh triggered");
         RunScan();
      }
   }
}

//+------------------------------------------------------------------+
//| Tester function (for strategy testing)                            |
//+------------------------------------------------------------------+
double OnTester() {
   int signalCount = 0;
   double avgCorr = 0;

   for(int i = 0; i < g_resultCount; i++) {
      if(g_results[i].signal != 0) signalCount++;
      avgCorr += MathAbs(g_results[i].spearman);
   }

   if(g_resultCount > 0) avgCorr /= g_resultCount;

   return signalCount * avgCorr;
}

//+------------------------------------------------------------------+
