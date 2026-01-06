//+------------------------------------------------------------------+
//|                                              D-LOGIC_Pairs.mq5  |
//|                          Professional Pairs Trading Dashboard    |
//|                                        Author: RafaB Dembski    |
//|     Features: Spearman, Cointegration, Z-Score, Multi-Timeframe |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"
#property description "Pairs Trading Dashboard - Correlation Scanner with Z-Score & Cointegration Analysis"
#property version   "2.00"
#property strict

#include "DLogic_PairsDash.mqh"

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
input int      Inp_MaxPairs = 25;                // Maximum pairs to display
input int      Inp_DashX = 10;                   // Dashboard X position
input int      Inp_DashY = 30;                   // Dashboard Y position
input bool     Inp_SortBySignal = true;          // Sort by signal strength first

input group "=== ALERTS ==="
input bool     Inp_AlertsEnabled = true;         // Enable sound alerts
input bool     Inp_PushEnabled = false;          // Enable push notifications
input bool     Inp_EmailEnabled = false;         // Enable email alerts

// ============================================================
// GLOBAL OBJECTS
// ============================================================

C_PairsCore      *PairsEngine;
C_PairsDashboard *Dashboard;

string           g_symbols[];
int              g_symbolCount;
PairResult       g_results[];
int              g_resultCount;
datetime         g_lastScan;
int              g_scanInterval = 60;            // Seconds between auto-scans

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
      // Auto-load from broker
      int loaded = PairsEngine.LoadSymbolsFromBroker();
      PairsEngine.GetSymbols(g_symbols, g_symbolCount);
      Print("[PAIRS] Auto-loaded ", g_symbolCount, " symbols from broker");
   } else {
      // Use custom symbols
      ParseCustomSymbols();
      Print("[PAIRS] Loaded ", g_symbolCount, " custom symbols");
   }

   // Log loaded symbols
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
//| Run full scan of all pairs                                        |
//+------------------------------------------------------------------+
void RunScan() {
   Print("[PAIRS] Starting scan of ", g_symbolCount, " symbols across ", g_tfCount, " timeframe(s)...");

   uint startTime = GetTickCount();

   // Calculate max possible results
   int maxPairsPerTF = g_symbolCount * (g_symbolCount - 1) / 2;
   int maxTotal = maxPairsPerTF * g_tfCount;
   ArrayResize(g_results, maxTotal);
   g_resultCount = 0;

   // Get filter symbol
   string filterSymbol = Dashboard.GetSelectedSymbol();

   // Scan all timeframes
   for(int tf = 0; tf < g_tfCount; tf++) {
      // Scan all unique pairs
      for(int i = 0; i < g_symbolCount - 1; i++) {
         // Apply symbol filter
         if(filterSymbol != "" && g_symbols[i] != filterSymbol) {
            // Check if second symbol matches filter
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
            // Apply symbol filter for second symbol
            if(filterSymbol != "" && g_symbols[i] != filterSymbol && g_symbols[j] != filterSymbol) {
               continue;
            }

            PairResult result;

            if(PairsEngine.AnalyzePair(g_symbols[i], g_symbols[j], g_timeframes[tf], result)) {
               // Only add pairs with significant correlation
               if(MathAbs(result.spearman) >= Inp_CorrThreshold * 0.8) {
                  g_results[g_resultCount] = result;
                  g_resultCount++;
               }
            }
         }
      }
   }

   // Resize to actual count
   ArrayResize(g_results, g_resultCount);

   // Sort results
   if(Inp_SortBySignal) {
      // First sort by signal, then by Z-score for non-signals
      Dashboard.SortBySignal(g_results, g_resultCount);
   } else {
      Dashboard.SortByCorrelation(g_results, g_resultCount);
   }

   // Limit to max display
   int displayCount = MathMin(g_resultCount, Inp_MaxPairs);

   // Update dashboard
   Dashboard.UpdateResults(g_results, displayCount);

   // Draw symbol buttons
   Dashboard.DrawSymbolButtons(g_symbols, g_symbolCount);

   g_lastScan = TimeCurrent();

   uint endTime = GetTickCount();
   Print("[PAIRS] Scan complete: ", g_resultCount, " pairs found in ", (endTime - startTime), "ms");

   // Check for signals and alert
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

         // Avoid duplicate alerts within 5 minutes
         if(pairKey == lastAlertPair && TimeCurrent() - lastAlertTime < 300) {
            continue;
         }

         string msg = Dashboard.GenerateAlertMessage(g_results[i]);

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
   // Open first symbol chart
   long chart1 = ChartOpen(sym1, tf);
   if(chart1 > 0) {
      ChartSetInteger(chart1, CHART_BRING_TO_TOP, true);
      Print("[PAIRS] Opened chart: ", sym1, " ", GetTFName(tf));
   }

   // Open second symbol chart
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
   Print("   D-LOGIC PAIRS TRADING DASHBOARD v2.00");
   Print("   Spearman | Cointegration | Z-Score");
   Print("   Author: RafaB Dembski");
   Print("==============================================");

   // Initialize engine
   PairsEngine = new C_PairsCore();
   PairsEngine.Configure(Inp_Lookback, Inp_CorrThreshold, Inp_ZScoreEntry, Inp_ZScoreExit);

   // Initialize dashboard
   Dashboard = new C_PairsDashboard();
   Dashboard.SetPosition(Inp_DashX, Inp_DashY);

   // Initialize timeframes
   InitializeTimeframes();

   // Initialize symbols
   InitializeSymbols();

   if(g_symbolCount < 2) {
      Alert("Error: Need at least 2 symbols to scan pairs. Check broker connection.");
      return INIT_FAILED;
   }

   Print("[PAIRS] Total possible pairs: ", g_symbolCount * (g_symbolCount - 1) / 2 * g_tfCount);

   // Initial scan
   RunScan();

   // Set timer for periodic updates
   EventSetTimer(g_scanInterval);

   Print("[PAIRS] Initialization complete - Dashboard ready");
   Print("[PAIRS] Next auto-scan in ", g_scanInterval, " seconds");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();

   if(CheckPointer(Dashboard) == POINTER_DYNAMIC) delete Dashboard;
   if(CheckPointer(PairsEngine) == POINTER_DYNAMIC) delete PairsEngine;

   ObjectsDeleteAll(0, "DL_PAIRS_");

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

   Print("[PAIRS] Shutdown: ", reasonText);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   // Check for new bar on primary timeframe
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, Inp_TF1, 0);

   if(lastBar != currentBar) {
      lastBar = currentBar;
      // Could trigger rescan on new bar (optional - may be resource intensive)
      // RunScan();
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer() {
   // Periodic rescan
   RunScan();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      string pair1, pair2;
      ENUM_TIMEFRAMES tf;

      int action = Dashboard.HandleClick(sparam, pair1, pair2, tf);

      switch(action) {
         case 1:  // Scan button
            Print("[PAIRS] Manual scan triggered");
            RunScan();
            break;

         case 2:  // Row clicked - open charts
            Print("[PAIRS] Selected: ", pair1, " / ", pair2, " on ", GetTFName(tf));
            OpenPairCharts(pair1, pair2, tf);
            break;

         case 3:  // Symbol filter changed
            Print("[PAIRS] Filter: ", Dashboard.GetSelectedSymbol());
            RunScan();  // Rescan with filter
            break;
      }
   }

   // Handle chart resize
   if(id == CHARTEVENT_CHART_CHANGE) {
      // Redraw dashboard
      if(g_resultCount > 0) {
         int displayCount = MathMin(g_resultCount, Inp_MaxPairs);
         Dashboard.UpdateResults(g_results, displayCount);
         Dashboard.DrawSymbolButtons(g_symbols, g_symbolCount);
      }
   }
}

//+------------------------------------------------------------------+
//| Tester function (for strategy testing)                            |
//+------------------------------------------------------------------+
double OnTester() {
   // Return metric for optimization
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
