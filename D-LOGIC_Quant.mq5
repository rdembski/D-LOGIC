//+------------------------------------------------------------------+
//|                                              D-LOGIC_Quant.mq5   |
//|              D-LOGIC Professional Pairs Trading Dashboard         |
//|                                        Author: Rafał Dembski     |
//|                                                                   |
//|  Institutional-Grade Statistical Arbitrage System                 |
//|  - OLS Regression Based Hedge Ratios                              |
//|  - Z-Score Mean Reversion Strategy                                |
//|  - Cointegration Testing (ADF + Zero-Crossing)                    |
//|  - Dollar Neutral Position Sizing                                 |
//|  - Dark/Neon Professional UI                                      |
//+------------------------------------------------------------------+
#property copyright "Rafał Dembski"
#property description "D-LOGIC Quant Dashboard - Statistical Arbitrage Engine"
#property version   "4.10"
#property strict

#include "DLogic_Engine.mqh"
#include "DLogic_TradeManager.mqh"
#include "DLogic_Dashboard.mqh"

// ============================================================
// INPUT PARAMETERS
// ============================================================

input group "=== STATISTICAL ENGINE ==="
input int      Inp_Lookback = 200;              // Rolling Window (bars)
input double   Inp_ZScoreEntry = 2.0;           // Z-Score Entry Threshold
input double   Inp_ZScoreExit = 0.5;            // Z-Score Exit Threshold
input double   Inp_ZScoreStop = 3.5;            // Z-Score Stop-Loss Threshold
input double   Inp_MinRSquared = 0.60;          // Minimum R² for Cointegration
input int      Inp_MinZeroCross = 10;           // Min Zero Crossings

input group "=== TIMEFRAME SETTINGS ==="
input ENUM_TIMEFRAMES Inp_AnalysisTF = PERIOD_H4;     // Analysis Timeframe
input ENUM_TIMEFRAMES Inp_ExecutionTF = PERIOD_M15;   // Execution Timeframe

input group "=== RISK MANAGEMENT ==="
input double   Inp_RiskPercent = 1.0;           // Risk per Trade (%)
input double   Inp_MaxPositionValue = 10000;    // Max Position Value ($)
input int      Inp_MagicNumber = 20240107;      // Magic Number

input group "=== SCANNER SETTINGS ==="
input int      Inp_MaxPairs = 20;               // Maximum Pairs to Display
input int      Inp_ScanInterval = 60;           // Scan Interval (seconds)
input bool     Inp_AutoScan = true;             // Enable Auto-Scan

input group "=== DISPLAY SETTINGS ==="
input int      Inp_DashX = 10;                  // Dashboard X Position
input int      Inp_DashY = 30;                  // Dashboard Y Position

input group "=== ALERT SETTINGS ==="
input bool     Inp_AlertsEnabled = true;        // Enable Alerts
input double   Inp_AlertZThreshold = 2.0;       // Alert Z-Score Threshold
input double   Inp_AlertStrength = 60;          // Alert Min Signal Strength (%)

// ============================================================
// PREDEFINED FOREX PAIRS FOR SCANNING
// ============================================================
string g_pairSymbols[] = {
   "EURUSD", "GBPUSD", "USDJPY", "USDCHF",
   "AUDUSD", "USDCAD", "NZDUSD", "EURGBP",
   "EURJPY", "GBPJPY", "AUDJPY", "EURAUD",
   "EURCHF", "GBPCHF", "AUDNZD", "CADJPY"
};

// ============================================================
// GLOBAL OBJECTS
// ============================================================

CPairsEngine     *Engine;
CTradeManager    *TradeManager;
CDashboard       *Dashboard;

SPairResult      g_results[];
int              g_resultCount;
datetime         g_lastScan;

// Spread history for selected pair
double           g_spreadHistory[];
double           g_zScoreHistory[];
int              g_historySize;

// Performance tracking
double           g_maxDrawdown;
double           g_peakEquity;
int              g_lastTradeCount;      // Track position count for closure detection
double           g_lastEquity;          // Track equity for P&L calculation

//+------------------------------------------------------------------+
//| Initialize symbols - validate availability                        |
//+------------------------------------------------------------------+
int InitializeSymbols(string &validSymbols[]) {
   int count = 0;
   int totalPairs = ArraySize(g_pairSymbols);

   ArrayResize(validSymbols, totalPairs);

   for(int i = 0; i < totalPairs; i++) {
      string sym = g_pairSymbols[i];

      // Try different broker suffixes
      string variants[] = {sym, sym + "+", sym + ".raw", sym + ".ecn", sym + "m"};

      for(int v = 0; v < ArraySize(variants); v++) {
         if(SymbolSelect(variants[v], true)) {
            double bid = SymbolInfoDouble(variants[v], SYMBOL_BID);
            if(bid > 0) {
               validSymbols[count] = variants[v];
               count++;
               break;
            }
         }
      }
   }

   ArrayResize(validSymbols, count);
   return count;
}

//+------------------------------------------------------------------+
//| Run full pair scan                                                |
//+------------------------------------------------------------------+
void RunPairScan() {
   Print("[SCAN] Starting pairs scan...");
   uint startTime = GetTickCount();

   string symbols[];
   int symCount = InitializeSymbols(symbols);

   if(symCount < 2) {
      Print("[SCAN] Insufficient symbols: ", symCount);
      return;
   }

   // Calculate all pair combinations
   int maxPairs = symCount * (symCount - 1) / 2;
   ArrayResize(g_results, maxPairs);
   g_resultCount = 0;

   for(int i = 0; i < symCount - 1 && g_resultCount < Inp_MaxPairs * 2; i++) {
      for(int j = i + 1; j < symCount && g_resultCount < Inp_MaxPairs * 2; j++) {
         SPairResult result;

         if(Engine.AnalyzePair(symbols[i], symbols[j], Inp_AnalysisTF, result)) {
            // Only include pairs with reasonable correlation
            if(result.rSquared >= Inp_MinRSquared * 0.7) {
               g_results[g_resultCount] = result;
               g_resultCount++;
            }
         }
      }
   }

   ArrayResize(g_results, g_resultCount);

   // Sort by absolute Z-Score (best opportunities first)
   SortResultsByZScore();

   // Limit to max display
   if(g_resultCount > Inp_MaxPairs) {
      g_resultCount = Inp_MaxPairs;
      ArrayResize(g_results, g_resultCount);
   }

   // Update dashboard
   Dashboard.UpdateResults(g_results, g_resultCount);
   Dashboard.SortByZScore();
   Dashboard.Draw();

   g_lastScan = TimeCurrent();

   uint elapsed = GetTickCount() - startTime;
   Print("[SCAN] Complete: ", g_resultCount, " pairs analyzed in ", elapsed, "ms");

   // Log top opportunities
   for(int i = 0; i < MathMin(3, g_resultCount); i++) {
      Print("  #", i+1, ": ", g_results[i].pairName,
            " Z=", DoubleToString(g_results[i].zScore, 2),
            " R²=", DoubleToString(g_results[i].rSquared * 100, 0), "%",
            " Coint=", g_results[i].isCointegrated ? "YES" : "NO",
            " -> ", g_results[i].signalText);
   }
}

//+------------------------------------------------------------------+
//| Sort results by Z-Score (absolute value, descending)              |
//+------------------------------------------------------------------+
void SortResultsByZScore() {
   for(int i = 0; i < g_resultCount - 1; i++) {
      for(int j = 0; j < g_resultCount - i - 1; j++) {
         if(MathAbs(g_results[j].zScore) < MathAbs(g_results[j + 1].zScore)) {
            SPairResult temp = g_results[j];
            g_results[j] = g_results[j + 1];
            g_results[j + 1] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update spread history for selected pair                           |
//+------------------------------------------------------------------+
void UpdateSpreadHistory(string symbolA, string symbolB, double beta) {
   g_historySize = Engine.GetLookback();
   ArrayResize(g_spreadHistory, g_historySize);
   ArrayResize(g_zScoreHistory, g_historySize);

   double closesA[], closesB[];
   ArraySetAsSeries(closesA, true);
   ArraySetAsSeries(closesB, true);

   if(CopyClose(symbolA, Inp_AnalysisTF, 0, g_historySize, closesA) < g_historySize) return;
   if(CopyClose(symbolB, Inp_AnalysisTF, 0, g_historySize, closesB) < g_historySize) return;

   // Calculate spread series
   double sum = 0;
   for(int i = 0; i < g_historySize; i++) {
      g_spreadHistory[i] = MathLog(closesA[i]) - beta * MathLog(closesB[i]);
      sum += g_spreadHistory[i];
   }
   double mean = sum / g_historySize;

   // Calculate std dev
   double sumSq = 0;
   for(int i = 0; i < g_historySize; i++) {
      sumSq += MathPow(g_spreadHistory[i] - mean, 2);
   }
   double stdDev = MathSqrt(sumSq / (g_historySize - 1));

   // Calculate Z-Score series
   for(int i = 0; i < g_historySize; i++) {
      if(stdDev > 1e-10) {
         g_zScoreHistory[i] = (g_spreadHistory[i] - mean) / stdDev;
      } else {
         g_zScoreHistory[i] = 0;
      }
   }

   Dashboard.UpdateSpreadHistory(g_spreadHistory, g_zScoreHistory, g_historySize);
}

//+------------------------------------------------------------------+
//| Update drawdown tracking                                          |
//+------------------------------------------------------------------+
void UpdateDrawdown() {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(equity > g_peakEquity) {
      g_peakEquity = equity;
   }

   if(g_peakEquity > 0) {
      double currentDD = (g_peakEquity - equity) / g_peakEquity * 100;
      if(currentDD > g_maxDrawdown) {
         g_maxDrawdown = currentDD;
      }
   }
}

//+------------------------------------------------------------------+
//| Check and execute signals                                         |
//+------------------------------------------------------------------+
void CheckSignals() {
   for(int i = 0; i < g_resultCount; i++) {
      SPairResult result = g_results[i];

      // Skip if not cointegrated
      if(!result.isCointegrated) continue;

      // Skip if already has position
      if(TradeManager.HasPosition(result.symbolA, result.symbolB)) continue;

      // Record any meaningful signals (±1 or ±2)
      if(result.signal != 0) {
         Dashboard.RecordSignal(result.pairName, result.signal,
                                result.zScore, Dashboard.GetSignalStrength());
      }

      // Check for strong signals
      if(result.signal == 2) {
         // Long spread: BUY A, SELL B (Z < -2)
         Print("[SIGNAL] Long Spread opportunity: ", result.pairName, " Z=", result.zScore);

         if(TradeManager.OpenPairsPosition(result.symbolA, result.symbolB,
                                           result.beta, result.zScore, true)) {
            Alert("Opened LONG SPREAD: ", result.pairName);
         }
      }
      else if(result.signal == -2) {
         // Short spread: SELL A, BUY B (Z > +2)
         Print("[SIGNAL] Short Spread opportunity: ", result.pairName, " Z=", result.zScore);

         if(TradeManager.OpenPairsPosition(result.symbolA, result.symbolB,
                                           result.beta, result.zScore, false)) {
            Alert("Opened SHORT SPREAD: ", result.pairName);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
   Print("=======================================================");
   Print("  D-LOGIC QUANT DASHBOARD v4.10");
   Print("  Statistical Arbitrage Engine");
   Print("  Author: Rafał Dembski");
   Print("-------------------------------------------------------");
   Print("  Features: Performance Tracking, Signal History,");
   Print("           Equity Curve, Alert System, Regime Detection");
   Print("=======================================================");

   // Initialize engine
   Engine = new CPairsEngine();
   Engine.Configure(Inp_Lookback, Inp_ZScoreEntry, Inp_ZScoreExit, Inp_ZScoreStop,
                    Inp_MinRSquared, Inp_MinZeroCross);

   // Initialize trade manager
   TradeManager = new CTradeManager();
   TradeManager.Configure(Inp_RiskPercent, Inp_MaxPositionValue, Inp_MagicNumber);

   // Initialize dashboard
   Dashboard = new CDashboard();
   Dashboard.SetPosition(Inp_DashX, Inp_DashY);
   Dashboard.ConfigureAlerts(Inp_AlertsEnabled, Inp_AlertZThreshold, Inp_AlertStrength);

   // Initialize tracking
   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_lastEquity = g_peakEquity;
   g_maxDrawdown = 0;
   g_resultCount = 0;
   g_lastTradeCount = 0;

   // Initial scan
   RunPairScan();

   // Set timer for auto-scan
   if(Inp_AutoScan) {
      EventSetTimer(Inp_ScanInterval);
   }

   Print("[SYSTEM] Initialization complete");
   Print("[SYSTEM] Keyboard: Q=Toggle | R=Refresh | X=Close All | A=Toggle Alerts | S=Reset Stats");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();

   if(CheckPointer(Dashboard) == POINTER_DYNAMIC) delete Dashboard;
   if(CheckPointer(TradeManager) == POINTER_DYNAMIC) delete TradeManager;
   if(CheckPointer(Engine) == POINTER_DYNAMIC) delete Engine;

   ObjectsDeleteAll(0, "DL_QUANT_");

   string reasonText;
   switch(reason) {
      case REASON_PROGRAM:     reasonText = "Expert removed"; break;
      case REASON_REMOVE:      reasonText = "Expert removed from chart"; break;
      case REASON_RECOMPILE:   reasonText = "Recompiled"; break;
      case REASON_CHARTCHANGE: reasonText = "Symbol/TF changed"; break;
      case REASON_CHARTCLOSE:  reasonText = "Chart closed"; break;
      case REASON_PARAMETERS:  reasonText = "Inputs changed"; break;
      case REASON_ACCOUNT:     reasonText = "Account changed"; break;
      default: reasonText = "Unknown";
   }

   Print("[SYSTEM] Shutdown: ", reasonText);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   // Update position management
   TradeManager.ManagePositions(Inp_ZScoreExit, Inp_ZScoreStop);

   // Update drawdown tracking
   UpdateDrawdown();

   // Update dashboard info
   double unrealizedPL = TradeManager.GetTotalUnrealizedPL();
   int positions = TradeManager.GetPositionCount();

   // Check for closed positions and record results
   if(positions < g_lastTradeCount) {
      // Position was closed - calculate approximate P&L
      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      double tradePL = currentEquity - g_lastEquity - unrealizedPL;

      // Record result in dashboard for performance tracking
      Dashboard.RecordTradeResult(tradePL);

      Print("[TRADE] Position closed. P&L: ", DoubleToString(tradePL, 2));
      g_lastEquity = currentEquity - unrealizedPL;  // Update base equity
   }
   g_lastTradeCount = positions;

   // Get active beta if position exists
   double activeBeta = 0;
   if(positions > 0) {
      SPairPosition pos;
      if(TradeManager.GetPosition(0, pos)) {
         activeBeta = pos.beta;
      }
   }

   Dashboard.UpdateInfo(unrealizedPL, positions, g_maxDrawdown, activeBeta);
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer() {
   // Auto-scan at interval
   RunPairScan();

   // Check for new signals (semi-auto mode)
   // Uncomment below for fully automatic execution:
   // CheckSignals();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   // Handle object clicks
   if(id == CHARTEVENT_OBJECT_CLICK) {
      string symbolA, symbolB;
      double beta;

      int action = Dashboard.HandleClick(sparam, symbolA, symbolB, beta);

      switch(action) {
         case 1:  // Scan button
            Print("[UI] Manual scan triggered");
            RunPairScan();
            break;

         case 2:  // Execute button
            if(symbolA != "" && symbolB != "") {
               double zScore;
               if(Dashboard.GetSelectedPair(symbolA, symbolB, beta, zScore)) {
                  bool isLong = (zScore < 0);

                  Print("[UI] Executing hedge: ", symbolA, "/", symbolB,
                        " Beta=", beta, " Z=", zScore,
                        " Direction=", (isLong ? "LONG" : "SHORT"), " SPREAD");

                  if(TradeManager.OpenPairsPosition(symbolA, symbolB, beta, zScore, isLong)) {
                     Alert("Opened ", (isLong ? "LONG" : "SHORT"), " SPREAD: ", symbolA, "/", symbolB);
                  }
               }
            }
            break;

         case 3:  // Close all button
            Print("[UI] Closing all positions");
            TradeManager.CloseAllPositions("User Request");
            break;

         case 4:  // Row selected
            Print("[UI] Selected pair: ", symbolA, "/", symbolB);
            UpdateSpreadHistory(symbolA, symbolB, beta);
            Dashboard.Draw();
            break;
      }
   }

   // Handle chart resize
   if(id == CHARTEVENT_CHART_CHANGE) {
      Dashboard.Draw();
   }

   // Handle keyboard
   if(id == CHARTEVENT_KEYDOWN) {
      // Q = Toggle dashboard
      if(lparam == 'Q' || lparam == 'q') {
         Dashboard.ToggleVisibility();
         Print("[UI] Dashboard ", Dashboard.IsVisible() ? "shown" : "hidden");
      }

      // R = Refresh scan
      if(lparam == 'R' || lparam == 'r') {
         Print("[UI] Manual refresh");
         RunPairScan();
      }

      // X = Close all
      if(lparam == 'X' || lparam == 'x') {
         Print("[UI] Emergency close all");
         TradeManager.CloseAllPositions("Emergency Close");
      }

      // A = Toggle alerts
      if(lparam == 'A' || lparam == 'a') {
         bool currentState = Dashboard.AreAlertsEnabled();
         Dashboard.ConfigureAlerts(!currentState, Inp_AlertZThreshold, Inp_AlertStrength);
         Print("[UI] Alerts ", !currentState ? "ENABLED" : "DISABLED");
         Dashboard.Draw();
      }

      // S = Reset stats
      if(lparam == 'S' || lparam == 's') {
         Dashboard.ResetStats();
         g_lastEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         Print("[UI] Performance stats reset");
         Dashboard.Draw();
      }
   }
}

//+------------------------------------------------------------------+
//| Tester function                                                   |
//+------------------------------------------------------------------+
double OnTester() {
   // Return profit factor as optimization criterion
   double profit = TesterStatistics(STAT_PROFIT);
   double loss = MathAbs(TesterStatistics(STAT_GROSS_LOSS));

   if(loss > 0) {
      return profit / loss;
   }

   return profit;
}

//+------------------------------------------------------------------+
