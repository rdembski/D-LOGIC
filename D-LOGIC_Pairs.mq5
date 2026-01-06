//+------------------------------------------------------------------+
//|                                              D-LOGIC_Pairs.mq5  |
//|                          Professional Pairs Trading Dashboard    |
//|                                        Author: RafaB Dembski    |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"
#property description "Pairs Trading Dashboard - Correlation Scanner with Z-Score & Stationarity Analysis"
#property version   "1.00"
#property strict

#include "DLogic_PairsDash.mqh"

// ============================================================
// INPUT PARAMETERS
// ============================================================

input group "=== PAIRS CONFIGURATION ==="
input string   Inp_Pairs = "EURUSD,GBPUSD,USDJPY,USDCHF,AUDUSD,USDCAD,NZDUSD,EURGBP,EURJPY,GBPJPY"; // Symbols to scan (comma separated)
input bool     Inp_ScanAllPairs = false;  // Scan all available major pairs

input group "=== ANALYSIS SETTINGS ==="
input int      Inp_Lookback = 100;        // Lookback period (bars)
input double   Inp_CorrThreshold = 0.80;  // Correlation threshold (0.0-1.0)
input double   Inp_ZScoreEntry = 2.0;     // Z-Score for entry signal
input double   Inp_ZScoreExit = 0.5;      // Z-Score for exit signal

input group "=== TIMEFRAME SETTINGS ==="
input ENUM_TIMEFRAMES Inp_TF1 = PERIOD_H1;  // Primary timeframe
input ENUM_TIMEFRAMES Inp_TF2 = PERIOD_H4;  // Secondary timeframe (for confirmation)

input group "=== TECHNICAL FILTERS ==="
input int      Inp_RSIPeriod = 14;        // RSI Period
input int      Inp_MAPeriod = 20;         // MA Period for trend
input bool     Inp_UseRSIFilter = true;   // Use RSI confirmation

input group "=== DISPLAY SETTINGS ==="
input int      Inp_MaxPairs = 20;         // Maximum pairs to display
input int      Inp_DashX = 10;            // Dashboard X position
input int      Inp_DashY = 50;            // Dashboard Y position
input bool     Inp_SortBySignal = true;   // Sort by signal strength

input group "=== ALERTS ==="
input bool     Inp_AlertsEnabled = true;  // Enable alerts
input bool     Inp_PushEnabled = false;   // Enable push notifications

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
int              g_scanInterval = 60;  // Seconds between auto-scans

// ============================================================
// PREDEFINED MAJOR PAIRS
// ============================================================
string MajorPairs[] = {
   "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD", "NZDUSD",
   "EURGBP", "EURJPY", "GBPJPY", "EURAUD", "EURCAD", "EURCHF", "EURNZD",
   "GBPAUD", "GBPCAD", "GBPCHF", "GBPNZD", "AUDJPY", "AUDNZD", "AUDCAD",
   "AUDCHF", "CADJPY", "CADCHF", "CHFJPY", "NZDJPY", "NZDCAD", "NZDCHF"
};

//+------------------------------------------------------------------+
//| Parse symbols from input string                                   |
//+------------------------------------------------------------------+
void ParseSymbols() {
   if(Inp_ScanAllPairs) {
      // Use predefined major pairs
      g_symbolCount = ArraySize(MajorPairs);
      ArrayResize(g_symbols, g_symbolCount);
      for(int i = 0; i < g_symbolCount; i++) {
         g_symbols[i] = MajorPairs[i];
      }
   } else {
      // Parse from input string
      string pairs = Inp_Pairs;
      StringReplace(pairs, " ", "");

      string parts[];
      g_symbolCount = StringSplit(pairs, ',', parts);

      ArrayResize(g_symbols, g_symbolCount);
      for(int i = 0; i < g_symbolCount; i++) {
         g_symbols[i] = parts[i];
      }
   }

   // Validate symbols
   int validCount = 0;
   for(int i = 0; i < g_symbolCount; i++) {
      if(SymbolSelect(g_symbols[i], true)) {
         if(validCount != i) {
            g_symbols[validCount] = g_symbols[i];
         }
         validCount++;
      } else {
         Print("[PAIRS] Symbol not available: ", g_symbols[i]);
      }
   }
   g_symbolCount = validCount;
   ArrayResize(g_symbols, g_symbolCount);

   Print("[PAIRS] Loaded ", g_symbolCount, " symbols for scanning");
}

//+------------------------------------------------------------------+
//| Generate all unique pairs from symbols                            |
//+------------------------------------------------------------------+
void GeneratePairCombinations() {
   // Calculate number of pairs: n*(n-1)/2
   int maxPairs = g_symbolCount * (g_symbolCount - 1) / 2;
   ArrayResize(g_results, maxPairs);
   g_resultCount = 0;
}

//+------------------------------------------------------------------+
//| Run full scan of all pairs                                        |
//+------------------------------------------------------------------+
void RunScan() {
   Print("[PAIRS] Starting scan of ", g_symbolCount, " symbols...");

   datetime startTime = GetTickCount();

   g_resultCount = 0;
   int maxPairs = g_symbolCount * (g_symbolCount - 1) / 2;
   ArrayResize(g_results, maxPairs);

   // Scan all unique pairs
   for(int i = 0; i < g_symbolCount - 1; i++) {
      for(int j = i + 1; j < g_symbolCount; j++) {
         PairResult result;

         if(PairsEngine.AnalyzePair(g_symbols[i], g_symbols[j], Inp_TF1, result)) {
            // Only add pairs with significant correlation
            if(MathAbs(result.correlation) >= Inp_CorrThreshold * 0.8) {
               g_results[g_resultCount] = result;
               g_resultCount++;
            }
         }
      }
   }

   // Resize to actual count
   ArrayResize(g_results, g_resultCount);

   // Sort results
   if(Inp_SortBySignal) {
      Dashboard.SortBySignal(g_results, g_resultCount);
   } else {
      Dashboard.SortByCorrelation(g_results, g_resultCount, true);
   }

   // Limit to max display
   int displayCount = MathMin(g_resultCount, Inp_MaxPairs);

   // Update dashboard
   Dashboard.UpdateResults(g_results, displayCount);

   g_lastScan = TimeCurrent();

   datetime endTime = GetTickCount();
   Print("[PAIRS] Scan complete: ", g_resultCount, " pairs found in ", (endTime - startTime), "ms");

   // Check for signals and alert
   if(Inp_AlertsEnabled) {
      CheckAndAlert();
   }
}

//+------------------------------------------------------------------+
//| Check for signals and send alerts                                 |
//+------------------------------------------------------------------+
void CheckAndAlert() {
   for(int i = 0; i < g_resultCount; i++) {
      if(g_results[i].signal != 0) {
         string msg = "PAIRS SIGNAL: " + g_results[i].symbol1 + "/" + g_results[i].symbol2 +
                     " - " + g_results[i].signalText +
                     " (Z: " + DoubleToString(g_results[i].zscore, 2) +
                     ", Corr: " + DoubleToString(g_results[i].correlation, 3) + ")";

         if(Inp_AlertsEnabled) {
            Alert(msg);
         }

         if(Inp_PushEnabled) {
            SendNotification(msg);
         }

         Print("[SIGNAL] ", msg);
      }
   }
}

//+------------------------------------------------------------------+
//| Open charts for selected pair                                     |
//+------------------------------------------------------------------+
void OpenPairCharts(string sym1, string sym2) {
   // Open first symbol chart
   long chart1 = ChartOpen(sym1, Inp_TF1);
   if(chart1 > 0) {
      ChartSetInteger(chart1, CHART_BRING_TO_TOP, true);
      Print("[PAIRS] Opened chart: ", sym1);
   }

   // Open second symbol chart
   long chart2 = ChartOpen(sym2, Inp_TF1);
   if(chart2 > 0) {
      ChartSetInteger(chart2, CHART_BRING_TO_TOP, true);
      Print("[PAIRS] Opened chart: ", sym2);
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
   Print("===========================================");
   Print("  D-LOGIC PAIRS TRADING SCANNER v1.00");
   Print("  Correlation & Statistical Arbitrage");
   Print("===========================================");

   // Initialize engine
   PairsEngine = new C_PairsCore();
   PairsEngine.Configure(Inp_Lookback, Inp_CorrThreshold, Inp_ZScoreEntry,
                         Inp_ZScoreExit, Inp_RSIPeriod, Inp_MAPeriod);

   // Initialize dashboard
   Dashboard = new C_PairsDashboard();
   Dashboard.SetPosition(Inp_DashX, Inp_DashY);

   // Parse symbols
   ParseSymbols();

   if(g_symbolCount < 2) {
      Alert("Error: Need at least 2 symbols to scan pairs");
      return INIT_FAILED;
   }

   // Generate pair combinations
   GeneratePairCombinations();

   // Initial scan
   RunScan();

   // Set timer for periodic updates
   EventSetTimer(g_scanInterval);

   Print("[PAIRS] Initialization complete");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();

   if(CheckPointer(Dashboard) == POINTER_DYNAMIC) delete Dashboard;
   if(CheckPointer(PairsEngine) == POINTER_DYNAMIC) delete PairsEngine;

   Print("[PAIRS] Shutdown complete");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   // Auto-rescan on new bar (optional - can be resource intensive)
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, Inp_TF1, 0);

   if(lastBar != currentBar) {
      lastBar = currentBar;
      // Optionally trigger rescan on new bar
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
      // Check for scan button
      if(Dashboard.IsScanClicked(sparam)) {
         Print("[PAIRS] Manual scan triggered");
         RunScan();
         return;
      }

      // Check for row click
      string pair1, pair2;
      if(Dashboard.HandleClick(sparam, pair1, pair2)) {
         Print("[PAIRS] Selected: ", pair1, " / ", pair2);
         OpenPairCharts(pair1, pair2);
      }
   }

   // Handle chart resize
   if(id == CHARTEVENT_CHART_CHANGE) {
      // Redraw dashboard
      if(g_resultCount > 0) {
         int displayCount = MathMin(g_resultCount, Inp_MaxPairs);
         Dashboard.UpdateResults(g_results, displayCount);
      }
   }
}

//+------------------------------------------------------------------+
//| Tester function (for strategy testing)                            |
//+------------------------------------------------------------------+
double OnTester() {
   // Return metric for optimization
   int signalCount = 0;
   for(int i = 0; i < g_resultCount; i++) {
      if(g_results[i].signal != 0) signalCount++;
   }
   return signalCount;
}
