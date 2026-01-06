//+------------------------------------------------------------------+
//|                                            DLogic_PairsCore.mqh |
//|                          Project: D-LOGIC Pairs Trading Scanner |
//|                                        Author: RafaB Dembski    |
//|                Core Engine: Correlation, Z-Score, Stationarity  |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"
#property strict

//+------------------------------------------------------------------+
//| Pair Analysis Result Structure                                    |
//+------------------------------------------------------------------+
struct PairResult {
   string   symbol1;           // First symbol
   string   symbol2;           // Second symbol
   double   correlation;       // Spearman correlation coefficient
   double   zscore;            // Current Z-Score of spread
   double   spread;            // Current spread value
   double   spreadMean;        // Mean of spread
   double   spreadStd;         // Std deviation of spread
   bool     isStationary;      // ADF test result
   double   adfStat;           // ADF statistic
   double   halfLife;          // Mean reversion half-life
   int      signal;            // Signal: 1=BUY, -1=SELL, 0=NEUTRAL
   string   signalText;        // Signal description
   double   rsi1;              // RSI of symbol1
   double   rsi2;              // RSI of symbol2
   double   maDistance1;       // Distance from MA for symbol1
   double   maDistance2;       // Distance from MA for symbol2
   datetime lastUpdate;        // Last calculation time
};

//+------------------------------------------------------------------+
//| Pairs Trading Core Engine                                         |
//+------------------------------------------------------------------+
class C_PairsCore {
private:
   int      m_lookback;        // Lookback period for calculations
   double   m_corrThreshold;   // Correlation threshold (abs value)
   double   m_zscoreEntry;     // Z-Score threshold for entry
   double   m_zscoreExit;      // Z-Score threshold for exit
   int      m_rsiPeriod;       // RSI period
   int      m_maPeriod;        // MA period
   int      m_bbPeriod;        // Bollinger period
   double   m_bbDeviation;     // Bollinger deviation

   // --- HELPER: Get prices array ---
   bool GetPrices(string symbol, ENUM_TIMEFRAMES tf, int count, double &prices[]) {
      ArrayResize(prices, count);
      ArraySetAsSeries(prices, true);
      int copied = CopyClose(symbol, tf, 0, count, prices);
      return (copied == count);
   }

   // --- HELPER: Calculate returns ---
   void CalculateReturns(double &prices[], double &returns[]) {
      int n = ArraySize(prices);
      ArrayResize(returns, n - 1);
      for(int i = 0; i < n - 1; i++) {
         if(prices[i+1] != 0)
            returns[i] = (prices[i] - prices[i+1]) / prices[i+1];
         else
            returns[i] = 0;
      }
   }

   // --- HELPER: Calculate ranks for Spearman ---
   void CalculateRanks(double &data[], double &ranks[]) {
      int n = ArraySize(data);
      ArrayResize(ranks, n);

      // Create index array
      int indices[];
      ArrayResize(indices, n);
      for(int i = 0; i < n; i++) indices[i] = i;

      // Sort indices by data values
      for(int i = 0; i < n - 1; i++) {
         for(int j = i + 1; j < n; j++) {
            if(data[indices[i]] > data[indices[j]]) {
               int temp = indices[i];
               indices[i] = indices[j];
               indices[j] = temp;
            }
         }
      }

      // Assign ranks (handling ties with average rank)
      int i = 0;
      while(i < n) {
         int j = i;
         // Find all elements with same value
         while(j < n - 1 && data[indices[j]] == data[indices[j+1]]) j++;
         // Average rank for ties
         double avgRank = (i + j) / 2.0 + 1;
         for(int k = i; k <= j; k++) {
            ranks[indices[k]] = avgRank;
         }
         i = j + 1;
      }
   }

   // --- HELPER: Mean ---
   double Mean(double &arr[]) {
      int n = ArraySize(arr);
      if(n == 0) return 0;
      double sum = 0;
      for(int i = 0; i < n; i++) sum += arr[i];
      return sum / n;
   }

   // --- HELPER: Standard Deviation ---
   double StdDev(double &arr[]) {
      int n = ArraySize(arr);
      if(n < 2) return 0;
      double mean = Mean(arr);
      double sumSq = 0;
      for(int i = 0; i < n; i++) {
         sumSq += MathPow(arr[i] - mean, 2);
      }
      return MathSqrt(sumSq / (n - 1));
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   C_PairsCore() {
      m_lookback = 100;
      m_corrThreshold = 0.80;
      m_zscoreEntry = 2.0;
      m_zscoreExit = 0.5;
      m_rsiPeriod = 14;
      m_maPeriod = 20;
      m_bbPeriod = 20;
      m_bbDeviation = 2.0;
   }

   //+------------------------------------------------------------------+
   //| Configure parameters                                              |
   //+------------------------------------------------------------------+
   void Configure(int lookback, double corrThresh, double zEntry, double zExit,
                  int rsiPeriod, int maPeriod) {
      m_lookback = lookback;
      m_corrThreshold = corrThresh;
      m_zscoreEntry = zEntry;
      m_zscoreExit = zExit;
      m_rsiPeriod = rsiPeriod;
      m_maPeriod = maPeriod;
   }

   //+------------------------------------------------------------------+
   //| Calculate Spearman Correlation                                    |
   //+------------------------------------------------------------------+
   double SpearmanCorrelation(string sym1, string sym2, ENUM_TIMEFRAMES tf) {
      double prices1[], prices2[];

      if(!GetPrices(sym1, tf, m_lookback, prices1)) return 0;
      if(!GetPrices(sym2, tf, m_lookback, prices2)) return 0;

      // Calculate returns
      double returns1[], returns2[];
      CalculateReturns(prices1, returns1);
      CalculateReturns(prices2, returns2);

      int n = MathMin(ArraySize(returns1), ArraySize(returns2));
      if(n < 10) return 0;

      // Resize to same length
      ArrayResize(returns1, n);
      ArrayResize(returns2, n);

      // Calculate ranks
      double ranks1[], ranks2[];
      CalculateRanks(returns1, ranks1);
      CalculateRanks(returns2, ranks2);

      // Spearman correlation = Pearson correlation of ranks
      double mean1 = Mean(ranks1);
      double mean2 = Mean(ranks2);

      double num = 0, den1 = 0, den2 = 0;
      for(int i = 0; i < n; i++) {
         double d1 = ranks1[i] - mean1;
         double d2 = ranks2[i] - mean2;
         num += d1 * d2;
         den1 += d1 * d1;
         den2 += d2 * d2;
      }

      if(den1 == 0 || den2 == 0) return 0;
      return num / MathSqrt(den1 * den2);
   }

   //+------------------------------------------------------------------+
   //| Calculate Spread and Z-Score                                      |
   //+------------------------------------------------------------------+
   void CalculateSpread(string sym1, string sym2, ENUM_TIMEFRAMES tf,
                        double &spread, double &zscore, double &mean, double &stddev) {
      double prices1[], prices2[];

      if(!GetPrices(sym1, tf, m_lookback, prices1)) { zscore = 0; return; }
      if(!GetPrices(sym2, tf, m_lookback, prices2)) { zscore = 0; return; }

      // Normalize prices to start at 1.0 for comparison
      double base1 = prices1[m_lookback-1];
      double base2 = prices2[m_lookback-1];

      if(base1 == 0 || base2 == 0) { zscore = 0; return; }

      // Calculate spread series (normalized price difference)
      double spreads[];
      ArrayResize(spreads, m_lookback);

      for(int i = 0; i < m_lookback; i++) {
         double norm1 = prices1[i] / base1;
         double norm2 = prices2[i] / base2;
         spreads[i] = norm1 - norm2;
      }

      // Current spread
      spread = spreads[0];

      // Mean and StdDev of spread
      mean = Mean(spreads);
      stddev = StdDev(spreads);

      // Z-Score
      if(stddev != 0)
         zscore = (spread - mean) / stddev;
      else
         zscore = 0;
   }

   //+------------------------------------------------------------------+
   //| ADF Test for Stationarity (Simplified)                            |
   //+------------------------------------------------------------------+
   bool ADFTest(string sym1, string sym2, ENUM_TIMEFRAMES tf, double &adfStat) {
      double prices1[], prices2[];

      if(!GetPrices(sym1, tf, m_lookback, prices1)) return false;
      if(!GetPrices(sym2, tf, m_lookback, prices2)) return false;

      // Normalize and create spread series
      double base1 = prices1[m_lookback-1];
      double base2 = prices2[m_lookback-1];

      if(base1 == 0 || base2 == 0) return false;

      double spreads[];
      ArrayResize(spreads, m_lookback);

      for(int i = 0; i < m_lookback; i++) {
         spreads[i] = (prices1[i] / base1) - (prices2[i] / base2);
      }

      // Simplified ADF: regression of delta(spread) on spread(t-1)
      // delta_y = alpha + beta * y(t-1) + error
      // If beta < 0 and significant, series is stationary

      int n = m_lookback - 1;
      double deltaY[], lagY[];
      ArrayResize(deltaY, n);
      ArrayResize(lagY, n);

      for(int i = 0; i < n; i++) {
         deltaY[i] = spreads[i] - spreads[i+1];
         lagY[i] = spreads[i+1];
      }

      // Simple OLS regression: beta = Cov(deltaY, lagY) / Var(lagY)
      double meanDelta = Mean(deltaY);
      double meanLag = Mean(lagY);

      double cov = 0, varLag = 0;
      for(int i = 0; i < n; i++) {
         cov += (deltaY[i] - meanDelta) * (lagY[i] - meanLag);
         varLag += MathPow(lagY[i] - meanLag, 2);
      }

      if(varLag == 0) { adfStat = 0; return false; }

      double beta = cov / varLag;
      double alpha = meanDelta - beta * meanLag;

      // Calculate residuals and standard error
      double ssr = 0;
      for(int i = 0; i < n; i++) {
         double pred = alpha + beta * lagY[i];
         ssr += MathPow(deltaY[i] - pred, 2);
      }

      double se = MathSqrt(ssr / (n - 2));
      double seBeta = se / MathSqrt(varLag);

      if(seBeta == 0) { adfStat = 0; return false; }

      // ADF statistic = beta / SE(beta)
      adfStat = beta / seBeta;

      // Critical values (approximate) for 5% significance:
      // n=50: -2.93, n=100: -2.89, n=250: -2.88
      double criticalValue = -2.89;

      return (adfStat < criticalValue);
   }

   //+------------------------------------------------------------------+
   //| Calculate Half-Life of Mean Reversion                             |
   //+------------------------------------------------------------------+
   double CalculateHalfLife(string sym1, string sym2, ENUM_TIMEFRAMES tf) {
      double prices1[], prices2[];

      if(!GetPrices(sym1, tf, m_lookback, prices1)) return 0;
      if(!GetPrices(sym2, tf, m_lookback, prices2)) return 0;

      double base1 = prices1[m_lookback-1];
      double base2 = prices2[m_lookback-1];

      if(base1 == 0 || base2 == 0) return 0;

      // Create spread series
      double spreads[];
      ArrayResize(spreads, m_lookback);

      for(int i = 0; i < m_lookback; i++) {
         spreads[i] = (prices1[i] / base1) - (prices2[i] / base2);
      }

      // Calculate lambda from AR(1) model: spread(t) = lambda * spread(t-1) + error
      int n = m_lookback - 1;
      double sumXY = 0, sumX2 = 0;

      for(int i = 0; i < n; i++) {
         sumXY += spreads[i] * spreads[i+1];
         sumX2 += spreads[i+1] * spreads[i+1];
      }

      if(sumX2 == 0) return 0;

      double lambda = sumXY / sumX2;

      // Half-life = -log(2) / log(lambda)
      if(lambda <= 0 || lambda >= 1) return 0;

      double halfLife = -MathLog(2) / MathLog(lambda);
      return halfLife;
   }

   //+------------------------------------------------------------------+
   //| Get RSI Value                                                     |
   //+------------------------------------------------------------------+
   double GetRSI(string symbol, ENUM_TIMEFRAMES tf) {
      int handle = iRSI(symbol, tf, m_rsiPeriod, PRICE_CLOSE);
      if(handle == INVALID_HANDLE) return 50;

      double rsi[];
      ArraySetAsSeries(rsi, true);

      if(CopyBuffer(handle, 0, 0, 1, rsi) <= 0) {
         IndicatorRelease(handle);
         return 50;
      }

      IndicatorRelease(handle);
      return rsi[0];
   }

   //+------------------------------------------------------------------+
   //| Get Distance from MA (percentage)                                 |
   //+------------------------------------------------------------------+
   double GetMADistance(string symbol, ENUM_TIMEFRAMES tf) {
      int handle = iMA(symbol, tf, m_maPeriod, 0, MODE_SMA, PRICE_CLOSE);
      if(handle == INVALID_HANDLE) return 0;

      double ma[];
      ArraySetAsSeries(ma, true);

      if(CopyBuffer(handle, 0, 0, 1, ma) <= 0) {
         IndicatorRelease(handle);
         return 0;
      }

      IndicatorRelease(handle);

      double price = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(ma[0] == 0) return 0;

      return ((price - ma[0]) / ma[0]) * 100.0;
   }

   //+------------------------------------------------------------------+
   //| Get Bollinger Band Position (-1 to 1)                             |
   //+------------------------------------------------------------------+
   double GetBBPosition(string symbol, ENUM_TIMEFRAMES tf) {
      int handle = iBands(symbol, tf, m_bbPeriod, 0, m_bbDeviation, PRICE_CLOSE);
      if(handle == INVALID_HANDLE) return 0;

      double upper[], lower[], middle[];
      ArraySetAsSeries(upper, true);
      ArraySetAsSeries(lower, true);
      ArraySetAsSeries(middle, true);

      if(CopyBuffer(handle, 1, 0, 1, upper) <= 0) { IndicatorRelease(handle); return 0; }
      if(CopyBuffer(handle, 2, 0, 1, lower) <= 0) { IndicatorRelease(handle); return 0; }
      if(CopyBuffer(handle, 0, 0, 1, middle) <= 0) { IndicatorRelease(handle); return 0; }

      IndicatorRelease(handle);

      double price = SymbolInfoDouble(symbol, SYMBOL_BID);
      double range = upper[0] - lower[0];

      if(range == 0) return 0;

      // Return position: -1 = at lower, 0 = at middle, 1 = at upper
      return (price - middle[0]) / (range / 2);
   }

   //+------------------------------------------------------------------+
   //| Generate Trading Signal                                           |
   //+------------------------------------------------------------------+
   int GenerateSignal(double zscore, double corr, bool isStationary,
                      double rsi1, double rsi2, string &signalText) {
      signalText = "NEUTRAL";

      // Check if correlation is strong enough
      if(MathAbs(corr) < m_corrThreshold) {
         signalText = "LOW CORR";
         return 0;
      }

      // Check stationarity
      if(!isStationary) {
         signalText = "NON-STAT";
         return 0;
      }

      // Z-Score based signals with RSI confirmation
      if(zscore > m_zscoreEntry) {
         // Spread is high - expect mean reversion down
         // SELL pair1, BUY pair2
         if(rsi1 > 60 && rsi2 < 40) {
            signalText = "SELL P1 / BUY P2";
            return -1;
         }
         signalText = "Z HIGH (wait RSI)";
         return 0;
      }
      else if(zscore < -m_zscoreEntry) {
         // Spread is low - expect mean reversion up
         // BUY pair1, SELL pair2
         if(rsi1 < 40 && rsi2 > 60) {
            signalText = "BUY P1 / SELL P2";
            return 1;
         }
         signalText = "Z LOW (wait RSI)";
         return 0;
      }
      else if(MathAbs(zscore) < m_zscoreExit) {
         signalText = "AT MEAN";
         return 0;
      }

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Full Pair Analysis                                                |
   //+------------------------------------------------------------------+
   bool AnalyzePair(string sym1, string sym2, ENUM_TIMEFRAMES tf, PairResult &result) {
      // Check if symbols exist
      if(!SymbolSelect(sym1, true) || !SymbolSelect(sym2, true)) {
         return false;
      }

      result.symbol1 = sym1;
      result.symbol2 = sym2;
      result.lastUpdate = TimeCurrent();

      // 1. Calculate Spearman Correlation
      result.correlation = SpearmanCorrelation(sym1, sym2, tf);

      // 2. Calculate Spread and Z-Score
      CalculateSpread(sym1, sym2, tf, result.spread, result.zscore,
                      result.spreadMean, result.spreadStd);

      // 3. ADF Test
      result.isStationary = ADFTest(sym1, sym2, tf, result.adfStat);

      // 4. Half-Life
      result.halfLife = CalculateHalfLife(sym1, sym2, tf);

      // 5. Technical indicators
      result.rsi1 = GetRSI(sym1, tf);
      result.rsi2 = GetRSI(sym2, tf);
      result.maDistance1 = GetMADistance(sym1, tf);
      result.maDistance2 = GetMADistance(sym2, tf);

      // 6. Generate Signal
      result.signal = GenerateSignal(result.zscore, result.correlation,
                                     result.isStationary, result.rsi1, result.rsi2,
                                     result.signalText);

      return true;
   }

   // Getters
   double GetCorrThreshold() { return m_corrThreshold; }
   double GetZScoreEntry() { return m_zscoreEntry; }
   int GetLookback() { return m_lookback; }
};
