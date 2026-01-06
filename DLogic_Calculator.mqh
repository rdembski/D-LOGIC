//+------------------------------------------------------------------+
//|                                           DLogic_Calculator.mqh |
//|                          Project: D-LOGIC Trading Dashboard      |
//|                                        Author: RafaB Dembski    |
//|                   Advanced Position Size & Risk Calculator       |
//+------------------------------------------------------------------+
#property copyright "RafaB Dembski"
#property strict

// ============================================================
// COLOR SCHEME - Matching Dashboard Theme
// ============================================================
#define CALC_BG_MAIN       C'15,15,20'
#define CALC_BG_HEADER     C'0,80,150'
#define CALC_BG_INPUT      C'35,40,50'
#define CALC_BG_RESULT     C'25,50,40'
#define CALC_BG_WARNING    C'80,40,20'
#define CALC_BORDER        C'50,55,65'
#define CALC_TEXT          C'220,220,225'
#define CALC_TEXT_DIM      C'130,130,145'
#define CALC_HEADER        C'0,200,255'
#define CALC_POSITIVE      C'0,230,118'
#define CALC_NEGATIVE      C'255,82,82'
#define CALC_WARNING       C'255,193,7'
#define CALC_CYAN          C'0,229,255'
#define CALC_GOLD          C'255,215,0'

// ============================================================
// CALCULATOR STRUCTURE
// ============================================================
struct CalculatorResult {
   double   accountBalance;
   double   accountEquity;
   double   riskPercent;
   double   riskAmount;
   double   stopLossPips;
   double   takeProfitPips;
   double   entryPrice;
   double   stopLossPrice;
   double   takeProfitPrice;
   double   positionSize;       // In lots
   double   pipValue;           // Value of 1 pip for 1 lot
   double   pipValuePosition;   // Pip value for calculated position
   double   potentialLoss;
   double   potentialProfit;
   double   riskRewardRatio;
   double   marginRequired;
   double   freeMargin;
   double   marginLevel;
   int      leverage;
   string   symbol;
   bool     isBuy;
   string   warningMessage;
};

//+------------------------------------------------------------------+
//| Position Calculator Class                                         |
//+------------------------------------------------------------------+
class C_PositionCalculator {
private:
   string         m_prefix;
   int            m_startX;
   int            m_startY;
   int            m_width;
   int            m_height;
   bool           m_isVisible;
   bool           m_isMinimized;

   // Input values
   string         m_symbol;
   double         m_riskPercent;
   double         m_stopLossPips;
   double         m_takeProfitPips;
   double         m_entryPrice;
   bool           m_isBuy;

   // Calculated results
   CalculatorResult m_result;

   //+------------------------------------------------------------------+
   //| Create Rectangle                                                  |
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
      ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, (border == clrNONE) ? CALC_BORDER : border);
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
      ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, CALC_BORDER);
   }

   //+------------------------------------------------------------------+
   //| Create Edit Box                                                   |
   //+------------------------------------------------------------------+
   void CreateEdit(string name, string text, int x, int y, int w, int h, bool readOnly = false) {
      string objName = m_prefix + name;
      if(ObjectFind(0, objName) < 0) {
         ObjectCreate(0, objName, OBJ_EDIT, 0, 0, 0);
         ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      }
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, readOnly ? C'25,28,35' : CALC_BG_INPUT);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, CALC_TEXT);
      ObjectSetString(0, objName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, CALC_BORDER);
      ObjectSetInteger(0, objName, OBJPROP_READONLY, readOnly);
      ObjectSetInteger(0, objName, OBJPROP_ALIGN, ALIGN_RIGHT);
   }

   //+------------------------------------------------------------------+
   //| Get pip size for symbol                                           |
   //+------------------------------------------------------------------+
   double GetPipSize(string symbol) {
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      if(digits == 3 || digits == 5)
         return SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
      return SymbolInfoDouble(symbol, SYMBOL_POINT);
   }

   //+------------------------------------------------------------------+
   //| Get pip value for 1 lot                                           |
   //+------------------------------------------------------------------+
   double GetPipValue(string symbol) {
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double pipSize = GetPipSize(symbol);

      if(tickSize <= 0) return 0;

      return (pipSize / tickSize) * tickValue;
   }

   //+------------------------------------------------------------------+
   //| Calculate margin required                                         |
   //+------------------------------------------------------------------+
   double CalculateMargin(string symbol, double lots, bool isBuy) {
      double margin = 0;
      ENUM_ORDER_TYPE orderType = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double price = isBuy ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);

      if(!OrderCalcMargin(orderType, symbol, lots, price, margin)) {
         // Fallback calculation
         double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
         long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
         if(leverage <= 0) leverage = 100;
         margin = (lots * contractSize * price) / leverage;
      }

      return margin;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   C_PositionCalculator() {
      m_prefix = "DL_CALC_";
      m_startX = 10;
      m_startY = 450;
      m_width = 280;
      m_height = 320;
      m_isVisible = true;
      m_isMinimized = false;

      m_symbol = _Symbol;
      m_riskPercent = 1.0;
      m_stopLossPips = 50;
      m_takeProfitPips = 100;
      m_entryPrice = 0;
      m_isBuy = true;

      ZeroMemory(m_result);
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~C_PositionCalculator() {
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
      if(SymbolSelect(symbol, true)) {
         m_symbol = symbol;
         m_entryPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
      }
   }

   //+------------------------------------------------------------------+
   //| Set risk parameters                                               |
   //+------------------------------------------------------------------+
   void SetRiskParams(double riskPercent, double slPips, double tpPips) {
      m_riskPercent = MathMax(0.1, MathMin(100, riskPercent));
      m_stopLossPips = MathMax(1, slPips);
      m_takeProfitPips = MathMax(1, tpPips);
   }

   //+------------------------------------------------------------------+
   //| Toggle Buy/Sell                                                   |
   //+------------------------------------------------------------------+
   void SetDirection(bool isBuy) {
      m_isBuy = isBuy;
   }

   //+------------------------------------------------------------------+
   //| Calculate position size and all metrics                           |
   //+------------------------------------------------------------------+
   void Calculate() {
      ZeroMemory(m_result);
      m_result.warningMessage = "";

      // Account info
      m_result.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_result.accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_result.freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      m_result.leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);
      m_result.symbol = m_symbol;
      m_result.isBuy = m_isBuy;

      // Risk calculation
      m_result.riskPercent = m_riskPercent;
      m_result.riskAmount = m_result.accountBalance * (m_riskPercent / 100.0);

      // Pip values
      m_result.stopLossPips = m_stopLossPips;
      m_result.takeProfitPips = m_takeProfitPips;
      m_result.pipValue = GetPipValue(m_symbol);

      if(m_result.pipValue <= 0) {
         m_result.warningMessage = "Cannot calculate pip value";
         return;
      }

      // Position size = Risk Amount / (SL pips * Pip Value)
      m_result.positionSize = m_result.riskAmount / (m_stopLossPips * m_result.pipValue);

      // Round to broker's lot step
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);

      if(lotStep > 0) {
         m_result.positionSize = MathFloor(m_result.positionSize / lotStep) * lotStep;
      }

      // Apply limits
      if(m_result.positionSize < minLot) {
         m_result.positionSize = minLot;
         m_result.warningMessage = "Size adjusted to min lot";
      }
      if(m_result.positionSize > maxLot) {
         m_result.positionSize = maxLot;
         m_result.warningMessage = "Size limited to max lot";
      }

      // Pip value for this position
      m_result.pipValuePosition = m_result.pipValue * m_result.positionSize;

      // Entry price
      if(m_entryPrice <= 0) {
         m_result.entryPrice = m_isBuy ?
            SymbolInfoDouble(m_symbol, SYMBOL_ASK) :
            SymbolInfoDouble(m_symbol, SYMBOL_BID);
      } else {
         m_result.entryPrice = m_entryPrice;
      }

      // SL/TP prices
      double pipSize = GetPipSize(m_symbol);
      if(m_isBuy) {
         m_result.stopLossPrice = m_result.entryPrice - (m_stopLossPips * pipSize);
         m_result.takeProfitPrice = m_result.entryPrice + (m_takeProfitPips * pipSize);
      } else {
         m_result.stopLossPrice = m_result.entryPrice + (m_stopLossPips * pipSize);
         m_result.takeProfitPrice = m_result.entryPrice - (m_takeProfitPips * pipSize);
      }

      // Potential P/L
      m_result.potentialLoss = m_stopLossPips * m_result.pipValuePosition;
      m_result.potentialProfit = m_takeProfitPips * m_result.pipValuePosition;

      // Risk/Reward ratio
      if(m_result.potentialLoss > 0) {
         m_result.riskRewardRatio = m_result.potentialProfit / m_result.potentialLoss;
      }

      // Margin calculation
      m_result.marginRequired = CalculateMargin(m_symbol, m_result.positionSize, m_isBuy);

      // Margin level check
      if(m_result.marginRequired > m_result.freeMargin) {
         m_result.warningMessage = "Insufficient margin!";
      }

      // Margin level after trade
      double totalMargin = AccountInfoDouble(ACCOUNT_MARGIN) + m_result.marginRequired;
      if(totalMargin > 0) {
         m_result.marginLevel = (m_result.accountEquity / totalMargin) * 100;
      }
   }

   //+------------------------------------------------------------------+
   //| Draw calculator panel                                             |
   //+------------------------------------------------------------------+
   void Draw() {
      if(!m_isVisible) return;

      int x = m_startX;
      int y = m_startY;
      int w = m_width;

      // Main background
      CreateRect("BG", x, y, w, m_isMinimized ? 24 : m_height, CALC_BG_MAIN, CALC_CYAN);

      // Title bar
      CreateRect("TITLE_BG", x, y, w, 24, CALC_BG_HEADER, CALC_CYAN);
      CreateLabel("TITLE", "Position Calculator", x + 8, y + 5, CALC_TEXT, 9, "Consolas Bold");

      // Minimize button
      CreateButton("BTN_MIN", m_isMinimized ? "+" : "-", x + w - 25, y + 3, 20, 18, C'60,65,75', CALC_TEXT, 10);

      if(m_isMinimized) {
         ChartRedraw(0);
         return;
      }

      int row = 0;
      int rowH = 22;
      int labelX = x + 8;
      int valueX = x + 130;
      int inputW = 140;
      int inputH = 18;
      int startY = y + 30;

      // ===== INPUT SECTION =====
      CreateLabel("LBL_INPUTS", "--- INPUTS ---", labelX, startY + row * rowH, CALC_HEADER, 8);
      row++;

      // Symbol
      CreateLabel("LBL_SYM", "Symbol:", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      CreateEdit("EDT_SYM", m_symbol, valueX, startY + row * rowH, inputW, inputH, true);
      row++;

      // Risk %
      CreateLabel("LBL_RISK", "Risk %:", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      CreateEdit("EDT_RISK", DoubleToString(m_riskPercent, 2), valueX, startY + row * rowH, inputW, inputH);
      row++;

      // Stop Loss Pips
      CreateLabel("LBL_SL", "Stop Loss (pips):", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      CreateEdit("EDT_SL", DoubleToString(m_stopLossPips, 1), valueX, startY + row * rowH, inputW, inputH);
      row++;

      // Take Profit Pips
      CreateLabel("LBL_TP", "Take Profit (pips):", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      CreateEdit("EDT_TP", DoubleToString(m_takeProfitPips, 1), valueX, startY + row * rowH, inputW, inputH);
      row++;

      // Buy/Sell buttons
      CreateButton("BTN_BUY", "BUY", labelX, startY + row * rowH, 65, 20,
                   m_isBuy ? C'0,120,80' : C'40,45,55', CALC_TEXT, 8);
      CreateButton("BTN_SELL", "SELL", labelX + 70, startY + row * rowH, 65, 20,
                   !m_isBuy ? C'150,40,40' : C'40,45,55', CALC_TEXT, 8);
      CreateButton("BTN_CALC", "CALCULATE", valueX, startY + row * rowH, inputW, 20, C'0,100,150', CALC_TEXT, 8);
      row++;

      row++; // Spacing

      // ===== RESULTS SECTION =====
      CreateLabel("LBL_RESULTS", "--- RESULTS ---", labelX, startY + row * rowH, CALC_POSITIVE, 8);
      row++;

      // Position Size (main result)
      CreateRect("RES_BG", labelX - 3, startY + row * rowH - 2, w - 16, 24, CALC_BG_RESULT);
      CreateLabel("LBL_LOT", "Position Size:", labelX, startY + row * rowH + 2, CALC_TEXT, 8);
      CreateLabel("VAL_LOT", DoubleToString(m_result.positionSize, 2) + " lots", valueX, startY + row * rowH + 2, CALC_GOLD, 10, "Consolas Bold");
      row++;

      row++; // Extra spacing after main result

      // Risk Amount
      CreateLabel("LBL_RISKAMT", "Risk Amount:", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      string currency = AccountInfoString(ACCOUNT_CURRENCY);
      CreateLabel("VAL_RISKAMT", DoubleToString(m_result.riskAmount, 2) + " " + currency, valueX, startY + row * rowH + 2, CALC_WARNING, 8);
      row++;

      // Entry Price
      CreateLabel("LBL_ENTRY", "Entry Price:", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      int priceDigits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      CreateLabel("VAL_ENTRY", DoubleToString(m_result.entryPrice, priceDigits), valueX, startY + row * rowH + 2, CALC_TEXT, 8);
      row++;

      // Stop Loss Price
      CreateLabel("LBL_SLPRICE", "Stop Loss:", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      CreateLabel("VAL_SLPRICE", DoubleToString(m_result.stopLossPrice, priceDigits), valueX, startY + row * rowH + 2, CALC_NEGATIVE, 8);
      row++;

      // Take Profit Price
      CreateLabel("LBL_TPPRICE", "Take Profit:", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      CreateLabel("VAL_TPPRICE", DoubleToString(m_result.takeProfitPrice, priceDigits), valueX, startY + row * rowH + 2, CALC_POSITIVE, 8);
      row++;

      // Potential Loss
      CreateLabel("LBL_PLOSS", "Potential Loss:", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      CreateLabel("VAL_PLOSS", "-" + DoubleToString(m_result.potentialLoss, 2) + " " + currency, valueX, startY + row * rowH + 2, CALC_NEGATIVE, 8);
      row++;

      // Potential Profit
      CreateLabel("LBL_PPROFIT", "Potential Profit:", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      CreateLabel("VAL_PPROFIT", "+" + DoubleToString(m_result.potentialProfit, 2) + " " + currency, valueX, startY + row * rowH + 2, CALC_POSITIVE, 8);
      row++;

      // Risk/Reward Ratio
      CreateLabel("LBL_RR", "Risk/Reward:", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      color rrColor = (m_result.riskRewardRatio >= 2.0) ? CALC_POSITIVE :
                      (m_result.riskRewardRatio >= 1.0) ? CALC_WARNING : CALC_NEGATIVE;
      CreateLabel("VAL_RR", "1:" + DoubleToString(m_result.riskRewardRatio, 2), valueX, startY + row * rowH + 2, rrColor, 8);
      row++;

      // Margin Required
      CreateLabel("LBL_MARGIN", "Margin Required:", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      CreateLabel("VAL_MARGIN", DoubleToString(m_result.marginRequired, 2) + " " + currency, valueX, startY + row * rowH + 2, CALC_CYAN, 8);
      row++;

      // Pip Value
      CreateLabel("LBL_PIPVAL", "Pip Value:", labelX, startY + row * rowH + 2, CALC_TEXT_DIM, 8);
      CreateLabel("VAL_PIPVAL", DoubleToString(m_result.pipValuePosition, 2) + " " + currency + "/pip", valueX, startY + row * rowH + 2, CALC_TEXT, 8);
      row++;

      // Warning message
      if(m_result.warningMessage != "") {
         row++;
         CreateRect("WARN_BG", labelX - 3, startY + row * rowH - 2, w - 16, 20, CALC_BG_WARNING);
         CreateLabel("VAL_WARN", m_result.warningMessage, labelX, startY + row * rowH + 2, CALC_WARNING, 8);
      }

      ChartRedraw(0);
   }

   //+------------------------------------------------------------------+
   //| Handle click events                                               |
   //+------------------------------------------------------------------+
   bool HandleClick(string sparam) {
      // Minimize button
      if(sparam == m_prefix + "BTN_MIN") {
         m_isMinimized = !m_isMinimized;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Draw();
         return true;
      }

      // Buy button
      if(sparam == m_prefix + "BTN_BUY") {
         m_isBuy = true;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Calculate();
         Draw();
         return true;
      }

      // Sell button
      if(sparam == m_prefix + "BTN_SELL") {
         m_isBuy = false;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Calculate();
         Draw();
         return true;
      }

      // Calculate button
      if(sparam == m_prefix + "BTN_CALC") {
         // Read values from edit boxes
         string riskStr = ObjectGetString(0, m_prefix + "EDT_RISK", OBJPROP_TEXT);
         string slStr = ObjectGetString(0, m_prefix + "EDT_SL", OBJPROP_TEXT);
         string tpStr = ObjectGetString(0, m_prefix + "EDT_TP", OBJPROP_TEXT);

         m_riskPercent = StringToDouble(riskStr);
         m_stopLossPips = StringToDouble(slStr);
         m_takeProfitPips = StringToDouble(tpStr);

         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Calculate();
         Draw();
         return true;
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Handle object end edit (Enter pressed in edit box)                |
   //+------------------------------------------------------------------+
   bool HandleEndEdit(string sparam) {
      if(StringFind(sparam, m_prefix + "EDT_") >= 0) {
         // Read and recalculate
         string riskStr = ObjectGetString(0, m_prefix + "EDT_RISK", OBJPROP_TEXT);
         string slStr = ObjectGetString(0, m_prefix + "EDT_SL", OBJPROP_TEXT);
         string tpStr = ObjectGetString(0, m_prefix + "EDT_TP", OBJPROP_TEXT);

         m_riskPercent = StringToDouble(riskStr);
         m_stopLossPips = StringToDouble(slStr);
         m_takeProfitPips = StringToDouble(tpStr);

         Calculate();
         Draw();
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
      } else {
         Calculate();
         Draw();
      }
   }

   //+------------------------------------------------------------------+
   //| Get visibility status                                             |
   //+------------------------------------------------------------------+
   bool IsVisible() { return m_isVisible; }

   //+------------------------------------------------------------------+
   //| Get calculated result                                             |
   //+------------------------------------------------------------------+
   void GetResult(CalculatorResult &result) {
      result = m_result;
   }

   //+------------------------------------------------------------------+
   //| Quick calculate without UI (for external use)                     |
   //+------------------------------------------------------------------+
   double QuickCalcLots(string symbol, double riskPercent, double slPips) {
      SetSymbol(symbol);
      m_riskPercent = riskPercent;
      m_stopLossPips = slPips;
      Calculate();
      return m_result.positionSize;
   }
};

//+------------------------------------------------------------------+
