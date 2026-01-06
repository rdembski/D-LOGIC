//+------------------------------------------------------------------+
//|                                               D-LOGIC_QUANT.mq5 |
//|                   QUANT Analytics Dashboard for EURUSD DayTrading|
//|                                        Author: RafaB Dembski    |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"
#property description "Professional QUANT Analytics Dashboard - Google Colab Integration"
#property version   "5.00"

#include "DLogic_Structs.mqh"
#include "DLogic_GUI.mqh"
#include "DLogic_SMC.mqh"
#include "DLogic_Patterns.mqh"
#include "DLogic_SR.mqh"
#include "DLogic_Turtle.mqh"
#include "DLogic_CRT.mqh"
#include "DLogic_QuantBridge.mqh"  // QUANT Bridge (includes QuantDash)

// --- INPUTS: TIMEFRAMES ---
input group "=== D-LOGIC: TIME SETTINGS ==="
input ENUM_TIMEFRAMES Inp_HTF_Frame = PERIOD_H4;
input ENUM_TIMEFRAMES Inp_ITF_Frame = PERIOD_H1;
input ENUM_TIMEFRAMES Inp_LTF_Frame = PERIOD_M5;

// --- INPUTS: SESSION ---
input group "=== D-LOGIC: TIME & SESSION (UTC) ==="
input int Inp_BrokerOffsetUTC = 2;
input int Inp_LondonOpen      = 7;
input int Inp_LondonClose     = 10;
input int Inp_NYOpen          = 12;
input int Inp_NYClose         = 15;

// --- INPUTS: VOLATILITY ---
input group "=== D-LOGIC: VOLATILITY MULTIPLIERS ==="
input double Inp_Mult_London    = 1.4;
input double Inp_Mult_LdnClose  = 1.3;
input double Inp_Mult_NY        = 1.6;
input double Inp_Mult_Asia      = 0.9;
input double Inp_Mult_Dead      = 0.7;

// --- INPUTS: STRUCTURE ---
input group "=== D-LOGIC: DUAL-SWING STRUCTURE ==="
input int Inp_SwingMinor = 2;
input int Inp_SwingMajor = 10;

// --- INPUTS: FILTERS ---
input group "=== D-LOGIC: INSTITUTIONAL FILTERS ==="
input double Inp_OB_Displacement = 1.5;
input bool   Inp_OB_VolFilter    = true;
input double Inp_FVG_MinSize     = 0.05;
input int    Inp_FVG_Decay       = 20;

// --- INPUTS: QUANT COLAB ---
input group "=== D-LOGIC: QUANT ENGINE (GOOGLE COLAB) ==="
input string Inp_ColabURL = "http://127.0.0.1:5000/analyze"; // Colab ngrok URL

// --- GLOBAL POINTERS ---
C_SMC_Engine       *Engine_HTF;
C_SMC_Engine       *Engine_ITF;
C_SMC_Engine       *Engine_LTF;

C_Pattern_Engine   *Pat_HTF;
C_Pattern_Engine   *Pat_ITF;
C_Pattern_Engine   *Pat_LTF;

C_SR_Engine        *SR_HTF;
C_SR_Engine        *SR_ITF;
C_SR_Engine        *SR_LTF;

C_Turtle_Engine    *Trtl;
C_CRT_Engine       *Crt;

C_BottomPanel      *GuiPanel;
C_QuantDashboard   *QuantDash;    // New QUANT Dashboard
C_QuantBridge      *QuantBridge;  // New QUANT Bridge

//+------------------------------------------------------------------+
//| Safe History Download with Retry                                  |
//+------------------------------------------------------------------+
bool DownloadHistory(ENUM_TIMEFRAMES tf) {
      int attempts = 0;
      datetime times[];

      while(attempts < 5) {
            if(SeriesInfoInteger(_Symbol, tf, SERIES_SYNCHRONIZED)) {
                  if(CopyTime(_Symbol, tf, 0, 100, times) > 0) return true;
            }

            bool data_ready = SeriesInfoInteger(_Symbol, tf, SERIES_BARS_COUNT) > 100;
            if(!data_ready) {
                  Print("--- D-LOGIC: Waiting for history data (", EnumToString(tf), ")... Attempt: ", attempts+1);
                  Sleep(250);
            } else {
                  return true;
            }
            attempts++;
      }

      Print("--- D-LOGIC CRITICAL ERROR: Failed to download history for ", EnumToString(tf));
      return false;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
      Print("=== D-LOGIC QUANT ENGINE INIT (v5.00) ===");

      // 1. Validate timeframes
      if(Inp_LTF_Frame >= Inp_ITF_Frame || Inp_ITF_Frame >= Inp_HTF_Frame) {
            Alert("Error: Timeframes must be LTF < ITF < HTF");
            return(INIT_PARAMETERS_INCORRECT);
      }

      // 2. Download history
      string sym = _Symbol;
      if(!DownloadHistory(Inp_HTF_Frame)) return(INIT_FAILED);
      if(!DownloadHistory(Inp_ITF_Frame)) return(INIT_FAILED);
      if(!DownloadHistory(Inp_LTF_Frame)) return(INIT_FAILED);

      // 3. Build GUI (bottom panel)
      GuiPanel = new C_BottomPanel();
      GuiPanel.BuildInterface();

      // 4. Initialize SMC Engines
      Engine_HTF = new C_SMC_Engine(sym, Inp_HTF_Frame, Inp_SwingMinor, Inp_SwingMajor, COLOR_THEME_HTF);
      Engine_ITF = new C_SMC_Engine(sym, Inp_ITF_Frame, Inp_SwingMinor, Inp_SwingMajor, COLOR_THEME_ITF);
      Engine_LTF = new C_SMC_Engine(sym, Inp_LTF_Frame, Inp_SwingMinor, Inp_SwingMajor, COLOR_THEME_LTF);

      // Configure filters
      Engine_HTF.SetFilters(Inp_OB_Displacement, Inp_OB_VolFilter, Inp_FVG_MinSize, Inp_FVG_Decay, Inp_BrokerOffsetUTC, Inp_LondonOpen, Inp_LondonClose, Inp_NYOpen, Inp_NYClose);
      Engine_ITF.SetFilters(Inp_OB_Displacement, Inp_OB_VolFilter, Inp_FVG_MinSize, Inp_FVG_Decay, Inp_BrokerOffsetUTC, Inp_LondonOpen, Inp_LondonClose, Inp_NYOpen, Inp_NYClose);
      Engine_LTF.SetFilters(Inp_OB_Displacement, Inp_OB_VolFilter, Inp_FVG_MinSize, Inp_FVG_Decay, Inp_BrokerOffsetUTC, Inp_LondonOpen, Inp_LondonClose, Inp_NYOpen, Inp_NYClose);

      Engine_HTF.SetVolatilityParams(Inp_Mult_London, Inp_Mult_LdnClose, Inp_Mult_NY, Inp_Mult_Asia, Inp_Mult_Dead);
      Engine_ITF.SetVolatilityParams(Inp_Mult_London, Inp_Mult_LdnClose, Inp_Mult_NY, Inp_Mult_Asia, Inp_Mult_Dead);
      Engine_LTF.SetVolatilityParams(Inp_Mult_London, Inp_Mult_LdnClose, Inp_Mult_NY, Inp_Mult_Asia, Inp_Mult_Dead);

      // Default visibility
      Engine_HTF.ToggleSwings(true); Engine_ITF.ToggleSwings(true); Engine_LTF.ToggleSwings(false);
      Engine_HTF.ToggleFVG(false);   Engine_ITF.ToggleFVG(false);   Engine_LTF.ToggleFVG(false);
      Engine_HTF.ToggleOB(false);    Engine_ITF.ToggleOB(false);    Engine_LTF.ToggleOB(false);
      Engine_HTF.ToggleLiq(false);   Engine_ITF.ToggleLiq(false);   Engine_LTF.ToggleLiq(false);
      Engine_HTF.ToggleCISD(false);  Engine_ITF.ToggleCISD(false);  Engine_LTF.ToggleCISD(false);

      // 5. Initialize Patterns
      Pat_HTF = new C_Pattern_Engine(sym, Inp_HTF_Frame);
      Pat_ITF = new C_Pattern_Engine(sym, Inp_ITF_Frame);
      Pat_LTF = new C_Pattern_Engine(sym, Inp_LTF_Frame);
      Pat_LTF.BindSMCEngines(Engine_HTF, Engine_ITF);
      Pat_ITF.BindSMCEngines(Engine_HTF, NULL);
      Pat_HTF.BindSMCEngines(NULL, NULL);

      // 6. Initialize S&R
      SR_HTF = new C_SR_Engine(sym, Inp_HTF_Frame);
      SR_ITF = new C_SR_Engine(sym, Inp_ITF_Frame);
      SR_LTF = new C_SR_Engine(sym, Inp_LTF_Frame);

      // 7. Initialize Entry Models
      Trtl = new C_Turtle_Engine(sym, PERIOD_CURRENT);
      Crt  = new C_CRT_Engine(sym, PERIOD_CURRENT);

      // 8. Initial scan
      Engine_HTF.RunInitialScan(1000);
      Engine_ITF.RunInitialScan(1000);
      Engine_LTF.RunInitialScan(1000);

      // 9. Initialize QUANT Dashboard
      QuantDash = new C_QuantDashboard(Engine_HTF, Engine_ITF);
      QuantDash.Update();

      // 10. Initialize QUANT Bridge
      QuantBridge = new C_QuantBridge();
      QuantBridge.SetEndpoint(Inp_ColabURL);

      // 11. Create QUANT button
      if(ObjectFind(0, "BTN_QUANT") < 0) {
            ObjectCreate(0, "BTN_QUANT", OBJ_BUTTON, 0, 0, 0);
            ObjectSetInteger(0, "BTN_QUANT", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
            ObjectSetInteger(0, "BTN_QUANT", OBJPROP_XDISTANCE, 10);
            ObjectSetInteger(0, "BTN_QUANT", OBJPROP_YDISTANCE, 30);
            ObjectSetInteger(0, "BTN_QUANT", OBJPROP_XSIZE, 140);
            ObjectSetInteger(0, "BTN_QUANT", OBJPROP_YSIZE, 28);
            ObjectSetString(0, "BTN_QUANT", OBJPROP_TEXT, "RUN QUANT ANALYSIS");
            ObjectSetInteger(0, "BTN_QUANT", OBJPROP_BGCOLOR, C'0,100,180');
            ObjectSetInteger(0, "BTN_QUANT", OBJPROP_COLOR, clrWhite);
            ObjectSetString(0, "BTN_QUANT", OBJPROP_FONT, "Consolas Bold");
            ObjectSetInteger(0, "BTN_QUANT", OBJPROP_FONTSIZE, 8);
      }

      EventSetMillisecondTimer(500);
      Print("=== D-LOGIC QUANT ENGINE READY ===");
      return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
      EventKillTimer();

      if(CheckPointer(QuantDash)   == POINTER_DYNAMIC) delete QuantDash;
      if(CheckPointer(QuantBridge) == POINTER_DYNAMIC) delete QuantBridge;

      if(CheckPointer(Pat_LTF)     == POINTER_DYNAMIC) delete Pat_LTF;
      if(CheckPointer(Pat_ITF)     == POINTER_DYNAMIC) delete Pat_ITF;
      if(CheckPointer(Pat_HTF)     == POINTER_DYNAMIC) delete Pat_HTF;

      if(CheckPointer(SR_LTF)      == POINTER_DYNAMIC) delete SR_LTF;
      if(CheckPointer(SR_ITF)      == POINTER_DYNAMIC) delete SR_ITF;
      if(CheckPointer(SR_HTF)      == POINTER_DYNAMIC) delete SR_HTF;

      if(CheckPointer(Trtl)        == POINTER_DYNAMIC) delete Trtl;
      if(CheckPointer(Crt)         == POINTER_DYNAMIC) delete Crt;

      if(CheckPointer(Engine_LTF)  == POINTER_DYNAMIC) delete Engine_LTF;
      if(CheckPointer(Engine_ITF)  == POINTER_DYNAMIC) delete Engine_ITF;
      if(CheckPointer(Engine_HTF)  == POINTER_DYNAMIC) delete Engine_HTF;

      if(CheckPointer(GuiPanel)    == POINTER_DYNAMIC) delete GuiPanel;

      ObjectDelete(0, "BTN_QUANT");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
      if(Engine_HTF) Engine_HTF.OnTick();
      if(Engine_ITF) Engine_ITF.OnTick();
      if(Engine_LTF) Engine_LTF.OnTick();

      if(Pat_HTF) Pat_HTF.OnTick();
      if(Pat_ITF) Pat_ITF.OnTick();
      if(Pat_LTF) Pat_LTF.OnTick();

      if(SR_HTF) SR_HTF.OnTick();
      if(SR_ITF) SR_ITF.OnTick();
      if(SR_LTF) SR_LTF.OnTick();

      if(Trtl) Trtl.OnTick();
      if(Crt) Crt.OnTick();
}

void OnTimer() {
      if(QuantDash) QuantDash.Update();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
      if(id == CHARTEVENT_CHART_CHANGE) {
            if(QuantDash) QuantDash.Update();
      }

      // --- QUANT BUTTON HANDLER ---
      if(id == CHARTEVENT_OBJECT_CLICK && sparam == "BTN_QUANT") {
            Print(">>> D-LOGIC: INITIALIZING QUANT ANALYSIS...");
            ObjectSetInteger(0, "BTN_QUANT", OBJPROP_STATE, false);
            ObjectSetString(0, "BTN_QUANT", OBJPROP_TEXT, "COMPUTING...");
            ObjectSetInteger(0, "BTN_QUANT", OBJPROP_BGCOLOR, clrOrange);
            ChartRedraw();

            if(QuantDash) QuantDash.SetWaiting();

            // 1. COLLECT DATA
            int bH = Engine_HTF.GetStructureBias();
            int bI = Engine_ITF.GetStructureBias();
            string h4_str = (bH == 1) ? "BULLISH" : (bH == -1 ? "BEARISH" : "NEUTRAL");
            string h1_str = (bI == 1) ? "BULLISH" : (bI == -1 ? "BEARISH" : "NEUTRAL");

            string zone = Engine_LTF.GetZoneInteraction();

            double dH = Engine_HTF.GetDistToLiquidity(true);
            double dL = Engine_HTF.GetDistToLiquidity(false);
            string liq_stat = "PDH=" + (dH==-1?"SWEEP":DoubleToString(dH/_Point,0)+"pts") + " PDL=" + (dL==-1?"SWEEP":DoubleToString(dL/_Point,0)+"pts");

            string cDir, cTime; Engine_LTF.GetLastCISD(cDir, cTime);
            string tDir, tTime; Trtl.GetLastSweepStatus(tDir, tTime);
            string sigs = "CISD:" + cDir + " TRTL:" + tDir;

            string sess_time = TimeToString(TimeCurrent());

            // 2. SEND QUERY TO COLAB
            QuantResponse quant_res;
            if(QuantBridge.SendQuery(h4_str, h1_str, zone, liq_stat, sigs, sess_time, quant_res)) {

                  Print("[QUANT] Decision: ", quant_res.decision);
                  Print("[QUANT] Sharpe: ", quant_res.sharpe, " | Sortino: ", quant_res.sortino);
                  Print("[QUANT] VaR: ", quant_res.var_95, " pips | Vol: ", quant_res.volatility, "%");
                  Print("[QUANT] Regime: ", quant_res.regime, " | P(Win): ", quant_res.prob_profit, "%");
                  Print("[QUANT] Comment: ", quant_res.comment);

                  // Update button
                  ObjectSetString(0, "BTN_QUANT", OBJPROP_TEXT, "QUANT: " + quant_res.decision);

                  color cRes = clrGray;
                  if(quant_res.decision == "EXECUTE") cRes = clrGreen;
                  else if(quant_res.decision == "WAIT") cRes = clrOrange;
                  else if(quant_res.decision == "DANGER") cRes = clrRed;

                  ObjectSetInteger(0, "BTN_QUANT", OBJPROP_BGCOLOR, cRes);

                  // Update dashboard
                  QuantDash.UpdateQuantData(quant_res);

            } else {
                  Print("[QUANT] CONNECTION ERROR");
                  ObjectSetString(0, "BTN_QUANT", OBJPROP_TEXT, "CONNECTION ERROR");
                  ObjectSetInteger(0, "BTN_QUANT", OBJPROP_BGCOLOR, clrRed);
            }
            ChartRedraw();
            return;
      }

      // --- BOTTOM PANEL HANDLER ---
      if(id == CHARTEVENT_OBJECT_CLICK) {
            if(StringFind(sparam, "DL_GUI_BTN_") >= 0) {

                  bool state = (bool)ObjectGetInteger(0, sparam, OBJPROP_STATE);
                  color activeCol = clrGray;
                  C_SMC_Engine *targetEngine = NULL;

                  // 1. Structure
                  if(StringFind(sparam, "SW_") >= 0) {
                        if(StringFind(sparam, "HTF") >= 0) { activeCol = COLOR_THEME_HTF; targetEngine = Engine_HTF; }
                        if(StringFind(sparam, "ITF") >= 0) { activeCol = COLOR_THEME_ITF; targetEngine = Engine_ITF; }
                        if(StringFind(sparam, "LTF") >= 0) { activeCol = COLOR_THEME_LTF; targetEngine = Engine_LTF; }
                        GuiPanel.UpdateColor(sparam, activeCol, state);
                        if(targetEngine) targetEngine.ToggleSwings(state);
                  }
                  // 2. FVG
                  else if(StringFind(sparam, "FVG_") >= 0) {
                        if(StringFind(sparam, "HTF") >= 0) { activeCol = COLOR_THEME_HTF; targetEngine = Engine_HTF; }
                        if(StringFind(sparam, "ITF") >= 0) { activeCol = COLOR_THEME_ITF; targetEngine = Engine_ITF; }
                        if(StringFind(sparam, "LTF") >= 0) { activeCol = COLOR_THEME_LTF; targetEngine = Engine_LTF; }
                        GuiPanel.UpdateColor(sparam, activeCol, state);
                        if(targetEngine) targetEngine.ToggleFVG(state);
                  }
                  // 3. OB
                  else if(StringFind(sparam, "OB_") >= 0) {
                        if(StringFind(sparam, "HTF") >= 0) { activeCol = COLOR_THEME_HTF; targetEngine = Engine_HTF; }
                        if(StringFind(sparam, "ITF") >= 0) { activeCol = COLOR_THEME_ITF; targetEngine = Engine_ITF; }
                        if(StringFind(sparam, "LTF") >= 0) { activeCol = COLOR_THEME_LTF; targetEngine = Engine_LTF; }
                        GuiPanel.UpdateColor(sparam, activeCol, state);
                        if(targetEngine) targetEngine.ToggleOB(state);
                  }
                  // 4. S&R
                  else if(StringFind(sparam, "SR_") >= 0) {
                        C_SR_Engine *targetSR = NULL;
                        if(StringFind(sparam, "HTF") >= 0) { activeCol = COLOR_THEME_HTF; targetSR = SR_HTF; }
                        if(StringFind(sparam, "ITF") >= 0) { activeCol = COLOR_THEME_ITF; targetSR = SR_ITF; }
                        if(StringFind(sparam, "LTF") >= 0) { activeCol = COLOR_THEME_LTF; targetSR = SR_LTF; }
                        GuiPanel.UpdateColor(sparam, activeCol, state);
                        if(targetSR) targetSR.Toggle(state);
                  }
                  // 5. Liquidity
                  else if(StringFind(sparam, "LIQ_ALL") >= 0) {
                        GuiPanel.UpdateColor(sparam, COLOR_THEME_HTF, state);
                        if(Engine_HTF) Engine_HTF.ToggleLiq(state);
                        if(Engine_ITF) Engine_ITF.ToggleLiq(state);
                        if(Engine_LTF) Engine_LTF.ToggleLiq(state);
                  }
                  // 6. Entry Models
                  else if(StringFind(sparam, "CISD_ALL") >= 0) {
                        GuiPanel.UpdateColor(sparam, COLOR_THEME_LTF, state);
                        if(Engine_LTF) Engine_LTF.ToggleCISD(state);
                  }
                  else if(StringFind(sparam, "TRTL_ALL") >= 0) {
                        GuiPanel.UpdateColor(sparam, COLOR_THEME_LTF, state);
                        if(Trtl) Trtl.Toggle(state);
                  }
                  else if(StringFind(sparam, "CRT_ALL") >= 0) {
                        GuiPanel.UpdateColor(sparam, COLOR_THEME_LTF, state);
                        if(Crt) Crt.Toggle(state);
                  }
                  // 7. Fibo
                  else if(StringFind(sparam, "FIB_") >= 0) {
                        ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
                        color c = clrGray;
                        if(StringFind(sparam, "D1") >= 0) { tf = PERIOD_D1; c = clrGoldenrod; }
                        if(StringFind(sparam, "W1") >= 0) { tf = PERIOD_W1; c = clrOrangeRed; }
                        if(StringFind(sparam, "MN") >= 0) { tf = PERIOD_MN1; c = clrDeepPink; }
                        GuiPanel.UpdateColor(sparam, c, state);
                        if(Engine_HTF) Engine_HTF.ToggleFibo(tf, state);
                  }
                  // 8. Patterns
                  else if(StringFind(sparam, "PAT_") >= 0) {
                        C_Pattern_Engine *targetPat = NULL;
                        if(StringFind(sparam, "HTF") >= 0) { activeCol = COLOR_THEME_HTF; targetPat = Pat_HTF; }
                        if(StringFind(sparam, "ITF") >= 0) { activeCol = COLOR_THEME_ITF; targetPat = Pat_ITF; }
                        if(StringFind(sparam, "LTF") >= 0) { activeCol = COLOR_THEME_LTF; targetPat = Pat_LTF; }
                        GuiPanel.UpdateColor(sparam, activeCol, state);
                        if(targetPat) targetPat.TogglePatterns(state);
                  }

                  ChartRedraw(0);
            }
      }
}
