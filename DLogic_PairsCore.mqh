//+------------------------------------------------------------------+
//|                                            DLogic_PairsCore.mqh |
//|                          Project: D-LOGIC Pairs Trading Scanner |
//|                                        Author: RafaB Dembski    |
//|                Core Engine: Correlation, Z-Score, Cointegration |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"
#property strict

//+------------------------------------------------------------------+
//| Pair Analysis Result Structure                                    |
//+------------------------------------------------------------------+
struct PairResult {
   string   pair1;              // First symbol
   string   pair2;              // Second symbol
   string   pairName;           // Combined name (GBPUSD-EURUSD)
   ENUM_TIMEFRAMES timeframe;   // Timeframe
   string   tfName;             // TF display name (H4, M30, etc.)

   // Correlation
   double   spearman;           // Spearman correlation coefficient
   double   pearson;            // Pearson correlation
   string   corrType;           // "Pos" or "Neg"

   // Z-Score & Spread
   double   zscore;             // Current Z-Score of spread
   double   spread;             // Current spread value
   double   spreadMean;         // Mean of spread
   double   spreadStd;          // Std deviation of spread

   // Cointegration (Engle-Granger)
   bool     isCointegrated;     // Cointegration test result
   double   coint_d;            // d coefficient
   double   coint_k;            // k (hedge ratio)
   double   coint_m;            // m (mean)

   // Stationarity
   bool     isStationary;       // ADF test result
   double   adfStat;            // ADF statistic
   double   halfLife;           // Mean reversion half-life

   // Signal
   int      signal;             // Signal: 1=BUY, -1=SELL, 0=NONE
   string   signalText;         // Signal description

   // Prices
   double   price1;             // Current price of pair1
   double   price2;             // Current price of pair2

   // Additional metrics
   double   adr1;               // ADR of pair1
   double   adr2;               // ADR of pair2
   double   adrPct;             // ADR percentage used today

   datetime lastUpdate;         // Last calculation time
};

//+------------------------------------------------------------------+
//| Pairs Trading Core Engine                                         |
//+------------------------------------------------------------------+
class C_PairsCore {
private:
   int      m_lookback;         // Lookback period for calculations
   double   m_corrThreshold;    // Correlation threshold (abs value)
   double   m_zscoreEntry;      // Z-Score threshold for entry
   double   m_zscoreExit;       // Z-Score threshold for exit
   int      m_adfLag;           // ADF test lag

   string   m_availableSymbols[];  // Symbols from broker
   int      m_symbolCount;

   //+------------------------------------------------------------------+
   //| Get prices array                                                  |
   //+------------------------------------------------------------------+
   bool GetPrices(string symbol, ENUM_TIMEFRAMES tf, int count, double &prices[]) {
      ArraySetAsSeries(prices, true);
      int copied = CopyClose(symbol, tf, 0, count, prices);
      return (copied >= count);
   }

   //+------------------------------------------------------------------+
   //| Calculate log returns                                             |
   //+------------------------------------------------------------------+
   void CalculateLogReturns(double &prices[], double &returns[], int count) {
      ArrayResize(returns, count - 1);
      for(int i = 0; i < count - 1; i++) {
         if(prices[i+1] > 0)
            returns[i] = MathLog(prices[i] / prices[i+1]);
         else
            returns[i] = 0;
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate ranks for Spearman correlation                          |
   //+------------------------------------------------------------------+
   void CalculateRanks(double &data[], double &ranks[], int n) {
      ArrayResize(ranks, n);

      // Create sorted index array
      int indices[];
      ArrayResize(indices, n);
      for(int i = 0; i < n; i++) indices[i] = i;

      // Sort indices by data values (bubble sort for simplicity)
      for(int i = 0; i < n - 1; i++) {
         for(int j = i + 1; j < n; j++) {
            if(data[indices[i]] > data[indices[j]]) {
               int temp = indices[i];
               indices[i] = indices[j];
               indices[j] = temp;
            }
         }
      }

      // Assign ranks with tie handling (average rank)
      int i = 0;
      while(i < n) {
         int j = i;
         while(j < n - 1 && MathAbs(data[indices[j]] - data[indices[j+1]]) < 1e-10) j++;
         double avgRank = (i + j) / 2.0 + 1.0;
         for(int k = i; k <= j; k++) {
            ranks[indices[k]] = avgRank;
         }
         i = j + 1;
      }
   }

   //+------------------------------------------------------------------+
   //| Mean calculation                                                  |
   //+------------------------------------------------------------------+
   double Mean(double &arr[], int n) {
      if(n <= 0) return 0;
      double sum = 0;
      for(int i = 0; i < n; i++) sum += arr[i];
      return sum / n;
   }

   //+------------------------------------------------------------------+
   //| Standard Deviation calculation                                    |
   //+------------------------------------------------------------------+
   double StdDev(double &arr[], int n) {
      if(n < 2) return 0;
      double mean = Mean(arr, n);
      double sumSq = 0;
      for(int i = 0; i < n; i++) {
         sumSq += MathPow(arr[i] - mean, 2);
      }
      return MathSqrt(sumSq / (n - 1));
   }

   //+------------------------------------------------------------------+
   //| Simple Linear Regression (returns slope, intercept, r-squared)    |
   //+------------------------------------------------------------------+
   void LinearRegression(double &x[], double &y[], int n, double &slope, double &intercept, double &rsq) {
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;

      for(int i = 0; i < n; i++) {
         sumX += x[i];
         sumY += y[i];
         sumXY += x[i] * y[i];
         sumX2 += x[i] * x[i];
         sumY2 += y[i] * y[i];
      }

      double denom = n * sumX2 - sumX * sumX;
      if(MathAbs(denom) < 1e-10) {
         slope = 0;
         intercept = 0;
         rsq = 0;
         return;
      }

      slope = (n * sumXY - sumX * sumY) / denom;
      intercept = (sumY - slope * sumX) / n;

      // R-squared
      double ssRes = 0, ssTot = 0;
      double meanY = sumY / n;
      for(int i = 0; i < n; i++) {
         double pred = intercept + slope * x[i];
         ssRes += MathPow(y[i] - pred, 2);
         ssTot += MathPow(y[i] - meanY, 2);
      }
      rsq = (ssTot > 0) ? 1.0 - ssRes / ssTot : 0;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   C_PairsCore() {
      m_lookback = 100;
      m_corrThreshold = 0.75;
      m_zscoreEntry = 2.0;
      m_zscoreExit = 0.5;
      m_adfLag = 1;
      m_symbolCount = 0;
   }

   //+------------------------------------------------------------------+
   //| Configure parameters                                              |
   //+------------------------------------------------------------------+
   void Configure(int lookback, double corrThresh, double zEntry, double zExit) {
      m_lookback = lookback;
      m_corrThreshold = corrThresh;
      m_zscoreEntry = zEntry;
      m_zscoreExit = zExit;
   }

   //+------------------------------------------------------------------+
   //| Auto-detect available Forex pairs from broker                     |
   //+------------------------------------------------------------------+
   int LoadSymbolsFromBroker() {
      m_symbolCount = 0;
      ArrayResize(m_availableSymbols, 0);

      // Major currencies to form pairs
      string currencies[] = {"EUR", "GBP", "USD", "JPY", "AUD", "NZD", "CAD", "CHF"};
      int currCount = ArraySize(currencies);

      // Generate all possible pairs and check availability
      for(int i = 0; i < currCount; i++) {
         for(int j = 0; j < currCount; j++) {
            if(i == j) continue;

            string pair = currencies[i] + currencies[j];

            // Try different broker suffixes
            string suffixes[] = {"", ".r", ".i", "_SB", ".pro", ".ecn"};

            for(int s = 0; s < ArraySize(suffixes); s++) {
               string testSymbol = pair + suffixes[s];

               if(SymbolSelect(testSymbol, true)) {
                  // Verify it has valid data
                  double bid = SymbolInfoDouble(testSymbol, SYMBOL_BID);
                  if(bid > 0) {
                     ArrayResize(m_availableSymbols, m_symbolCount + 1);
                     m_availableSymbols[m_symbolCount] = testSymbol;
                     m_symbolCount++;
                     break;  // Found valid symbol, don't try other suffixes
                  }
               }
            }
         }
      }

      Print("[PairsCore] Loaded ", m_symbolCount, " symbols from broker");
      return m_symbolCount;
   }

   //+------------------------------------------------------------------+
   //| Get loaded symbols                                                |
   //+------------------------------------------------------------------+
   void GetSymbols(string &symbols[], int &count) {
      count = m_symbolCount;
      ArrayResize(symbols, m_symbolCount);
      for(int i = 0; i < m_symbolCount; i++) {
         symbols[i] = m_availableSymbols[i];
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Spearman Rank Correlation                               |
   //+------------------------------------------------------------------+
   double SpearmanCorrelation(string sym1, string sym2, ENUM_TIMEFRAMES tf) {
      double prices1[], prices2[];

      if(!GetPrices(sym1, tf, m_lookback + 1, prices1)) return 0;
      if(!GetPrices(sym2, tf, m_lookback + 1, prices2)) return 0;

      // Calculate log returns
      double returns1[], returns2[];
      CalculateLogReturns(prices1, returns1, m_lookback + 1);
      CalculateLogReturns(prices2, returns2, m_lookback + 1);

      int n = MathMin(ArraySize(returns1), ArraySize(returns2));
      if(n < 20) return 0;

      // Calculate ranks
      double ranks1[], ranks2[];
      CalculateRanks(returns1, ranks1, n);
      CalculateRanks(returns2, ranks2, n);

      // Pearson correlation of ranks = Spearman correlation
      double mean1 = Mean(ranks1, n);
      double mean2 = Mean(ranks2, n);

      double num = 0, den1 = 0, den2 = 0;
      for(int i = 0; i < n; i++) {
         double d1 = ranks1[i] - mean1;
         double d2 = ranks2[i] - mean2;
         num += d1 * d2;
         den1 += d1 * d1;
         den2 += d2 * d2;
      }

      if(den1 < 1e-10 || den2 < 1e-10) return 0;
      return num / MathSqrt(den1 * den2);
   }

   //+------------------------------------------------------------------+
   //| Calculate Pearson Correlation                                     |
   //+------------------------------------------------------------------+
   double PearsonCorrelation(string sym1, string sym2, ENUM_TIMEFRAMES tf) {
      double prices1[], prices2[];

      if(!GetPrices(sym1, tf, m_lookback + 1, prices1)) return 0;
      if(!GetPrices(sym2, tf, m_lookback + 1, prices2)) return 0;

      double returns1[], returns2[];
      CalculateLogReturns(prices1, returns1, m_lookback + 1);
      CalculateLogReturns(prices2, returns2, m_lookback + 1);

      int n = MathMin(ArraySize(returns1), ArraySize(returns2));
      if(n < 20) return 0;

      double mean1 = Mean(returns1, n);
      double mean2 = Mean(returns2, n);

      double num = 0, den1 = 0, den2 = 0;
      for(int i = 0; i < n; i++) {
         double d1 = returns1[i] - mean1;
         double d2 = returns2[i] - mean2;
         num += d1 * d2;
         den1 += d1 * d1;
         den2 += d2 * d2;
      }

      if(den1 < 1e-10 || den2 < 1e-10) return 0;
      return num / MathSqrt(den1 * den2);
   }

   //+------------------------------------------------------------------+
   //| Calculate Spread with Hedge Ratio (Cointegration approach)        |
   //+------------------------------------------------------------------+
   void CalculateSpreadWithHedgeRatio(string sym1, string sym2, ENUM_TIMEFRAMES tf,
                                       double &spread, double &zscore,
                                       double &hedgeRatio, double &mean, double &stddev) {
      double prices1[], prices2[];

      if(!GetPrices(sym1, tf, m_lookback, prices1)) { zscore = 0; return; }
      if(!GetPrices(sym2, tf, m_lookback, prices2)) { zscore = 0; return; }

      int n = m_lookback;

      // Calculate hedge ratio using OLS regression: prices1 = k * prices2 + m
      double slope, intercept, rsq;
      LinearRegression(prices2, prices1, n, slope, intercept, rsq);

      hedgeRatio = slope;

      // Calculate spread series: spread = prices1 - k * prices2
      double spreads[];
      ArrayResize(spreads, n);

      for(int i = 0; i < n; i++) {
         spreads[i] = prices1[i] - hedgeRatio * prices2[i];
      }

      // Current spread
      spread = spreads[0];

      // Mean and StdDev of spread
      mean = Mean(spreads, n);
      stddev = StdDev(spreads, n);

      // Z-Score
      if(stddev > 1e-10)
         zscore = (spread - mean) / stddev;
      else
         zscore = 0;
   }

   //+------------------------------------------------------------------+
   //| Cointegration Test (Engle-Granger two-step method)                |
   //+------------------------------------------------------------------+
   bool CointegrationTest(string sym1, string sym2, ENUM_TIMEFRAMES tf,
                          double &coint_d, double &coint_k, double &coint_m) {
      double prices1[], prices2[];

      if(!GetPrices(sym1, tf, m_lookback, prices1)) return false;
      if(!GetPrices(sym2, tf, m_lookback, prices2)) return false;

      int n = m_lookback;

      // Step 1: Regress prices1 on prices2 to get hedge ratio
      double slope, intercept, rsq;
      LinearRegression(prices2, prices1, n, slope, intercept, rsq);

      coint_k = slope;      // Hedge ratio
      coint_m = intercept;  // Intercept

      // Step 2: Calculate residuals (spread)
      double residuals[];
      ArrayResize(residuals, n);

      for(int i = 0; i < n; i++) {
         residuals[i] = prices1[i] - slope * prices2[i] - intercept;
      }

      // Step 3: ADF test on residuals
      // Simplified: check if residuals are mean-reverting
      // delta_resid = alpha + beta * resid(t-1) + error

      double deltaResid[], lagResid[];
      ArrayResize(deltaResid, n - 1);
      ArrayResize(lagResid, n - 1);

      for(int i = 0; i < n - 1; i++) {
         deltaResid[i] = residuals[i] - residuals[i + 1];
         lagResid[i] = residuals[i + 1];
      }

      // Regress delta on lag
      double beta, alpha, r2;
      LinearRegression(lagResid, deltaResid, n - 1, beta, alpha, r2);

      coint_d = beta;  // Should be negative for cointegration

      // Calculate t-statistic for beta
      double ssr = 0;
      for(int i = 0; i < n - 1; i++) {
         double pred = alpha + beta * lagResid[i];
         ssr += MathPow(deltaResid[i] - pred, 2);
      }

      double se = MathSqrt(ssr / (n - 3));
      double varLag = 0;
      double meanLag = Mean(lagResid, n - 1);
      for(int i = 0; i < n - 1; i++) {
         varLag += MathPow(lagResid[i] - meanLag, 2);
      }

      double seBeta = (varLag > 0) ? se / MathSqrt(varLag) : 1;
      double tStat = (seBeta > 0) ? beta / seBeta : 0;

      // Critical value for cointegration (Engle-Granger, 5% level, ~100 obs)
      // Approximately -3.37 for two variables
      double criticalValue = -3.37;

      return (tStat < criticalValue);
   }

   //+------------------------------------------------------------------+
   //| ADF Test for Stationarity                                         |
   //+------------------------------------------------------------------+
   bool ADFTest(double &series[], int n, double &adfStat) {
      if(n < 20) return false;

      double delta[], lag[];
      ArrayResize(delta, n - 1);
      ArrayResize(lag, n - 1);

      for(int i = 0; i < n - 1; i++) {
         delta[i] = series[i] - series[i + 1];
         lag[i] = series[i + 1];
      }

      // Regress delta on lag
      double beta, alpha, r2;
      LinearRegression(lag, delta, n - 1, beta, alpha, r2);

      // Calculate standard error
      double ssr = 0;
      for(int i = 0; i < n - 1; i++) {
         double pred = alpha + beta * lag[i];
         ssr += MathPow(delta[i] - pred, 2);
      }

      double se = MathSqrt(ssr / (n - 3));
      double varLag = 0;
      double meanLag = Mean(lag, n - 1);
      for(int i = 0; i < n - 1; i++) {
         varLag += MathPow(lag[i] - meanLag, 2);
      }

      double seBeta = (varLag > 0) ? se / MathSqrt(varLag) : 1;
      adfStat = (seBeta > 0) ? beta / seBeta : 0;

      // Critical value (5% level, ~100 obs): -2.89
      return (adfStat < -2.89);
   }

   //+------------------------------------------------------------------+
   //| Calculate Half-Life of Mean Reversion                             |
   //+------------------------------------------------------------------+
   double CalculateHalfLife(double &spread[], int n) {
      if(n < 20) return 0;

      double delta[], lag[];
      ArrayResize(delta, n - 1);
      ArrayResize(lag, n - 1);

      for(int i = 0; i < n - 1; i++) {
         delta[i] = spread[i] - spread[i + 1];
         lag[i] = spread[i + 1];
      }

      // Regress delta on lag: delta = lambda * lag
      double sumXY = 0, sumX2 = 0;
      for(int i = 0; i < n - 1; i++) {
         sumXY += delta[i] * lag[i];
         sumX2 += lag[i] * lag[i];
      }

      if(sumX2 < 1e-10) return 0;

      double lambda = sumXY / sumX2;

      // Half-life = -ln(2) / ln(1 + lambda)
      // For small lambda: half-life ≈ -ln(2) / lambda
      if(lambda >= 0 || lambda <= -1) return 0;

      double halfLife = -MathLog(2) / MathLog(1 + lambda);
      return (halfLife > 0 && halfLife < 500) ? halfLife : 0;
   }

   //+------------------------------------------------------------------+
   //| Calculate ADR (Average Daily Range)                               |
   //+------------------------------------------------------------------+
   double CalculateADR(string symbol, int days = 14) {
      double highs[], lows[];
      ArraySetAsSeries(highs, true);
      ArraySetAsSeries(lows, true);

      if(CopyHigh(symbol, PERIOD_D1, 1, days, highs) < days) return 0;
      if(CopyLow(symbol, PERIOD_D1, 1, days, lows) < days) return 0;

      double sum = 0;
      for(int i = 0; i < days; i++) {
         sum += highs[i] - lows[i];
      }

      return sum / days;
   }

   //+------------------------------------------------------------------+
   //| Calculate ADR Percentage Used Today                               |
   //+------------------------------------------------------------------+
   double CalculateADRPercent(string symbol) {
      double adr = CalculateADR(symbol);
      if(adr <= 0) return 0;

      double todayHigh = iHigh(symbol, PERIOD_D1, 0);
      double todayLow = iLow(symbol, PERIOD_D1, 0);
      double todayRange = todayHigh - todayLow;

      return (todayRange / adr) * 100.0;
   }

   //+------------------------------------------------------------------+
   //| Get Timeframe Name                                                |
   //+------------------------------------------------------------------+
   string GetTimeframeName(ENUM_TIMEFRAMES tf) {
      switch(tf) {
         case PERIOD_M1:  return "M1";
         case PERIOD_M5:  return "M5";
         case PERIOD_M15: return "M15";
         case PERIOD_M30: return "M30";
         case PERIOD_H1:  return "H1";
         case PERIOD_H4:  return "H4";
         case PERIOD_D1:  return "D1";
         case PERIOD_W1:  return "W1";
         default: return "??";
      }
   }

   //+------------------------------------------------------------------+
   //| Generate Trading Signal                                           |
   //+------------------------------------------------------------------+
   int GenerateSignal(double zscore, double spearman, bool isCointegrated,
                      bool isStationary, string sym1, string sym2, string &signalText) {
      signalText = "None";

      // Check cointegration and stationarity
      if(!isCointegrated && !isStationary) {
         return 0;
      }

      // Check correlation threshold
      if(MathAbs(spearman) < m_corrThreshold) {
         return 0;
      }

      // Z-Score based signals
      if(zscore >= m_zscoreEntry) {
         // Spread too high - expect mean reversion down
         // For positive correlation: SELL sym1, BUY sym2
         // For negative correlation: BUY both or SELL both
         if(spearman > 0) {
            signalText = "Sell " + sym1 + " & Buy " + sym2;
            return -1;
         } else {
            signalText = "Buy " + sym1 + " & " + sym2;
            return 1;
         }
      }
      else if(zscore <= -m_zscoreEntry) {
         // Spread too low - expect mean reversion up
         if(spearman > 0) {
            signalText = "Buy " + sym1 + " & Sell " + sym2;
            return 1;
         } else {
            signalText = "Sell " + sym1 + " & " + sym2;
            return -1;
         }
      }

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Full Pair Analysis                                                |
   //+------------------------------------------------------------------+
   bool AnalyzePair(string sym1, string sym2, ENUM_TIMEFRAMES tf, PairResult &result) {
      // Initialize result
      ZeroMemory(result);

      // Check symbols exist
      if(!SymbolSelect(sym1, true) || !SymbolSelect(sym2, true)) {
         return false;
      }

      // Check for valid prices
      double bid1 = SymbolInfoDouble(sym1, SYMBOL_BID);
      double bid2 = SymbolInfoDouble(sym2, SYMBOL_BID);
      if(bid1 <= 0 || bid2 <= 0) return false;

      result.pair1 = sym1;
      result.pair2 = sym2;
      result.pairName = sym1 + "-" + sym2;
      result.timeframe = tf;
      result.tfName = GetTimeframeName(tf);
      result.price1 = bid1;
      result.price2 = bid2;
      result.lastUpdate = TimeCurrent();

      // 1. Calculate correlations
      result.spearman = SpearmanCorrelation(sym1, sym2, tf);
      result.pearson = PearsonCorrelation(sym1, sym2, tf);
      result.corrType = (result.spearman >= 0) ? "Pos" : "Neg";

      // 2. Cointegration test
      result.isCointegrated = CointegrationTest(sym1, sym2, tf,
                                                 result.coint_d, result.coint_k, result.coint_m);

      // 3. Calculate spread with hedge ratio
      double hedgeRatio;
      CalculateSpreadWithHedgeRatio(sym1, sym2, tf,
                                     result.spread, result.zscore,
                                     hedgeRatio, result.spreadMean, result.spreadStd);

      // 4. Stationarity test on spread
      double prices1[], prices2[];
      GetPrices(sym1, tf, m_lookback, prices1);
      GetPrices(sym2, tf, m_lookback, prices2);

      double spreadSeries[];
      ArrayResize(spreadSeries, m_lookback);
      for(int i = 0; i < m_lookback; i++) {
         spreadSeries[i] = prices1[i] - result.coint_k * prices2[i];
      }

      result.isStationary = ADFTest(spreadSeries, m_lookback, result.adfStat);

      // 5. Half-life
      result.halfLife = CalculateHalfLife(spreadSeries, m_lookback);

      // 6. ADR metrics
      result.adr1 = CalculateADR(sym1);
      result.adr2 = CalculateADR(sym2);
      result.adrPct = (CalculateADRPercent(sym1) + CalculateADRPercent(sym2)) / 2.0;

      // 7. Generate signal
      result.signal = GenerateSignal(result.zscore, result.spearman,
                                      result.isCointegrated, result.isStationary,
                                      sym1, sym2, result.signalText);

      return true;
   }

   // Getters
   double GetCorrThreshold() { return m_corrThreshold; }
   double GetZScoreEntry() { return m_zscoreEntry; }
   double GetZScoreExit() { return m_zscoreExit; }
   int GetLookback() { return m_lookback; }
   int GetSymbolCount() { return m_symbolCount; }
};
