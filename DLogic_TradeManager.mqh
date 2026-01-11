//+------------------------------------------------------------------+
//|                                          DLogic_TradeManager.mqh |
//|                     D-LOGIC Professional Trade Execution Module   |
//|                                        Author: Rafał Dembski     |
//|                                                                   |
//|  Execution Logic:                                                 |
//|  - Dollar Neutrality Position Sizing                              |
//|  - Hedge Ratio Based Lot Calculation                              |
//|  - Pairs Entry/Exit Management                                    |
//+------------------------------------------------------------------+
#property copyright "Rafał Dembski"
#property strict

#include <Trade/Trade.mqh>

// ============================================================
// POSITION STRUCTURE
// ============================================================
struct SPairPosition {
   string   symbolA;
   string   symbolB;
   ulong    ticketA;
   ulong    ticketB;
   double   lotsA;
   double   lotsB;
   double   entrySpread;
   double   entryZScore;
   double   beta;
   bool     isLong;           // Long spread = Long A, Short B
   datetime openTime;
   double   unrealizedPL;
};

//+------------------------------------------------------------------+
//| CTradeManager - Pairs Trade Execution                             |
//+------------------------------------------------------------------+
class CTradeManager {
private:
   CTrade         m_trade;
   int            m_magicNumber;
   double         m_riskPercent;      // Risk per trade as % of equity
   double         m_maxPositionValue; // Max position value in account currency
   int            m_slippage;

   SPairPosition  m_positions[];
   int            m_positionCount;

   //+------------------------------------------------------------------+
   //| Calculate Lot Size for Dollar Neutrality                          |
   //|                                                                   |
   //| Dollar Neutrality means:                                          |
   //| ValueA * LotA ≈ ValueB * LotB * Beta                              |
   //|                                                                   |
   //| This ensures equal dollar exposure on both legs                   |
   //+------------------------------------------------------------------+
   void CalculateDollarNeutralLots(string symbolA, string symbolB, double beta,
                                    double riskAmount, double &lotsA, double &lotsB) {
      // Get contract specifications
      double tickValueA = SymbolInfoDouble(symbolA, SYMBOL_TRADE_TICK_VALUE);
      double tickValueB = SymbolInfoDouble(symbolB, SYMBOL_TRADE_TICK_VALUE);
      double tickSizeA = SymbolInfoDouble(symbolA, SYMBOL_TRADE_TICK_SIZE);
      double tickSizeB = SymbolInfoDouble(symbolB, SYMBOL_TRADE_TICK_SIZE);
      double lotStepA = SymbolInfoDouble(symbolA, SYMBOL_VOLUME_STEP);
      double lotStepB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_STEP);
      double minLotA = SymbolInfoDouble(symbolA, SYMBOL_VOLUME_MIN);
      double minLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_MIN);
      double maxLotA = SymbolInfoDouble(symbolA, SYMBOL_VOLUME_MAX);
      double maxLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_MAX);

      // Price values
      double priceA = SymbolInfoDouble(symbolA, SYMBOL_BID);
      double priceB = SymbolInfoDouble(symbolB, SYMBOL_BID);

      // Contract sizes
      double contractA = SymbolInfoDouble(symbolA, SYMBOL_TRADE_CONTRACT_SIZE);
      double contractB = SymbolInfoDouble(symbolB, SYMBOL_TRADE_CONTRACT_SIZE);

      // Dollar value per lot
      double valuePerLotA = priceA * contractA;
      double valuePerLotB = priceB * contractB;

      // Safety check for zero values
      if(valuePerLotA <= 0 || valuePerLotB <= 0 || MathAbs(beta) < 1e-10) {
         lotsA = minLotA;
         lotsB = minLotB;
         Print("[TRADE] Warning: Invalid values for lot calculation, using minimums");
         return;
      }

      // Calculate base lots from risk amount
      // Start with symbol A
      double baseLotA = riskAmount / valuePerLotA;

      // Calculate B lots using hedge ratio (beta)
      // For dollar neutrality: valueA = beta * valueB
      // lotsB = (lotsA * valuePerLotA) / (beta * valuePerLotB)
      double baseLotB = (baseLotA * valuePerLotA) / (MathAbs(beta) * valuePerLotB);

      // Normalize to lot steps
      lotsA = MathFloor(baseLotA / lotStepA) * lotStepA;
      lotsB = MathFloor(baseLotB / lotStepB) * lotStepB;

      // Ensure minimum lots
      if(lotsA < minLotA) lotsA = minLotA;
      if(lotsB < minLotB) lotsB = minLotB;

      // Cap at maximum lots
      if(lotsA > maxLotA) lotsA = maxLotA;
      if(lotsB > maxLotB) lotsB = maxLotB;

      Print("[TRADE] Dollar Neutral Lots: ", symbolA, "=", lotsA, " ", symbolB, "=", lotsB,
            " (Beta=", beta, ", Risk=", riskAmount, ")");
   }

   //+------------------------------------------------------------------+
   //| Check if pair position already exists                             |
   //+------------------------------------------------------------------+
   int FindPairPosition(string symbolA, string symbolB) {
      for(int i = 0; i < m_positionCount; i++) {
         if((m_positions[i].symbolA == symbolA && m_positions[i].symbolB == symbolB) ||
            (m_positions[i].symbolA == symbolB && m_positions[i].symbolB == symbolA)) {
            return i;
         }
      }
      return -1;
   }

   //+------------------------------------------------------------------+
   //| Calculate unrealized P&L for a pair position                      |
   //+------------------------------------------------------------------+
   double CalculatePairPL(int index) {
      if(index < 0 || index >= m_positionCount) return 0;

      SPairPosition pos = m_positions[index];
      double plA = 0, plB = 0;

      // Check if positions still exist and get their P&L
      if(PositionSelectByTicket(pos.ticketA)) {
         plA = PositionGetDouble(POSITION_PROFIT);
      }
      if(PositionSelectByTicket(pos.ticketB)) {
         plB = PositionGetDouble(POSITION_PROFIT);
      }

      return plA + plB;
   }

   //+------------------------------------------------------------------+
   //| Remove position from tracking array                               |
   //+------------------------------------------------------------------+
   void RemovePosition(int index) {
      if(index < 0 || index >= m_positionCount) return;

      // Shift array
      for(int i = index; i < m_positionCount - 1; i++) {
         m_positions[i] = m_positions[i + 1];
      }
      m_positionCount--;
      ArrayResize(m_positions, m_positionCount);
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CTradeManager() {
      m_magicNumber = 20240107;
      m_riskPercent = 1.0;
      m_maxPositionValue = 10000;
      m_slippage = 30;
      m_positionCount = 0;

      m_trade.SetExpertMagicNumber(m_magicNumber);
      m_trade.SetDeviationInPoints(m_slippage);
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   }

   //+------------------------------------------------------------------+
   //| Configure Trade Parameters                                        |
   //+------------------------------------------------------------------+
   void Configure(double riskPercent, double maxValue, int magic = 20240107) {
      m_riskPercent = riskPercent;
      m_maxPositionValue = maxValue;
      m_magicNumber = magic;
      m_trade.SetExpertMagicNumber(magic);

      Print("[TRADE] Configured: Risk=", riskPercent, "%, MaxValue=", maxValue);
   }

   //+------------------------------------------------------------------+
   //| Open Pairs Position                                               |
   //|                                                                   |
   //| isLongSpread = true:  BUY A, SELL B (spread too low, Z < -2)      |
   //| isLongSpread = false: SELL A, BUY B (spread too high, Z > +2)     |
   //+------------------------------------------------------------------+
   bool OpenPairsPosition(string symbolA, string symbolB, double beta,
                          double zScore, bool isLongSpread) {
      // Check if position already exists
      if(FindPairPosition(symbolA, symbolB) >= 0) {
         Print("[TRADE] Position already exists for ", symbolA, "/", symbolB);
         return false;
      }

      // Check margin requirements
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

      double riskAmount = equity * m_riskPercent / 100.0;
      if(riskAmount > m_maxPositionValue) riskAmount = m_maxPositionValue;

      // Calculate dollar-neutral lot sizes
      double lotsA, lotsB;
      CalculateDollarNeutralLots(symbolA, symbolB, beta, riskAmount, lotsA, lotsB);

      // Check margin
      double marginA = 0, marginB = 0;
      ENUM_ORDER_TYPE typeA = isLongSpread ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      ENUM_ORDER_TYPE typeB = isLongSpread ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      double priceA = isLongSpread ? SymbolInfoDouble(symbolA, SYMBOL_ASK) : SymbolInfoDouble(symbolA, SYMBOL_BID);
      double priceB = isLongSpread ? SymbolInfoDouble(symbolB, SYMBOL_BID) : SymbolInfoDouble(symbolB, SYMBOL_ASK);

      if(!OrderCalcMargin(typeA, symbolA, lotsA, priceA, marginA) ||
         !OrderCalcMargin(typeB, symbolB, lotsB, priceB, marginB)) {
         Print("[TRADE] Cannot calculate margin requirements");
         return false;
      }

      if(marginA + marginB > freeMargin * 0.9) {
         Print("[TRADE] Insufficient margin: Required=", marginA + marginB, " Free=", freeMargin);
         return false;
      }

      // Execute trades
      string comment = "PAIRS_" + (isLongSpread ? "LONG" : "SHORT") + "_Z" + DoubleToString(zScore, 2);

      // Open leg A
      bool successA = false;
      if(isLongSpread) {
         successA = m_trade.Buy(lotsA, symbolA, 0, 0, 0, comment);
      } else {
         successA = m_trade.Sell(lotsA, symbolA, 0, 0, 0, comment);
      }

      if(!successA) {
         Print("[TRADE] Failed to open leg A: ", m_trade.ResultRetcode(), " ", m_trade.ResultRetcodeDescription());
         return false;
      }
      ulong ticketA = m_trade.ResultOrder();

      // Open leg B
      bool successB = false;
      if(isLongSpread) {
         successB = m_trade.Sell(lotsB, symbolB, 0, 0, 0, comment);
      } else {
         successB = m_trade.Buy(lotsB, symbolB, 0, 0, 0, comment);
      }

      if(!successB) {
         Print("[TRADE] Failed to open leg B, closing leg A");
         // Close leg A on failure
         if(PositionSelectByTicket(ticketA)) {
            m_trade.PositionClose(ticketA);
         }
         return false;
      }
      ulong ticketB = m_trade.ResultOrder();

      // Record position
      m_positionCount++;
      ArrayResize(m_positions, m_positionCount);

      SPairPosition pos;
      pos.symbolA = symbolA;
      pos.symbolB = symbolB;
      pos.ticketA = ticketA;
      pos.ticketB = ticketB;
      pos.lotsA = lotsA;
      pos.lotsB = lotsB;
      pos.beta = beta;
      pos.entryZScore = zScore;
      pos.isLong = isLongSpread;
      pos.openTime = TimeCurrent();
      pos.unrealizedPL = 0;

      // Calculate entry spread
      pos.entrySpread = MathLog(priceA) - beta * MathLog(priceB);

      m_positions[m_positionCount - 1] = pos;

      Print("[TRADE] Opened pair position: ", symbolA, (isLongSpread ? " LONG " : " SHORT "),
            lotsA, " + ", symbolB, (isLongSpread ? " SHORT " : " LONG "), lotsB,
            " Z-Score=", zScore);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Close Pairs Position                                              |
   //+------------------------------------------------------------------+
   bool ClosePairsPosition(string symbolA, string symbolB, string reason = "") {
      int index = FindPairPosition(symbolA, symbolB);
      if(index < 0) {
         Print("[TRADE] No position found for ", symbolA, "/", symbolB);
         return false;
      }

      SPairPosition pos = m_positions[index];
      bool successA = false, successB = false;

      // Close leg A
      if(PositionSelectByTicket(pos.ticketA)) {
         successA = m_trade.PositionClose(pos.ticketA);
      } else {
         successA = true;  // Already closed
      }

      // Close leg B
      if(PositionSelectByTicket(pos.ticketB)) {
         successB = m_trade.PositionClose(pos.ticketB);
      } else {
         successB = true;  // Already closed
      }

      if(successA && successB) {
         double finalPL = CalculatePairPL(index);
         Print("[TRADE] Closed pair: ", symbolA, "/", symbolB, " P&L=", finalPL, " Reason: ", reason);
         RemovePosition(index);
         return true;
      }

      Print("[TRADE] Failed to close pair position: A=", successA, " B=", successB);
      return false;
   }

   //+------------------------------------------------------------------+
   //| Close All Positions                                               |
   //+------------------------------------------------------------------+
   void CloseAllPositions(string reason = "Close All") {
      for(int i = m_positionCount - 1; i >= 0; i--) {
         ClosePairsPosition(m_positions[i].symbolA, m_positions[i].symbolB, reason);
      }
   }

   //+------------------------------------------------------------------+
   //| Check and Manage Existing Positions                               |
   //+------------------------------------------------------------------+
   void ManagePositions(double zScoreExit, double zScoreStop) {
      for(int i = m_positionCount - 1; i >= 0; i--) {
         SPairPosition pos = m_positions[i];

         // Calculate current Z-Score (simplified - would need engine reference)
         double currentPriceA = SymbolInfoDouble(pos.symbolA, SYMBOL_BID);
         double currentPriceB = SymbolInfoDouble(pos.symbolB, SYMBOL_BID);

         if(currentPriceA <= 0 || currentPriceB <= 0) continue;

         // Estimate current spread (rough, for position management)
         double currentSpread = MathLog(currentPriceA) - pos.beta * MathLog(currentPriceB);
         double spreadChange = currentSpread - pos.entrySpread;

         // Update unrealized P&L
         m_positions[i].unrealizedPL = CalculatePairPL(i);

         // Check for orphaned positions (one leg closed)
         bool legAExists = PositionSelectByTicket(pos.ticketA);
         bool legBExists = PositionSelectByTicket(pos.ticketB);

         if(!legAExists || !legBExists) {
            Print("[TRADE] Orphaned position detected, closing remaining leg");
            if(legAExists) m_trade.PositionClose(pos.ticketA);
            if(legBExists) m_trade.PositionClose(pos.ticketB);
            RemovePosition(i);
            continue;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Get Position Count                                                |
   //+------------------------------------------------------------------+
   int GetPositionCount() { return m_positionCount; }

   //+------------------------------------------------------------------+
   //| Get Total Unrealized P&L                                          |
   //+------------------------------------------------------------------+
   double GetTotalUnrealizedPL() {
      double total = 0;
      for(int i = 0; i < m_positionCount; i++) {
         total += CalculatePairPL(i);
      }
      return total;
   }

   //+------------------------------------------------------------------+
   //| Get Position Info                                                 |
   //+------------------------------------------------------------------+
   bool GetPosition(int index, SPairPosition &pos) {
      if(index < 0 || index >= m_positionCount) return false;
      pos = m_positions[index];
      pos.unrealizedPL = CalculatePairPL(index);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Check if pair has position                                        |
   //+------------------------------------------------------------------+
   bool HasPosition(string symbolA, string symbolB) {
      return FindPairPosition(symbolA, symbolB) >= 0;
   }
};

//+------------------------------------------------------------------+
