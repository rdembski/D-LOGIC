//+------------------------------------------------------------------+
//|                                            DLogic_QuantDash.mqh |
//|                                   Project: D-LOGIC QUANT v5.0   |
//|                                        Author: RafaB Dembski    |
//|          Layer: PROFESSIONAL QUANT DASHBOARD (Minimal & Fast)   |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"

// Forward declarations
class C_SMC_Engine;

// --- QUANT COLOR SCHEME ---
#define COLOR_Q_BG             C'18,18,18'          // Dark background
#define COLOR_Q_HEADER         C'30,30,35'          // Header background
#define COLOR_Q_TEXT           C'220,220,220'       // Main text
#define COLOR_Q_LABEL          C'130,130,140'       // Labels (muted)
#define COLOR_Q_UP             C'0,230,118'         // Positive/Bullish
#define COLOR_Q_DN             C'255,82,82'         // Negative/Bearish
#define COLOR_Q_WARN           C'255,180,0'         // Warning/Caution
#define COLOR_Q_ACCENT         C'100,181,246'       // Accent blue
#define COLOR_Q_CYAN           C'0,229,255'         // QUANT cyan
#define COLOR_Q_PURPLE         C'186,104,200'       // Probability purple
#define COLOR_Q_NEUT           C'100,100,100'       // Neutral gray

//+------------------------------------------------------------------+
//| QUANT Response Structure                                          |
//+------------------------------------------------------------------+
struct QuantResponse {
   string   decision;
   int      confidence;
   string   comment;

   // Risk Metrics
   double   var_95;
   double   cvar;
   double   sharpe;
   double   sortino;
   double   max_dd;
   double   volatility;

   // Regime
   string   regime;
   int      regime_conf;

   // Trend
   int      trend_strength;
   string   trend_dir;

   // Probability
   int      prob_profit;
   double   expected_ret;

   // Anomaly
   bool     is_anomaly;
   double   anomaly_score;

   // Distribution
   double   skewness;
   double   kurtosis;
};

//+------------------------------------------------------------------+
//| QUANT Dashboard Class                                             |
//+------------------------------------------------------------------+
class C_QuantDashboard {
private:
      string         m_prefix;
      int            m_height;
      int            m_colWidth;
      int            m_offsetLeft;

      C_SMC_Engine   *m_engHTF;
      C_SMC_Engine   *m_engITF;

      // Current QUANT data
      QuantResponse  m_quant;
      bool           m_dataReady;

      // --- DRAWING HELPERS ---

      void CreateRect(string name, int x, int y, int w, int h, color bg, int border=BORDER_FLAT) {
            if(ObjectFind(0, name) < 0) {
                  ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
                  ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                  ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
                  ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
            }
            ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
            ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
            ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
            ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
            ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
            ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, border);
            ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'50,50,55');
      }

      void CreateText(string name, string text, int x, int y, color clr, int fontSize=8, bool bold=false) {
            if(ObjectFind(0, name) < 0) {
                  ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
                  ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                  ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
                  ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
            }
            ObjectSetString(0, name, OBJPROP_FONT, bold ? "Consolas Bold" : "Consolas");
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
            ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
            ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
            ObjectSetString(0, name, OBJPROP_TEXT, text);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      }

      void CreateMiniBar(string name, int x, int y, int w, int h, double pct, color cFill) {
            CreateRect(name+"_BG", x, y, w, h, C'40,40,45', BORDER_FLAT);

            int fillW = (int)(w * (pct/100.0));
            if(fillW > w) fillW = w;
            if(fillW < 1) fillW = 1;

            string nameFill = name + "_FILL";
            if(ObjectFind(0, nameFill) < 0) {
                  ObjectCreate(0, nameFill, OBJ_RECTANGLE_LABEL, 0, 0, 0);
                  ObjectSetInteger(0, nameFill, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                  ObjectSetInteger(0, nameFill, OBJPROP_ZORDER, 1);
                  ObjectSetInteger(0, nameFill, OBJPROP_HIDDEN, true);
            }
            ObjectSetInteger(0, nameFill, OBJPROP_XDISTANCE, x);
            ObjectSetInteger(0, nameFill, OBJPROP_YDISTANCE, y);
            ObjectSetInteger(0, nameFill, OBJPROP_XSIZE, fillW);
            ObjectSetInteger(0, nameFill, OBJPROP_YSIZE, h);
            ObjectSetInteger(0, nameFill, OBJPROP_BGCOLOR, cFill);
            ObjectSetInteger(0, nameFill, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      }

      // Get bias from engine
      void GetBiasState(C_SMC_Engine *eng, string &txt, color &col) {
            if(!eng) { txt="N/A"; col=COLOR_Q_NEUT; return; }
            int b = eng.GetStructureBias();
            if(b == 1) { txt="BULL"; col=COLOR_Q_UP; }
            else if(b == -1) { txt="BEAR"; col=COLOR_Q_DN; }
            else { txt="NEUT"; col=COLOR_Q_NEUT; }
      }

      // Color based on value
      color GetRiskColor(double val, double good, double bad) {
            if(val >= good) return COLOR_Q_UP;
            if(val <= bad) return COLOR_Q_DN;
            return COLOR_Q_WARN;
      }

public:
      C_QuantDashboard(C_SMC_Engine *htf, C_SMC_Engine *itf) {
            m_engHTF = htf;
            m_engITF = itf;
            m_prefix = "DL_QUANT_";
            m_height = 95;
            m_colWidth = 170;
            m_offsetLeft = 5;
            m_dataReady = false;

            // Initialize default QUANT data
            ZeroMemory(m_quant);
            m_quant.decision = "READY";
            m_quant.confidence = 0;
            m_quant.comment = "Awaiting QUANT analysis...";
            m_quant.regime = "UNKNOWN";
            m_quant.trend_dir = "NONE";
            m_quant.prob_profit = 50;
      }

      ~C_QuantDashboard() { ObjectsDeleteAll(0, m_prefix); }

      // Update QUANT data from Colab response
      void UpdateQuantData(QuantResponse &data) {
            m_quant = data;
            m_dataReady = true;
            Update();
      }

      // Reset to waiting state
      void SetWaiting() {
            m_quant.decision = "COMPUTING";
            m_quant.comment = "Processing QUANT analysis...";
            Update();
      }

      void Update() {
            int x = m_offsetLeft + 5;
            int yH = 5;    // Header Y
            int y1 = 25;   // Row 1
            int y2 = 42;   // Row 2
            int y3 = 59;   // Row 3
            int y4 = 76;   // Row 4

            // ================================================================
            // COLUMN 1: RISK METRICS
            // ================================================================
            CreateRect(m_prefix+"H1_BG", x-3, yH-2, m_colWidth-5, 16, COLOR_Q_HEADER);
            CreateText(m_prefix+"H1", "RISK METRICS", x+3, yH, COLOR_Q_CYAN, 8, true);

            // VaR
            color cVar = (m_quant.var_95 > -30) ? COLOR_Q_UP : COLOR_Q_DN;
            CreateText(m_prefix+"L1_1", "VaR 95%:", x, y1, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V1_1", DoubleToString(m_quant.var_95, 1)+" pips", x+55, y1, cVar, 8);

            // CVaR
            CreateText(m_prefix+"L1_2", "CVaR:", x, y2, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V1_2", DoubleToString(m_quant.cvar, 1)+" pips", x+55, y2, cVar, 8);

            // Sharpe
            color cSharpe = GetRiskColor(m_quant.sharpe, 1.0, 0);
            CreateText(m_prefix+"L1_3", "Sharpe:", x, y3, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V1_3", DoubleToString(m_quant.sharpe, 2), x+55, y3, cSharpe, 8, true);

            // Sortino
            color cSortino = GetRiskColor(m_quant.sortino, 1.5, 0);
            CreateText(m_prefix+"L1_4", "Sortino:", x, y4, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V1_4", DoubleToString(m_quant.sortino, 2), x+55, y4, cSortino, 8);

            // ================================================================
            // COLUMN 2: VOLATILITY & DRAWDOWN
            // ================================================================
            x += m_colWidth;
            CreateRect(m_prefix+"H2_BG", x-3, yH-2, m_colWidth-5, 16, COLOR_Q_HEADER);
            CreateText(m_prefix+"H2", "VOL & DD", x+3, yH, COLOR_Q_CYAN, 8, true);

            // Volatility
            color cVol = (m_quant.volatility < 15) ? COLOR_Q_UP : (m_quant.volatility < 25 ? COLOR_Q_WARN : COLOR_Q_DN);
            CreateText(m_prefix+"L2_1", "Vol (ann):", x, y1, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V2_1", DoubleToString(m_quant.volatility, 1)+"%", x+60, y1, cVol, 8, true);

            // Max Drawdown
            color cDD = (m_quant.max_dd > -5) ? COLOR_Q_UP : (m_quant.max_dd > -15 ? COLOR_Q_WARN : COLOR_Q_DN);
            CreateText(m_prefix+"L2_2", "Max DD:", x, y2, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V2_2", DoubleToString(m_quant.max_dd, 1)+"%", x+60, y2, cDD, 8);

            // Skewness
            color cSkew = (MathAbs(m_quant.skewness) < 0.5) ? COLOR_Q_UP : COLOR_Q_WARN;
            CreateText(m_prefix+"L2_3", "Skew:", x, y3, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V2_3", DoubleToString(m_quant.skewness, 2), x+60, y3, cSkew, 8);

            // Kurtosis
            color cKurt = (m_quant.kurtosis < 3) ? COLOR_Q_UP : COLOR_Q_WARN;
            CreateText(m_prefix+"L2_4", "Kurt:", x, y4, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V2_4", DoubleToString(m_quant.kurtosis, 2), x+60, y4, cKurt, 8);

            // ================================================================
            // COLUMN 3: REGIME ANALYSIS
            // ================================================================
            x += m_colWidth;
            CreateRect(m_prefix+"H3_BG", x-3, yH-2, m_colWidth-5, 16, COLOR_Q_HEADER);
            CreateText(m_prefix+"H3", "REGIME", x+3, yH, COLOR_Q_CYAN, 8, true);

            // Regime type
            color cRegime = COLOR_Q_NEUT;
            if(m_quant.regime == "LOW_VOLATILITY") cRegime = COLOR_Q_UP;
            else if(m_quant.regime == "HIGH_VOLATILITY") cRegime = COLOR_Q_DN;
            else if(m_quant.regime == "NORMAL") cRegime = COLOR_Q_ACCENT;

            CreateText(m_prefix+"L3_1", "State:", x, y1, COLOR_Q_LABEL, 7);
            string regimeShort = m_quant.regime;
            if(regimeShort == "LOW_VOLATILITY") regimeShort = "LOW VOL";
            else if(regimeShort == "HIGH_VOLATILITY") regimeShort = "HIGH VOL";
            CreateText(m_prefix+"V3_1", regimeShort, x+45, y1, cRegime, 8, true);

            // Regime confidence
            CreateText(m_prefix+"L3_2", "Conf:", x, y2, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V3_2", IntegerToString(m_quant.regime_conf)+"%", x+45, y2, COLOR_Q_TEXT, 8);
            CreateMiniBar(m_prefix+"RG_BAR", x+80, y2+2, 70, 6, (double)m_quant.regime_conf, cRegime);

            // Structure bias (from engines)
            string bH, bI; color cH, cI;
            GetBiasState(m_engHTF, bH, cH);
            GetBiasState(m_engITF, bI, cI);

            CreateText(m_prefix+"L3_3", "H4:", x, y3, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V3_3", bH, x+30, y3, cH, 8, true);
            CreateText(m_prefix+"L3_3b", "H1:", x+70, y3, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V3_3b", bI, x+95, y3, cI, 8, true);

            // Anomaly status
            color cAnom = m_quant.is_anomaly ? COLOR_Q_DN : COLOR_Q_UP;
            string anomStr = m_quant.is_anomaly ? "DETECTED" : "NORMAL";
            CreateText(m_prefix+"L3_4", "Anomaly:", x, y4, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V3_4", anomStr, x+55, y4, cAnom, 8, m_quant.is_anomaly);

            // ================================================================
            // COLUMN 4: TREND QUANT
            // ================================================================
            x += m_colWidth;
            CreateRect(m_prefix+"H4_BG", x-3, yH-2, m_colWidth-5, 16, COLOR_Q_HEADER);
            CreateText(m_prefix+"H4", "TREND QUANT", x+3, yH, COLOR_Q_CYAN, 8, true);

            // Trend direction
            color cTrend = (m_quant.trend_dir == "UP") ? COLOR_Q_UP : (m_quant.trend_dir == "DOWN" ? COLOR_Q_DN : COLOR_Q_NEUT);
            CreateText(m_prefix+"L4_1", "Dir:", x, y1, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V4_1", m_quant.trend_dir, x+35, y1, cTrend, 9, true);

            // Trend strength (R-squared)
            color cStr = (m_quant.trend_strength > 60) ? COLOR_Q_UP : (m_quant.trend_strength > 30 ? COLOR_Q_WARN : COLOR_Q_NEUT);
            CreateText(m_prefix+"L4_2", "R^2:", x, y2, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V4_2", IntegerToString(m_quant.trend_strength)+"%", x+35, y2, cStr, 8, true);
            CreateMiniBar(m_prefix+"TR_BAR", x+75, y2+2, 75, 6, (double)m_quant.trend_strength, cStr);

            // ADR Info
            double adr=0;
            for(int k=1; k<=5; k++) adr += (iHigh(_Symbol, PERIOD_D1, k) - iLow(_Symbol, PERIOD_D1, k));
            adr /= 5.0;
            double rng = iHigh(_Symbol, PERIOD_D1, 0) - iLow(_Symbol, PERIOD_D1, 0);
            double adrPct = (adr > 0) ? (rng/adr*100.0) : 0;

            color cADR = (adrPct < 70) ? COLOR_Q_UP : (adrPct < 100 ? COLOR_Q_WARN : COLOR_Q_DN);
            CreateText(m_prefix+"L4_3", "ADR used:", x, y3, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V4_3", DoubleToString(adrPct, 0)+"%", x+60, y3, cADR, 8);

            // Spread
            long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
            color cSpr = (spread < 12) ? COLOR_Q_UP : COLOR_Q_DN;
            CreateText(m_prefix+"L4_4", "Spread:", x, y4, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V4_4", IntegerToString(spread)+" pts", x+50, y4, cSpr, 8);

            // ================================================================
            // COLUMN 5: PROBABILITY
            // ================================================================
            x += m_colWidth;
            CreateRect(m_prefix+"H5_BG", x-3, yH-2, m_colWidth-5, 16, COLOR_Q_HEADER);
            CreateText(m_prefix+"H5", "PROBABILITY", x+3, yH, COLOR_Q_PURPLE, 8, true);

            // Probability of profit
            color cProb = (m_quant.prob_profit >= 60) ? COLOR_Q_UP : (m_quant.prob_profit >= 45 ? COLOR_Q_WARN : COLOR_Q_DN);
            CreateText(m_prefix+"L5_1", "P(Win):", x, y1, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V5_1", IntegerToString(m_quant.prob_profit)+"%", x+50, y1, cProb, 10, true);
            CreateMiniBar(m_prefix+"PR_BAR", x+90, y1+2, 60, 8, (double)m_quant.prob_profit, cProb);

            // Expected return
            color cExp = (m_quant.expected_ret > 0) ? COLOR_Q_UP : COLOR_Q_DN;
            CreateText(m_prefix+"L5_2", "E[R]:", x, y2, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V5_2", DoubleToString(m_quant.expected_ret, 1)+" pips", x+50, y2, cExp, 8);

            // Monte Carlo simulation indicator
            CreateText(m_prefix+"L5_3", "MC Sims:", x, y3, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V5_3", "1000", x+55, y3, COLOR_Q_ACCENT, 8);

            // Time
            string timeStr = TimeToString(TimeLocal(), TIME_MINUTES|TIME_SECONDS);
            CreateText(m_prefix+"L5_4", "Time:", x, y4, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V5_4", timeStr, x+40, y4, COLOR_Q_TEXT, 8);

            // ================================================================
            // COLUMN 6: QUANT DECISION
            // ================================================================
            x += m_colWidth;
            CreateRect(m_prefix+"H6_BG", x-3, yH-2, m_colWidth, 16, COLOR_Q_HEADER);
            CreateText(m_prefix+"H6", "QUANT DECISION", x+3, yH, COLOR_Q_CYAN, 8, true);

            // Decision
            color cDec = COLOR_Q_NEUT;
            if(m_quant.decision == "EXECUTE") cDec = COLOR_Q_UP;
            else if(m_quant.decision == "WAIT" || m_quant.decision == "COMPUTING") cDec = COLOR_Q_WARN;
            else if(m_quant.decision == "DANGER") cDec = COLOR_Q_DN;

            CreateText(m_prefix+"L6_1", "Signal:", x, y1, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V6_1", m_quant.decision, x+48, y1, cDec, 11, true);

            // Confidence
            color cConf = (m_quant.confidence >= 70) ? COLOR_Q_UP : (m_quant.confidence >= 50 ? COLOR_Q_WARN : COLOR_Q_NEUT);
            CreateText(m_prefix+"L6_2", "Conf:", x, y2, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V6_2", IntegerToString(m_quant.confidence)+"%", x+40, y2, cConf, 9, true);
            CreateMiniBar(m_prefix+"CF_BAR", x+80, y2+2, 75, 7, (double)m_quant.confidence, cConf);

            // Mode indicator
            string mode = m_dataReady ? "QUANT" : "STANDBY";
            color cMode = m_dataReady ? COLOR_Q_CYAN : COLOR_Q_NEUT;
            CreateText(m_prefix+"L6_3", "Mode:", x, y3, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V6_3", mode, x+40, y3, cMode, 8);

            // Engine status
            CreateText(m_prefix+"L6_4", "Engine:", x, y4, COLOR_Q_LABEL, 7);
            CreateText(m_prefix+"V6_4", "COLAB", x+48, y4, COLOR_Q_ACCENT, 8, true);

            // ================================================================
            // COLUMN 7: SYNTHESIS (Expanding)
            // ================================================================
            long chartWidth = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
            int startX_Col7 = x + m_colWidth + 5;
            int width7 = (int)(chartWidth - startX_Col7 - 10);
            if(width7 < 200) width7 = 200;

            x += m_colWidth + 5;

            CreateRect(m_prefix+"H7_BG", x-3, yH-2, width7, 16, COLOR_Q_HEADER);
            CreateText(m_prefix+"H7", "QUANT SYNTHESIS", x+3, yH, COLOR_Q_CYAN, 8, true);

            // Comment - split into lines if needed
            string comment = m_quant.comment;
            if(StringLen(comment) > 80) comment = StringSubstr(comment, 0, 77) + "...";

            CreateText(m_prefix+"V7_1", comment, x+3, y1, COLOR_Q_TEXT, 8, false);

            // Quick summary line
            string summary = "Sharpe:" + DoubleToString(m_quant.sharpe,1) +
                           " | Vol:" + DoubleToString(m_quant.volatility,0) + "%" +
                           " | P(W):" + IntegerToString(m_quant.prob_profit) + "%";
            CreateText(m_prefix+"V7_2", summary, x+3, y2, COLOR_Q_LABEL, 7);

            // Risk summary
            string riskSum = "VaR:" + DoubleToString(m_quant.var_95,1) + "p" +
                           " | DD:" + DoubleToString(m_quant.max_dd,1) + "%" +
                           " | " + m_quant.regime;
            CreateText(m_prefix+"V7_3", riskSum, x+3, y3, COLOR_Q_LABEL, 7);

            // Timestamp
            CreateText(m_prefix+"V7_4", "Last update: " + TimeToString(TimeLocal(), TIME_SECONDS), x+3, y4, COLOR_Q_NEUT, 7);

            // --- BUTTON POSITIONING ---
            if(ObjectFind(0, "BTN_QUANT") >= 0) {
                  ObjectSetInteger(0, "BTN_QUANT", OBJPROP_CORNER, CORNER_LEFT_UPPER);
                  ObjectSetInteger(0, "BTN_QUANT", OBJPROP_XDISTANCE, x + width7 - 115);
                  ObjectSetInteger(0, "BTN_QUANT", OBJPROP_YDISTANCE, yH - 1);
                  ObjectSetInteger(0, "BTN_QUANT", OBJPROP_XSIZE, 110);
                  ObjectSetInteger(0, "BTN_QUANT", OBJPROP_YSIZE, 14);
                  ObjectSetInteger(0, "BTN_QUANT", OBJPROP_ZORDER, 15);
                  ObjectSetInteger(0, "BTN_QUANT", OBJPROP_FONTSIZE, 7);
            }

            ChartRedraw(0);
      }
};
