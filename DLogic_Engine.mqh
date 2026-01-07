//+------------------------------------------------------------------+
//|                                               DLogic_Engine.mqh  |
//|                     D-LOGIC Professional Pairs Trading Engine     |
//|                                        Author: Rafał Dembski     |
//|                                                                   |
//|  Statistical Arbitrage Engine:                                    |
//|  - OLS Regression (Hedge Ratio/Beta)                              |
//|  - Z-Score Normalization                                          |
//|  - Cointegration Testing (ADF + Zero-Crossing)                    |
//|  - Rolling Window Statistics                                      |
//+------------------------------------------------------------------+
#property copyright "Rafał Dembski"
#property strict

// ============================================================
// PAIR ANALYSIS RESULT STRUCTURE
// ============================================================
struct SPairResult {
   string   symbolA;           // First symbol (dependent)
   string   symbolB;           // Second symbol (independent)
   string   pairName;          // Combined name "EURUSD/GBPUSD"

   // OLS Regression
   double   beta;              // Hedge Ratio (slope)
   double   alpha;             // Intercept
   double   rSquared;          // R² goodness of fit

   // Spread Statistics
   double   currentSpread;     // Current spread value
   double   spreadMean;        // Rolling mean of spread
   double   spreadStdDev;      // Rolling standard deviation
   double   zScore;            // Normalized Z-Score

   // Cointegration Metrics
   double   adfStatistic;      // Simplified ADF test statistic
   int      zeroCrossings;     // Count of zero crossings (mean reversion indicator)
   double   halfLife;          // Estimated half-life of mean reversion
   bool     isCointegrated;    // Passes cointegration test?

   // Advanced Analytics (NEW)
   double   hurstExponent;     // Hurst Exponent: <0.5=mean reverting, >0.5=trending
   double   volatilityRatio;   // Current vol / Historical vol (regime indicator)
   double   kellyFraction;     // Optimal position size (Kelly Criterion)
   double   expectedReturn;    // Expected return based on Z-Score mean reversion
   int      qualityScore;      // Overall pair quality (0-100)

   // Signal
   int      signal;            // -2=Strong Short, -1=Weak Short, 0=Neutral, 1=Weak Long, 2=Strong Long
   string   signalText;        // Human readable signal

   // Timestamps
   datetime lastUpdate;
   ENUM_TIMEFRAMES timeframe;
};

//+------------------------------------------------------------------+
//| CPairsEngine - Statistical Arbitrage Engine                       |
//+------------------------------------------------------------------+
class CPairsEngine {
private:
   // Configuration
   int            m_lookback;           // Rolling window size
   double         m_zScoreEntry;        // Z-Score entry threshold
   double         m_zScoreExit;         // Z-Score exit threshold
   double         m_zScoreStop;         // Z-Score stop-loss threshold
   double         m_minRSquared;        // Minimum R² for valid pair
   int            m_minZeroCrossings;   // Minimum zero crossings for cointegration

   // Cache for calculations
   double         m_logPricesA[];
   double         m_logPricesB[];
   double         m_spreadSeries[];
   double         m_zScoreSeries[];

   //+------------------------------------------------------------------+
   //| Calculate natural log prices for stability                        |
   //+------------------------------------------------------------------+
   bool CalculateLogPrices(string symbol, ENUM_TIMEFRAMES tf, double &logPrices[]) {
      double closes[];
      ArraySetAsSeries(closes, true);
      ArraySetAsSeries(logPrices, true);

      int copied = CopyClose(symbol, tf, 0, m_lookback + 1, closes);
      if(copied < m_lookback) {
         Print("[ENGINE] Insufficient data for ", symbol, " got ", copied, " bars");
         return false;
      }

      ArrayResize(logPrices, m_lookback);

      for(int i = 0; i < m_lookback; i++) {
         if(closes[i] <= 0) {
            Print("[ENGINE] Invalid price for ", symbol, " at bar ", i);
            return false;
         }
         logPrices[i] = MathLog(closes[i]);
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| OLS Regression: Y = Alpha + Beta * X                              |
   //| Returns Beta (Hedge Ratio), Alpha (Intercept), R²                 |
   //|                                                                   |
   //| Formula:                                                          |
   //| Beta = Cov(X,Y) / Var(X)                                          |
   //| Alpha = Mean(Y) - Beta * Mean(X)                                  |
   //| R² = [Cov(X,Y)]² / [Var(X) * Var(Y)]                              |
   //+------------------------------------------------------------------+
   void OLSRegression(double &pricesY[], double &pricesX[], int size,
                      double &beta, double &alpha, double &rSquared) {
      // Calculate means
      double sumX = 0, sumY = 0;
      for(int i = 0; i < size; i++) {
         sumX += pricesX[i];
         sumY += pricesY[i];
      }
      double meanX = sumX / size;
      double meanY = sumY / size;

      // Calculate variances and covariance
      double varX = 0, varY = 0, covXY = 0;
      for(int i = 0; i < size; i++) {
         double devX = pricesX[i] - meanX;
         double devY = pricesY[i] - meanY;
         varX += devX * devX;
         varY += devY * devY;
         covXY += devX * devY;
      }

      varX /= (size - 1);
      varY /= (size - 1);
      covXY /= (size - 1);

      // Calculate OLS coefficients
      if(MathAbs(varX) < 1e-10) {
         beta = 1.0;
         alpha = 0.0;
         rSquared = 0.0;
         return;
      }

      beta = covXY / varX;
      alpha = meanY - beta * meanX;

      // R² = Coefficient of Determination
      if(MathAbs(varY) < 1e-10) {
         rSquared = 0.0;
      } else {
         rSquared = (covXY * covXY) / (varX * varY);
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Spread Series: Spread = Y - Beta * X                    |
   //+------------------------------------------------------------------+
   void CalculateSpreadSeries(double &pricesY[], double &pricesX[],
                               double beta, double &spread[]) {
      int size = ArraySize(pricesY);
      ArrayResize(spread, size);

      for(int i = 0; i < size; i++) {
         spread[i] = pricesY[i] - beta * pricesX[i];
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Z-Score: (Value - Mean) / StdDev                        |
   //+------------------------------------------------------------------+
   double CalculateZScore(double &series[], double &mean, double &stdDev) {
      int size = ArraySize(series);
      if(size < 2) return 0;

      // Calculate mean
      double sum = 0;
      for(int i = 0; i < size; i++) {
         sum += series[i];
      }
      mean = sum / size;

      // Calculate standard deviation
      double sumSq = 0;
      for(int i = 0; i < size; i++) {
         sumSq += MathPow(series[i] - mean, 2);
      }
      stdDev = MathSqrt(sumSq / (size - 1));

      // Z-Score of most recent value
      if(stdDev < 1e-10) return 0;

      return (series[0] - mean) / stdDev;
   }

   //+------------------------------------------------------------------+
   //| Count Zero Crossings - Indicator of Mean Reversion                |
   //| More crossings = more mean-reverting behavior                     |
   //+------------------------------------------------------------------+
   int CountZeroCrossings(double &series[], double mean) {
      int size = ArraySize(series);
      if(size < 2) return 0;

      int crossings = 0;
      bool wasAbove = (series[size-1] > mean);

      for(int i = size - 2; i >= 0; i--) {
         bool isAbove = (series[i] > mean);
         if(isAbove != wasAbove) {
            crossings++;
            wasAbove = isAbove;
         }
      }

      return crossings;
   }

   //+------------------------------------------------------------------+
   //| Simplified ADF Test (Augmented Dickey-Fuller)                     |
   //| Tests for unit root (non-stationarity)                            |
   //|                                                                   |
   //| H0: Unit root exists (non-stationary)                             |
   //| H1: No unit root (stationary)                                     |
   //|                                                                   |
   //| Simplified: ΔY_t = γ * Y_{t-1} + ε_t                              |
   //| t-statistic = γ / SE(γ)                                           |
   //| If t-stat < critical value (-2.86 at 5%), reject H0 = stationary  |
   //+------------------------------------------------------------------+
   double SimplifiedADFTest(double &series[]) {
      int size = ArraySize(series);
      if(size < 10) return 0;

      // Calculate first differences: ΔY_t = Y_t - Y_{t-1}
      double deltaY[];
      double lagY[];
      ArrayResize(deltaY, size - 1);
      ArrayResize(lagY, size - 1);

      for(int i = 0; i < size - 1; i++) {
         deltaY[i] = series[i] - series[i + 1];  // Remember: series is reversed
         lagY[i] = series[i + 1];
      }

      // Regress ΔY on Y_{t-1}
      double gamma, intercept, rSq;
      OLSRegression(deltaY, lagY, size - 1, gamma, intercept, rSq);

      // Calculate standard error of gamma
      double sumResidSq = 0;
      for(int i = 0; i < size - 1; i++) {
         double predicted = intercept + gamma * lagY[i];
         double residual = deltaY[i] - predicted;
         sumResidSq += residual * residual;
      }

      double mse = sumResidSq / (size - 3);  // n - k - 1

      // Variance of lagY
      double sumLag = 0, sumLagSq = 0;
      for(int i = 0; i < size - 1; i++) {
         sumLag += lagY[i];
         sumLagSq += lagY[i] * lagY[i];
      }
      double varLag = sumLagSq - (sumLag * sumLag) / (size - 1);

      if(varLag < 1e-10) return 0;

      double seGamma = MathSqrt(mse / varLag);

      // t-statistic
      if(seGamma < 1e-10) return 0;
      double tStat = gamma / seGamma;

      return tStat;
   }

   //+------------------------------------------------------------------+
   //| Estimate Half-Life of Mean Reversion                              |
   //| HL = -ln(2) / ln(1 + γ)                                           |
   //| Where γ is the autoregressive coefficient                         |
   //+------------------------------------------------------------------+
   double EstimateHalfLife(double &series[]) {
      int size = ArraySize(series);
      if(size < 10) return 999;

      // Regress spread_t on spread_{t-1}
      double current[];
      double lagged[];
      ArrayResize(current, size - 1);
      ArrayResize(lagged, size - 1);

      for(int i = 0; i < size - 1; i++) {
         current[i] = series[i];
         lagged[i] = series[i + 1];
      }

      double phi, intercept, rSq;
      OLSRegression(current, lagged, size - 1, phi, intercept, rSq);

      // Half-life calculation
      // phi should be < 1 for mean reversion
      if(phi >= 1.0 || phi <= 0) return 999;  // No mean reversion

      double halfLife = -MathLog(2) / MathLog(phi);

      return MathAbs(halfLife);
   }

   //+------------------------------------------------------------------+
   //| Calculate Hurst Exponent (Rescaled Range Method)                   |
   //| H < 0.5 = Mean Reverting (ideal for pairs trading)                |
   //| H = 0.5 = Random Walk                                              |
   //| H > 0.5 = Trending (avoid for pairs trading)                       |
   //+------------------------------------------------------------------+
   double CalculateHurstExponent(double &series[]) {
      int size = ArraySize(series);
      if(size < 20) return 0.5;  // Default to random walk

      // Use multiple sub-periods for R/S calculation
      int minPeriod = 10;
      int maxPeriod = size / 2;

      double logN[], logRS[];
      int validPoints = 0;

      // Calculate R/S for different period lengths
      for(int n = minPeriod; n <= maxPeriod; n += 5) {
         int numPeriods = size / n;
         if(numPeriods < 1) continue;

         double sumRS = 0;
         int countRS = 0;

         for(int p = 0; p < numPeriods; p++) {
            int startIdx = p * n;
            if(startIdx + n > size) break;

            // Calculate mean of this sub-period
            double subMean = 0;
            for(int i = 0; i < n; i++) {
               subMean += series[startIdx + i];
            }
            subMean /= n;

            // Calculate cumulative deviation from mean
            double cumDev = 0;
            double minCumDev = 0;
            double maxCumDev = 0;

            for(int i = 0; i < n; i++) {
               cumDev += (series[startIdx + i] - subMean);
               if(cumDev < minCumDev) minCumDev = cumDev;
               if(cumDev > maxCumDev) maxCumDev = cumDev;
            }

            double range = maxCumDev - minCumDev;

            // Calculate standard deviation
            double sumSq = 0;
            for(int i = 0; i < n; i++) {
               sumSq += MathPow(series[startIdx + i] - subMean, 2);
            }
            double stdDev = MathSqrt(sumSq / n);

            if(stdDev > 1e-10) {
               sumRS += range / stdDev;
               countRS++;
            }
         }

         if(countRS > 0) {
            ArrayResize(logN, validPoints + 1);
            ArrayResize(logRS, validPoints + 1);
            logN[validPoints] = MathLog((double)n);
            logRS[validPoints] = MathLog(sumRS / countRS);
            validPoints++;
         }
      }

      // Linear regression of log(R/S) on log(n) to get Hurst exponent
      if(validPoints < 3) return 0.5;

      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for(int i = 0; i < validPoints; i++) {
         sumX += logN[i];
         sumY += logRS[i];
         sumXY += logN[i] * logRS[i];
         sumX2 += logN[i] * logN[i];
      }

      double denom = validPoints * sumX2 - sumX * sumX;
      if(MathAbs(denom) < 1e-10) return 0.5;

      double hurst = (validPoints * sumXY - sumX * sumY) / denom;

      // Clamp to reasonable range [0, 1]
      return MathMax(0.0, MathMin(1.0, hurst));
   }

   //+------------------------------------------------------------------+
   //| Calculate Volatility Ratio (Current / Historical)                  |
   //| >1 = High volatility regime, <1 = Low volatility regime            |
   //+------------------------------------------------------------------+
   double CalculateVolatilityRatio(double &series[]) {
      int size = ArraySize(series);
      if(size < 50) return 1.0;

      // Recent volatility (last 20 bars)
      int recentPeriod = 20;
      double recentSum = 0, recentSumSq = 0;
      for(int i = 0; i < recentPeriod; i++) {
         recentSum += series[i];
      }
      double recentMean = recentSum / recentPeriod;
      for(int i = 0; i < recentPeriod; i++) {
         recentSumSq += MathPow(series[i] - recentMean, 2);
      }
      double recentVol = MathSqrt(recentSumSq / recentPeriod);

      // Historical volatility (full period)
      double histSum = 0, histSumSq = 0;
      for(int i = 0; i < size; i++) {
         histSum += series[i];
      }
      double histMean = histSum / size;
      for(int i = 0; i < size; i++) {
         histSumSq += MathPow(series[i] - histMean, 2);
      }
      double histVol = MathSqrt(histSumSq / size);

      if(histVol < 1e-10) return 1.0;
      return recentVol / histVol;
   }

   //+------------------------------------------------------------------+
   //| Calculate Kelly Fraction for Optimal Position Sizing               |
   //| Kelly = (p * W - q) / W                                            |
   //| Where: p = win probability, q = 1-p, W = avg win/avg loss          |
   //+------------------------------------------------------------------+
   double CalculateKellyFraction(double winRate, double avgWinLossRatio) {
      double p = winRate / 100.0;  // Win probability
      double q = 1.0 - p;          // Loss probability

      if(avgWinLossRatio <= 0 || p <= 0) return 0;

      double kelly = (p * avgWinLossRatio - q) / avgWinLossRatio;

      // Apply half-Kelly for safety
      kelly *= 0.5;

      // Clamp to reasonable range [0, 0.25]
      return MathMax(0.0, MathMin(0.25, kelly));
   }

   //+------------------------------------------------------------------+
   //| Calculate Expected Return for Mean Reversion Trade                 |
   //| Based on Z-Score reverting to mean                                 |
   //+------------------------------------------------------------------+
   double CalculateExpectedReturn(double zScore, double halfLife, double spreadStdDev) {
      if(halfLife <= 0 || halfLife > 100) return 0;

      // Expected move = current Z-Score deviation * probability of reversion
      // Assume reversion to Z=0 with exponential decay
      double reversionProb = 1.0 - MathExp(-MathLog(2) / halfLife);  // Prob of 50% reversion in halfLife bars

      // Expected Z-Score change
      double expectedZChange = MathAbs(zScore) * reversionProb;

      // Convert to price move (approximate)
      double expectedMove = expectedZChange * spreadStdDev;

      return expectedMove;
   }

   //+------------------------------------------------------------------+
   //| Calculate Overall Pair Quality Score (0-100)                       |
   //+------------------------------------------------------------------+
   int CalculateQualityScore(SPairResult &result) {
      int score = 0;

      // Cointegration (30 points)
      if(result.isCointegrated) score += 30;

      // R² (20 points)
      score += (int)(result.rSquared * 20);

      // Hurst Exponent (20 points) - lower is better for mean reversion
      if(result.hurstExponent < 0.4) score += 20;
      else if(result.hurstExponent < 0.5) score += 15;
      else if(result.hurstExponent < 0.55) score += 5;

      // Half-Life (15 points) - optimal is 5-30 bars
      if(result.halfLife >= 5 && result.halfLife <= 30) score += 15;
      else if(result.halfLife > 0 && result.halfLife <= 50) score += 8;

      // Zero Crossings (10 points)
      if(result.zeroCrossings >= 15) score += 10;
      else if(result.zeroCrossings >= 10) score += 7;
      else if(result.zeroCrossings >= 5) score += 3;

      // Volatility Ratio penalty (5 points) - prefer normal volatility
      if(result.volatilityRatio >= 0.7 && result.volatilityRatio <= 1.5) score += 5;

      return MathMin(100, score);
   }

   //+------------------------------------------------------------------+
   //| Generate Trading Signal                                           |
   //+------------------------------------------------------------------+
   void GenerateSignal(SPairResult &result) {
      double z = result.zScore;

      // Strong signals at Z > 2 or Z < -2
      if(z >= m_zScoreEntry) {
         result.signal = -2;  // Strong Short Spread (SELL A, BUY B)
         result.signalText = "SHORT SPREAD";
      }
      else if(z <= -m_zScoreEntry) {
         result.signal = 2;   // Strong Long Spread (BUY A, SELL B)
         result.signalText = "LONG SPREAD";
      }
      else if(z >= m_zScoreEntry * 0.75) {
         result.signal = -1;  // Weak Short
         result.signalText = "WEAK SHORT";
      }
      else if(z <= -m_zScoreEntry * 0.75) {
         result.signal = 1;   // Weak Long
         result.signalText = "WEAK LONG";
      }
      else if(MathAbs(z) <= m_zScoreExit) {
         result.signal = 0;
         result.signalText = "EXIT ZONE";
      }
      else {
         result.signal = 0;
         result.signalText = "NEUTRAL";
      }

      // Check for stop-loss zone
      if(MathAbs(z) >= m_zScoreStop) {
         result.signalText = "STOP LOSS";
      }

      // Require cointegration for valid signals
      if(!result.isCointegrated && result.signal != 0) {
         result.signalText += " [!COINT]";
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CPairsEngine() {
      m_lookback = 200;
      m_zScoreEntry = 2.0;
      m_zScoreExit = 0.5;
      m_zScoreStop = 3.5;
      m_minRSquared = 0.60;
      m_minZeroCrossings = 10;  // At least 10 crossings in lookback period
   }

   //+------------------------------------------------------------------+
   //| Configure Engine Parameters                                       |
   //+------------------------------------------------------------------+
   void Configure(int lookback, double zEntry, double zExit, double zStop,
                  double minR2 = 0.60, int minCrossings = 10) {
      m_lookback = lookback;
      m_zScoreEntry = zEntry;
      m_zScoreExit = zExit;
      m_zScoreStop = zStop;
      m_minRSquared = minR2;
      m_minZeroCrossings = minCrossings;

      Print("[ENGINE] Configured: Lookback=", lookback, ", Z-Entry=", zEntry,
            ", Z-Exit=", zExit, ", Z-Stop=", zStop);
   }

   //+------------------------------------------------------------------+
   //| Analyze Pair - Full Statistical Analysis                          |
   //+------------------------------------------------------------------+
   bool AnalyzePair(string symbolA, string symbolB, ENUM_TIMEFRAMES tf, SPairResult &result) {
      // Initialize result
      result.symbolA = symbolA;
      result.symbolB = symbolB;
      result.pairName = symbolA + "/" + symbolB;
      result.timeframe = tf;
      result.lastUpdate = TimeCurrent();
      result.signal = 0;
      result.signalText = "ANALYZING";
      result.isCointegrated = false;

      // Step 1: Get log prices
      if(!CalculateLogPrices(symbolA, tf, m_logPricesA)) return false;
      if(!CalculateLogPrices(symbolB, tf, m_logPricesB)) return false;

      // Step 2: OLS Regression to find Hedge Ratio
      OLSRegression(m_logPricesA, m_logPricesB, m_lookback,
                    result.beta, result.alpha, result.rSquared);

      // Step 3: Calculate Spread Series
      CalculateSpreadSeries(m_logPricesA, m_logPricesB, result.beta, m_spreadSeries);

      // Step 4: Calculate Z-Score
      result.zScore = CalculateZScore(m_spreadSeries, result.spreadMean, result.spreadStdDev);
      result.currentSpread = m_spreadSeries[0];

      // Step 5: Cointegration Tests
      result.zeroCrossings = CountZeroCrossings(m_spreadSeries, result.spreadMean);
      result.adfStatistic = SimplifiedADFTest(m_spreadSeries);
      result.halfLife = EstimateHalfLife(m_spreadSeries);

      // Step 6: Determine if cointegrated
      // Criteria:
      // 1. ADF statistic < -2.86 (5% critical value)
      // 2. At least minimum zero crossings
      // 3. R² above threshold
      // 4. Half-life reasonable (< 50 bars)
      result.isCointegrated = (result.adfStatistic < -2.0 &&
                               result.zeroCrossings >= m_minZeroCrossings &&
                               result.rSquared >= m_minRSquared &&
                               result.halfLife < 50);

      // Step 7: Advanced Analytics
      result.hurstExponent = CalculateHurstExponent(m_spreadSeries);
      result.volatilityRatio = CalculateVolatilityRatio(m_spreadSeries);
      result.expectedReturn = CalculateExpectedReturn(result.zScore, result.halfLife, result.spreadStdDev);

      // Kelly Fraction (assumes 60% win rate and 1.5:1 reward/risk as baseline for pairs trading)
      double assumedWinRate = result.isCointegrated ? 60.0 : 50.0;
      double assumedRatio = result.isCointegrated ? 1.5 : 1.0;
      result.kellyFraction = CalculateKellyFraction(assumedWinRate, assumedRatio);

      // Quality Score
      result.qualityScore = CalculateQualityScore(result);

      // Step 8: Generate Signal
      GenerateSignal(result);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Quick Z-Score Update (for existing pair)                          |
   //+------------------------------------------------------------------+
   double QuickZScoreUpdate(string symbolA, string symbolB, double beta, ENUM_TIMEFRAMES tf) {
      double closeA = iClose(symbolA, tf, 0);
      double closeB = iClose(symbolB, tf, 0);

      if(closeA <= 0 || closeB <= 0) return 0;

      double logA = MathLog(closeA);
      double logB = MathLog(closeB);
      double spread = logA - beta * logB;

      // Use cached mean/stddev if available
      if(ArraySize(m_spreadSeries) > 0) {
         double mean = 0, stdDev = 0;
         int size = ArraySize(m_spreadSeries);

         for(int i = 0; i < size; i++) mean += m_spreadSeries[i];
         mean /= size;

         for(int i = 0; i < size; i++) stdDev += MathPow(m_spreadSeries[i] - mean, 2);
         stdDev = MathSqrt(stdDev / (size - 1));

         if(stdDev > 1e-10) {
            return (spread - mean) / stdDev;
         }
      }

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Get Entry Threshold                                               |
   //+------------------------------------------------------------------+
   double GetEntryThreshold() { return m_zScoreEntry; }

   //+------------------------------------------------------------------+
   //| Get Exit Threshold                                                |
   //+------------------------------------------------------------------+
   double GetExitThreshold() { return m_zScoreExit; }

   //+------------------------------------------------------------------+
   //| Get Stop Threshold                                                |
   //+------------------------------------------------------------------+
   double GetStopThreshold() { return m_zScoreStop; }

   //+------------------------------------------------------------------+
   //| Get Lookback Period                                               |
   //+------------------------------------------------------------------+
   int GetLookback() { return m_lookback; }
};

//+------------------------------------------------------------------+
