//+------------------------------------------------------------------+
//|                                     Enhanced_TradeAlgorithms.mqh |
//|                   Enhanced Trading Algorithms for ST&VWAP System |
//+------------------------------------------------------------------+
#property copyright "Enhanced Trading Algorithms © 2025"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Enhanced Enumerations                                            |
//+------------------------------------------------------------------+
enum MarginMode
{
   FREEMARGIN=0,     // MM from free margin on account
   BALANCE,          // MM from balance on account  
   LOSSFREEMARGIN,   // MM by losses from free margin on account
   LOSSBALANCE,      // MM by losses from balance on account
   LOT               // Fixed lot without changes
};

enum EA_STATE 
{ 
   ST_READY = 0, 
   ST_IN_TRADE, 
   ST_FROZEN, 
   ST_COOLDOWN, 
   ST_ARMING,
   ST_SIGNAL_WAIT,   // New state for signal waiting
   ST_EXECUTING      // New state for trade execution
};

enum DIR 
{ 
   DIR_NONE = 0, 
   DIR_BUY = 1, 
   DIR_SELL = -1 
};

enum FREEZE_REASON 
{ 
   FREEZE_TRADE_CLOSE = 0, 
   FREEZE_DATA_MISSING, 
   FREEZE_MANUAL,
   FREEZE_DAILY_LIMIT,
   FREEZE_CONNECTION_LOST
};

enum TRADE_DECISION
{
   TRADE_NONE = 0,
   TRADE_BUY = 1,
   TRADE_SELL = -1,
   TRADE_CLOSE_BUY = 2,
   TRADE_CLOSE_SELL = -2
};

//+------------------------------------------------------------------+
//| Enhanced Structures                                              |
//+------------------------------------------------------------------+
struct SessionTime
{
   bool   enabled;
   int    startHour;
   int    startMinute;
   int    endHour;
   int    endMinute;
   string description;
   
   SessionTime() : enabled(false), startHour(0), startMinute(0), endHour(0), endMinute(0), description("") {}
};

struct PositionTracker
{
   ulong    ticket;
   int      slModifications;
   int      tpModifications;
   ulong    lastTickTime;
   bool     breakEvenExecuted;
   datetime entryTime;
   double   entryPrice;
   double   originalSL;
   double   originalTP;
   double   highestProfit;
   double   maxDrawdown;
   int      trailingSteps;
   bool     isActive;
   ENUM_POSITION_TYPE positionType;
   
   PositionTracker() : ticket(0), slModifications(0), tpModifications(0), 
                      lastTickTime(0), breakEvenExecuted(false), entryTime(0),
                      entryPrice(0), originalSL(0), originalTP(0), highestProfit(0),
                      maxDrawdown(0), trailingSteps(0), isActive(false), positionType(POSITION_TYPE_BUY) {}
};

struct TradeStats
{
   int      totalTrades;
   int      winTrades;
   int      loseTrades;
   double   totalProfit;
   double   totalLoss;
   double   maxDrawdown;
   double   maxProfit;
   datetime lastTradeTime;
   double   averageWin;
   double   averageLoss;
   double   profitFactor;
   double   winRate;
   int      consecutiveWins;
   int      consecutiveLosses;
   int      maxConsecutiveWins;
   int      maxConsecutiveLosses;
   
   TradeStats() : totalTrades(0), winTrades(0), loseTrades(0), 
                 totalProfit(0), totalLoss(0), maxDrawdown(0), maxProfit(0), 
                 lastTradeTime(0), averageWin(0), averageLoss(0), profitFactor(0),
                 winRate(0), consecutiveWins(0), consecutiveLosses(0), 
                 maxConsecutiveWins(0), maxConsecutiveLosses(0) {}
};

struct MarketCondition
{
   double   spread;
   double   volatility;
   double   volume;
   bool     isHighVolatility;
   bool     isGoodSpread;
   bool     isTradingTime;
   datetime lastUpdate;
   
   MarketCondition() : spread(0), volatility(0), volume(0), isHighVolatility(false),
                      isGoodSpread(true), isTradingTime(true), lastUpdate(0) {}
};

//+------------------------------------------------------------------+
//| Global Variables with Memory Optimization                       |
//+------------------------------------------------------------------+
CTrade         trade;
CSymbolInfo    symbolInfo;
CPositionInfo  positionInfo;
COrderInfo     orderInfo;

// Optimized arrays with memory management
PositionTracker g_positionTrackers[];
TradeStats g_tradeStats;
MarketCondition g_marketCondition;

// Enhanced state management
EA_STATE g_eaState = ST_READY;
datetime g_lastStateChange = 0;
datetime g_freezeUntil = 0;
datetime g_cooldownUntil = 0;
int      g_freezeMinutes = 15;
int      g_cooldownMinutes = 5;

// Signal tracking for single trade logic
bool     g_lastSignalProcessed = true;
datetime g_lastSignalTime = 0;
TRADE_DECISION g_pendingTrade = TRADE_NONE;

// Performance optimization variables
static int g_lastCalculatedBar = -1;
static int g_arrayCleanupCounter = 0;
const int ARRAY_CLEANUP_FREQUENCY = 100;

//+------------------------------------------------------------------+
//| Enhanced Global Variable Helper Functions                       |
//+------------------------------------------------------------------+
string GV(const string tag, const ulong mag) 
{ 
   return _Symbol + "_" + tag + "_" + (string)mag; 
}

void GlobalVariableDel_(const string symbol)
{
   string prefix = symbol + "_";
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string name = GlobalVariableName(i);
      if(StringFind(name, prefix) == 0)
         GlobalVariableDel(name);
   }
}

void ConfigureStateDurations(int freezeMin, int cooldownMin)
{
   g_freezeMinutes   = MathMax(1, freezeMin);
   g_cooldownMinutes = MathMax(0, cooldownMin);
}

//+------------------------------------------------------------------+
//| Enhanced State Management Functions                              |
//+------------------------------------------------------------------+
void SetEAState(EA_STATE newState, FREEZE_REASON reason = FREEZE_TRADE_CLOSE)
{
   if(g_eaState != newState)
   {
      EA_STATE oldState = g_eaState;
      g_eaState = newState;
      g_lastStateChange = TimeCurrent();
      
      Print("EA State: ", EnumToString(oldState), " -> ", EnumToString(newState));
      
      // Set timing based on new state
      switch(newState)
      {
         case ST_FROZEN:
            g_freezeUntil = TimeCurrent() + g_freezeMinutes * 60;
            Print("EA Frozen (", EnumToString(reason), ") until: ", TimeToString(g_freezeUntil));
            break;
            
         case ST_COOLDOWN:
            g_cooldownUntil = TimeCurrent() + g_cooldownMinutes * 60;
            Print("EA Cooldown until: ", TimeToString(g_cooldownUntil));
            break;
            
         case ST_IN_TRADE:
            // Clear pending signals when entering trade
            g_pendingTrade = TRADE_NONE;
            g_lastSignalProcessed = true;
            break;
            
         case ST_READY:
            // Reset signal processing
            g_lastSignalProcessed = true;
            g_pendingTrade = TRADE_NONE;
            break;
      }
   }
}

EA_STATE GetEAState()
{
   datetime current = TimeCurrent();
   
   // Check if freeze/cooldown period has expired
   if(g_eaState == ST_FROZEN && current >= g_freezeUntil)
   {
      SetEAState(ST_READY);
   }
   else if(g_eaState == ST_COOLDOWN && current >= g_cooldownUntil)
   {
      // Check if we still have positions before going to ready
      if(CountActivePositions() == 0)
         SetEAState(ST_READY);
   }
   
   return g_eaState;
}

bool IsEAReadyToTrade()
{
   EA_STATE currentState = GetEAState();
   return (currentState == ST_READY || currentState == ST_SIGNAL_WAIT);
}

bool CanOpenNewPosition()
{
   // Critical rule: Only one position at a time
   if(CountActivePositions() > 0)
      return false;
      
   // Check EA state
   if(!IsEAReadyToTrade())
      return false;
      
   // Check if signal is already being processed
   if(!g_lastSignalProcessed)
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Enhanced Position Tracking Functions with Memory Optimization   |
//+------------------------------------------------------------------+
int CountActivePositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() == _Symbol)
            count++;
      }
   }
   return count;
}

int FindPositionTrackerIndex(ulong ticket)
{
   for(int i = 0; i < ArraySize(g_positionTrackers); i++)
   {
      if(g_positionTrackers[i].isActive && g_positionTrackers[i].ticket == ticket)
         return i;
   }
   return -1;
}

void AddPositionTracker(ulong ticket, double entryPrice, double sl, double tp, ENUM_POSITION_TYPE posType)
{
   // Find empty slot first (memory optimization)
   int index = -1;
   for(int i = 0; i < ArraySize(g_positionTrackers); i++)
   {
      if(!g_positionTrackers[i].isActive)
      {
         index = i;
         break;
      }
   }
   
   // If no empty slot, expand array
   if(index == -1)
   {
      index = ArraySize(g_positionTrackers);
      ArrayResize(g_positionTrackers, index + 1);
   }
   
   // Initialize tracker
   g_positionTrackers[index].ticket = ticket;
   g_positionTrackers[index].entryTime = TimeCurrent();
   g_positionTrackers[index].entryPrice = entryPrice;
   g_positionTrackers[index].originalSL = sl;
   g_positionTrackers[index].originalTP = tp;
   g_positionTrackers[index].slModifications = 0;
   g_positionTrackers[index].tpModifications = 0;
   g_positionTrackers[index].breakEvenExecuted = false;
   g_positionTrackers[index].lastTickTime = GetTickCount();
   g_positionTrackers[index].highestProfit = 0;
   g_positionTrackers[index].maxDrawdown = 0;
   g_positionTrackers[index].trailingSteps = 0;
   g_positionTrackers[index].isActive = true;
   g_positionTrackers[index].positionType = posType;
   
   Print("Position tracker added: Ticket=", ticket, ", Entry=", entryPrice);
}

void RemovePositionTracker(ulong ticket)
{
   int index = FindPositionTrackerIndex(ticket);
   if(index >= 0)
   {
      g_positionTrackers[index].isActive = false;
      // Don't resize array immediately - reuse slots for memory efficiency
      Print("Position tracker removed: Ticket=", ticket);
      
      // Periodic cleanup
      g_arrayCleanupCounter++;
      if(g_arrayCleanupCounter >= ARRAY_CLEANUP_FREQUENCY)
      {
         CleanupPositionTrackers();
         g_arrayCleanupCounter = 0;
      }
   }
}

void CleanupPositionTrackers()
{
   int activeCount = 0;
   PositionTracker tempArray[];
   
   // Count active trackers
   for(int i = 0; i < ArraySize(g_positionTrackers); i++)
   {
      if(g_positionTrackers[i].isActive)
         activeCount++;
   }
   
   if(activeCount == 0)
   {
      ArrayFree(g_positionTrackers);
      return;
   }
   
   // Copy active trackers to temp array
   ArrayResize(tempArray, activeCount);
   int newIndex = 0;
   for(int i = 0; i < ArraySize(g_positionTrackers); i++)
   {
      if(g_positionTrackers[i].isActive)
      {
         tempArray[newIndex] = g_positionTrackers[i];
         newIndex++;
      }
   }
   
   // Replace main array
   ArrayFree(g_positionTrackers);
   ArrayResize(g_positionTrackers, activeCount);
   for(int i = 0; i < activeCount; i++)
   {
      g_positionTrackers[i] = tempArray[i];
   }
   
   ArrayFree(tempArray);
   Print("Position trackers cleaned up. Active positions: ", activeCount);
}

//+------------------------------------------------------------------+
//| Enhanced Lot Size Calculation Functions                         |
//+------------------------------------------------------------------+
double GetLot(double MM, MarginMode MMMode, string symbol)
{
   if(!symbolInfo.Name(symbol))
      return 0.1;
      
   double lot = 0.1;
   double margin = 0;
   
   switch(MMMode)
   {
      case FREEMARGIN:
         margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         lot = NormalizeDouble(margin * MM / 100000, 2);
         break;
         
      case BALANCE:
         margin = AccountInfoDouble(ACCOUNT_BALANCE);
         lot = NormalizeDouble(margin * MM / 100000, 2);
         break;
         
      case LOSSFREEMARGIN:
         margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         lot = NormalizeDouble(margin * MM / 50000, 2);
         break;
         
      case LOSSBALANCE:
         margin = AccountInfoDouble(ACCOUNT_BALANCE);
         lot = NormalizeDouble(margin * MM / 50000, 2);
         break;
         
      case LOT:
      default:
         lot = MM;
         break;
   }
   
   // Normalize lot size according to symbol specifications
   double minLot = symbolInfo.LotsMin();
   double maxLot = symbolInfo.LotsMax();
   double lotStep = symbolInfo.LotsStep();
   
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   lot = NormalizeDouble(lot / lotStep, 0) * lotStep;
   
   return lot;
}

double CalculateOptimalLot(double riskPercent, double stopLossPoints, string symbol)
{
   if(stopLossPoints <= 0 || riskPercent <= 0)
      return GetLot(1.0, LOT, symbol);
      
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * riskPercent / 100.0;
   
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue = tickValue * (_Point / tickSize);
   
   if(pointValue > 0)
   {
      double optimalLot = riskAmount / (stopLossPoints * pointValue);
      return GetLot(optimalLot, LOT, symbol);
   }
   
   return GetLot(1.0, LOT, symbol);
}

//+------------------------------------------------------------------+
//| Enhanced Order Management Functions with Single Trade Logic     |
//+------------------------------------------------------------------+
bool BuyPositionOpen(bool signal, string symbol, datetime signalTime, 
                    double MM, MarginMode MMMode, int deviation, 
                    int stopLoss, int takeProfit, ulong magicNumber = 0)
{
   // Critical validation for single trade logic
   if(!signal || !CanOpenNewPosition())
   {
      if(signal && !CanOpenNewPosition())
         Print("BUY signal ignored - position already exists or EA not ready");
      return false;
   }
   
   // Set executing state to prevent concurrent trades
   SetEAState(ST_EXECUTING);
   g_lastSignalProcessed = false;
   
   if(!symbolInfo.Name(symbol))
   {
      Print("Error: Invalid symbol ", symbol);
      SetEAState(ST_READY);
      g_lastSignalProcessed = true;
      return false;
   }
   
   double lot = GetLot(MM, MMMode, symbol);
   if(lot <= 0)
   {
      Print("Error: Invalid lot size calculated: ", lot);
      SetEAState(ST_READY);
      g_lastSignalProcessed = true;
      return false;
   }
   
   symbolInfo.RefreshRates();
   double price = symbolInfo.Ask();
   if(price <= 0)
   {
      Print("Error: Unable to retrieve valid ask price for ", symbol);
      SetEAState(ST_READY);
      g_lastSignalProcessed = true;
      return false;
   }

   double sl = (stopLoss > 0) ? price - stopLoss * symbolInfo.Point() : 0;
   double tp = (takeProfit > 0) ? price + takeProfit * symbolInfo.Point() : 0;
   
   trade.SetExpertMagicNumber(magicNumber);
   trade.SetDeviationInPoints(deviation);
   
   // Enhanced trade execution with retry logic
   bool success = false;
   int retries = 3;
   
   for(int i = 0; i < retries && !success; i++)
   {
      if(trade.Buy(lot, symbol, price, sl, tp, "ST_VWAP Buy"))
      {
         success = true;
         ulong ticket = trade.ResultOrder();
         if(ticket == 0)
            ticket = trade.ResultDeal();
         if(ticket == 0 && PositionSelect(symbol))
            ticket = (ulong)PositionGetInteger(POSITION_TICKET);
         
         // Add position tracker
         AddPositionTracker(ticket, price, sl, tp, POSITION_TYPE_BUY);
         
         // Update statistics
         g_tradeStats.totalTrades++;
         g_tradeStats.lastTradeTime = TimeCurrent();
         
         // Set proper state
         SetEAState(ST_IN_TRADE);
         g_lastSignalProcessed = true;
         g_lastSignalTime = signalTime;
         
         Print("BUY position opened successfully: Ticket=", ticket, ", Lot=", lot, ", Price=", price, ", SL=", sl, ", TP=", tp);
         return true;
      }
      else
      {
         Print("BUY attempt ", i+1, " failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         if(i < retries - 1)
         {
            Sleep(100); // Brief pause before retry
            symbolInfo.RefreshRates();
            price = symbolInfo.Ask();
         }
      }
   }
   
   // Failed to open position
   SetEAState(ST_READY);
   g_lastSignalProcessed = true;
   Print("Failed to open BUY position after ", retries, " attempts");
   return false;
}

bool SellPositionOpen(bool signal, string symbol, datetime signalTime,
                     double MM, MarginMode MMMode, int deviation,
                     int stopLoss, int takeProfit, ulong magicNumber = 0)
{
   // Critical validation for single trade logic
   if(!signal || !CanOpenNewPosition())
   {
      if(signal && !CanOpenNewPosition())
         Print("SELL signal ignored - position already exists or EA not ready");
      return false;
   }
   
   // Set executing state to prevent concurrent trades
   SetEAState(ST_EXECUTING);
   g_lastSignalProcessed = false;
   
   if(!symbolInfo.Name(symbol))
   {
      Print("Error: Invalid symbol ", symbol);
      SetEAState(ST_READY);
      g_lastSignalProcessed = true;
      return false;
   }
   
   double lot = GetLot(MM, MMMode, symbol);
   if(lot <= 0)
   {
      Print("Error: Invalid lot size calculated: ", lot);
      SetEAState(ST_READY);
      g_lastSignalProcessed = true;
      return false;
   }
   
   symbolInfo.RefreshRates();
   double price = symbolInfo.Bid();
   if(price <= 0)
   {
      Print("Error: Unable to retrieve valid bid price for ", symbol);
      SetEAState(ST_READY);
      g_lastSignalProcessed = true;
      return false;
   }

   double sl = (stopLoss > 0) ? price + stopLoss * symbolInfo.Point() : 0;
   double tp = (takeProfit > 0) ? price - takeProfit * symbolInfo.Point() : 0;
   
   trade.SetExpertMagicNumber(magicNumber);
   trade.SetDeviationInPoints(deviation);
   
   // Enhanced trade execution with retry logic
   bool success = false;
   int retries = 3;
   
   for(int i = 0; i < retries && !success; i++)
   {
      if(trade.Sell(lot, symbol, price, sl, tp, "ST_VWAP Sell"))
      {
         success = true;
         ulong ticket = trade.ResultOrder();
         if(ticket == 0)
            ticket = trade.ResultDeal();
         if(ticket == 0 && PositionSelect(symbol))
            ticket = (ulong)PositionGetInteger(POSITION_TICKET);
         
         // Add position tracker
         AddPositionTracker(ticket, price, sl, tp, POSITION_TYPE_SELL);
         
         // Update statistics
         g_tradeStats.totalTrades++;
         g_tradeStats.lastTradeTime = TimeCurrent();
         
         // Set proper state
         SetEAState(ST_IN_TRADE);
         g_lastSignalProcessed = true;
         g_lastSignalTime = signalTime;
         
         Print("SELL position opened successfully: Ticket=", ticket, ", Lot=", lot, ", Price=", price, ", SL=", sl, ", TP=", tp);
         return true;
      }
      else
      {
         Print("SELL attempt ", i+1, " failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         if(i < retries - 1)
         {
            Sleep(100); // Brief pause before retry
            symbolInfo.RefreshRates();
            price = symbolInfo.Bid();
         }
      }
   }
   
   // Failed to open position
   SetEAState(ST_READY);
   g_lastSignalProcessed = true;
   Print("Failed to open SELL position after ", retries, " attempts");
   return false;
}

bool BuyPositionClose(bool signal, string symbol, int deviation, ulong magicNumber = 0)
{
   if(!signal) return false;
   
   trade.SetExpertMagicNumber(magicNumber);
   trade.SetDeviationInPoints(deviation);
   
   bool closed = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() == symbol && 
            positionInfo.PositionType() == POSITION_TYPE_BUY &&
            (magicNumber == 0 || positionInfo.Magic() == magicNumber))
         {
            ulong ticket = positionInfo.Ticket();
            double profit = positionInfo.Profit();
            
            if(trade.PositionClose(ticket))
            {
               RemovePositionTracker(ticket);
               UpdateTradeStats(profit);
               SetEAState(ST_COOLDOWN);
               
               Print("BUY position closed: Ticket=", ticket, ", Profit=", DoubleToString(profit, 2));
               closed = true;
            }
         }
      }
   }
   return closed;
}

bool SellPositionClose(bool signal, string symbol, int deviation, ulong magicNumber = 0)
{
   if(!signal) return false;
   
   trade.SetExpertMagicNumber(magicNumber);
   trade.SetDeviationInPoints(deviation);
   
   bool closed = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() == symbol && 
            positionInfo.PositionType() == POSITION_TYPE_SELL &&
            (magicNumber == 0 || positionInfo.Magic() == magicNumber))
         {
            ulong ticket = positionInfo.Ticket();
            double profit = positionInfo.Profit();
            
            if(trade.PositionClose(ticket))
            {
               RemovePositionTracker(ticket);
               UpdateTradeStats(profit);
               SetEAState(ST_COOLDOWN);
               
               Print("SELL position closed: Ticket=", ticket, ", Profit=", DoubleToString(profit, 2));
               closed = true;
            }
         }
      }
   }
   return closed;
}

//+------------------------------------------------------------------+
//| Enhanced Trade Statistics Functions                              |
//+------------------------------------------------------------------+
void UpdateTradeStats(double profit)
{
   if(profit > 0)
   {
      g_tradeStats.winTrades++;
      g_tradeStats.totalProfit += profit;
      g_tradeStats.consecutiveWins++;
      g_tradeStats.consecutiveLosses = 0;
      
      if(g_tradeStats.consecutiveWins > g_tradeStats.maxConsecutiveWins)
         g_tradeStats.maxConsecutiveWins = g_tradeStats.consecutiveWins;
         
      if(profit > g_tradeStats.maxProfit)
         g_tradeStats.maxProfit = profit;
   }
   else if(profit < 0)
   {
      g_tradeStats.loseTrades++;
      g_tradeStats.totalLoss += MathAbs(profit);
      g_tradeStats.consecutiveLosses++;
      g_tradeStats.consecutiveWins = 0;
      
      if(g_tradeStats.consecutiveLosses > g_tradeStats.maxConsecutiveLosses)
         g_tradeStats.maxConsecutiveLosses = g_tradeStats.consecutiveLosses;
         
      if(MathAbs(profit) > g_tradeStats.maxDrawdown)
         g_tradeStats.maxDrawdown = MathAbs(profit);
   }
   
   // Calculate derived statistics
   if(g_tradeStats.totalTrades > 0)
   {
      g_tradeStats.winRate = (double)g_tradeStats.winTrades / g_tradeStats.totalTrades * 100.0;
   }
   
   if(g_tradeStats.winTrades > 0)
      g_tradeStats.averageWin = g_tradeStats.totalProfit / g_tradeStats.winTrades;
      
   if(g_tradeStats.loseTrades > 0)
      g_tradeStats.averageLoss = g_tradeStats.totalLoss / g_tradeStats.loseTrades;
      
   if(g_tradeStats.totalLoss > 0)
      g_tradeStats.profitFactor = g_tradeStats.totalProfit / g_tradeStats.totalLoss;
   else if(g_tradeStats.totalProfit > 0)
      g_tradeStats.profitFactor = 9999; // High value when no losses
}

bool ModifyPosition(ulong ticket, double newSL, double newTP, int maxSLMods = -1, int maxTPMods = -1)
{
   if(!positionInfo.SelectByTicket(ticket))
      return false;
      
   int trackerIndex = FindPositionTrackerIndex(ticket);
   if(trackerIndex < 0)
      return false;
      
   // Check modification limits
   if(maxSLMods > 0 && g_positionTrackers[trackerIndex].slModifications >= maxSLMods)
   {
      Print("SL modification limit reached for ticket ", ticket);
      return false;
   }
   
   if(maxTPMods > 0 && g_positionTrackers[trackerIndex].tpModifications >= maxTPMods)
   {
      Print("TP modification limit reached for ticket ", ticket);
      return false;
   }
   
   // Check minimum interval between modifications
   ulong currentTick = GetTickCount();
   if(currentTick - g_positionTrackers[trackerIndex].lastTickTime < 1000)
      return false;
   
   if(trade.PositionModify(ticket, newSL, newTP))
   {
      // Update modification counters
      double currentSL = positionInfo.StopLoss();
      double currentTP = positionInfo.TakeProfit();
      
      if(MathAbs(newSL - currentSL) > symbolInfo.Point())
         g_positionTrackers[trackerIndex].slModifications++;
         
      if(MathAbs(newTP - currentTP) > symbolInfo.Point())
         g_positionTrackers[trackerIndex].tpModifications++;
         
      g_positionTrackers[trackerIndex].lastTickTime = currentTick;
      
      Print("Position modified: Ticket=", ticket, ", New SL=", newSL, ", New TP=", newTP);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Enhanced Break-Even and Trailing Functions                      |
//+------------------------------------------------------------------+
void ProcessBreakEven(double breakEvenPercent, double beSLPercent)
{
   for(int i = 0; i < ArraySize(g_positionTrackers); i++)
   {
      if(!g_positionTrackers[i].isActive || g_positionTrackers[i].breakEvenExecuted)
         continue;
         
      ulong ticket = g_positionTrackers[i].ticket;
      if(!positionInfo.SelectByTicket(ticket))
         continue;
         
      double entryPrice = g_positionTrackers[i].entryPrice;
      double originalTP = g_positionTrackers[i].originalTP;
      double currentPrice = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 
                           symbolInfo.Bid() : symbolInfo.Ask();
      
      // Calculate profit percentage based on TP distance
      double tpDistance = MathAbs(originalTP - entryPrice);
      double currentProfit = 0;
      
      if(positionInfo.PositionType() == POSITION_TYPE_BUY)
         currentProfit = currentPrice - entryPrice;
      else
         currentProfit = entryPrice - currentPrice;
         
      double profitPercent = (tpDistance > 0) ? (currentProfit / tpDistance) * 100 : 0;
      
      if(profitPercent >= breakEvenPercent)
      {
         double offset = tpDistance * beSLPercent / 100.0;
         double newSL = entryPrice + (positionInfo.PositionType() == POSITION_TYPE_BUY ? offset : -offset);

         if(ModifyPosition(ticket, newSL, positionInfo.TakeProfit()))
         {
            g_positionTrackers[i].breakEvenExecuted = true;
            Print("Break-even executed for ticket ", ticket, ", Profit %: ", DoubleToString(profitPercent, 2), ", New SL: ", newSL);
         }
      }
   }
}

void ProcessAdvancedTrailing(double trailStartPercent, int trailStepPoints, int maxTrailSteps = 10)
{
   for(int i = 0; i < ArraySize(g_positionTrackers); i++)
   {
      if(!g_positionTrackers[i].isActive)
         continue;
         
      ulong ticket = g_positionTrackers[i].ticket;
      if(!positionInfo.SelectByTicket(ticket))
         continue;
         
      double entryPrice = g_positionTrackers[i].entryPrice;
      double originalTP = g_positionTrackers[i].originalTP;
      double currentPrice = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 
                           symbolInfo.Bid() : symbolInfo.Ask();
      
      // Calculate current profit
      double tpDistance = MathAbs(originalTP - entryPrice);
      double currentProfit = 0;
      
      if(positionInfo.PositionType() == POSITION_TYPE_BUY)
         currentProfit = currentPrice - entryPrice;
      else
         currentProfit = entryPrice - currentPrice;
         
      double profitPercent = (tpDistance > 0) ? (currentProfit / tpDistance) * 100 : 0;
      
      // Update highest profit tracker
      if(currentProfit > g_positionTrackers[i].highestProfit)
         g_positionTrackers[i].highestProfit = currentProfit;
      
      // Start trailing when profit threshold is reached and max steps not exceeded
      if(profitPercent >= trailStartPercent && g_positionTrackers[i].trailingSteps < maxTrailSteps)
      {
         double currentSL = positionInfo.StopLoss();
         double stepDistance = trailStepPoints * symbolInfo.Point();
         double newSL = 0;
         
         if(positionInfo.PositionType() == POSITION_TYPE_BUY)
         {
            newSL = currentPrice - stepDistance;
            if(newSL > currentSL + symbolInfo.Point())
            {
               if(ModifyPosition(ticket, newSL, positionInfo.TakeProfit()))
               {
                  g_positionTrackers[i].trailingSteps++;
                  Print("Trailing SL updated for BUY ticket ", ticket, ", New SL: ", newSL, ", Steps: ", g_positionTrackers[i].trailingSteps);
               }
            }
         }
         else
         {
            newSL = currentPrice + stepDistance;
            if(newSL < currentSL - symbolInfo.Point())
            {
               if(ModifyPosition(ticket, newSL, positionInfo.TakeProfit()))
               {
                  g_positionTrackers[i].trailingSteps++;
                  Print("Trailing SL updated for SELL ticket ", ticket, ", New SL: ", newSL, ", Steps: ", g_positionTrackers[i].trailingSteps);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Enhanced Market Condition Analysis                              |
//+------------------------------------------------------------------+
void UpdateMarketCondition(int maxSpreadPoints = 50)
{
   g_marketCondition.lastUpdate = TimeCurrent();
   
   // Update spread
   g_marketCondition.spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_marketCondition.isGoodSpread = (g_marketCondition.spread <= maxSpreadPoints);
   
   // Calculate volatility (ATR-based)
   double atr[];
   int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
   {
      g_marketCondition.volatility = atr[0];
      g_marketCondition.isHighVolatility = (atr[0] > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100);
      IndicatorRelease(atrHandle);
   }
   
   // Update volume
   long volume[];
   if(CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 1, volume) > 0)
      g_marketCondition.volume = (double)volume[0];
   
   // Trading time check (basic)
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   g_marketCondition.isTradingTime = (time.day_of_week >= 1 && time.day_of_week <= 5 && 
                                     time.hour >= 1 && time.hour <= 23);
}

bool IsMarketConditionGood()
{
   UpdateMarketCondition();
   return (g_marketCondition.isGoodSpread && g_marketCondition.isTradingTime);
}

//+------------------------------------------------------------------+
//| Enhanced Session Management Functions                           |
//+------------------------------------------------------------------+
bool IsInSession(SessionTime &session, datetime time)
{
   if(!session.enabled)
      return false;
      
   MqlDateTime timeStruct;
   TimeToStruct(time, timeStruct);
   
   int currentMinutes = timeStruct.hour * 60 + timeStruct.min;
   int startMinutes = session.startHour * 60 + session.startMinute;
   int endMinutes = session.endHour * 60 + session.endMinute;
   
   if(startMinutes <= endMinutes)
   {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
   }
   else // Overnight session
   {
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
   }
}

bool IsInAnySession(SessionTime &sessions[], datetime time)
{
   for(int i = 0; i < ArraySize(sessions); i++)
   {
      if(IsInSession(sessions[i], time))
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Enhanced Utility Functions                                      |
//+------------------------------------------------------------------+
void LoadHistory(datetime startTime, string symbol, ENUM_TIMEFRAMES timeframe)
{
   datetime time[];
   if(CopyTime(symbol, timeframe, startTime, TimeCurrent(), time) > 0)
   {
      Print("History loaded successfully for ", symbol, " ", EnumToString(timeframe), " (", ArraySize(time), " bars)");
   }
}

// Optimized new bar detection
class CIsNewBar
{
private:
   datetime m_lastBarTime;
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
public:
   CIsNewBar() : m_lastBarTime(0) {}
   
   bool IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      datetime currentBarTime = iTime(symbol, timeframe, 0);
      
      if(m_symbol != symbol || m_timeframe != timeframe)
      {
         m_symbol = symbol;
         m_timeframe = timeframe;
         m_lastBarTime = currentBarTime;
         return false;
      }
      
      if(currentBarTime != m_lastBarTime)
      {
         m_lastBarTime = currentBarTime;
         return true;
      }
      
      return false;
   }
   
   datetime GetLastBarTime() { return m_lastBarTime; }
};

//+------------------------------------------------------------------+
//| Enhanced Performance Monitoring                                 |
//+------------------------------------------------------------------+
void PrintTradeStatistics()
{
   Print("=== Enhanced Trade Statistics ===");
   Print("Total Trades: ", g_tradeStats.totalTrades);
   Print("Win Trades: ", g_tradeStats.winTrades, " (", DoubleToString(g_tradeStats.winRate, 2), "%)");
   Print("Lose Trades: ", g_tradeStats.loseTrades);
   Print("Total Profit: ", DoubleToString(g_tradeStats.totalProfit - g_tradeStats.totalLoss, 2));
   Print("Profit Factor: ", DoubleToString(g_tradeStats.profitFactor, 2));
   Print("Average Win: ", DoubleToString(g_tradeStats.averageWin, 2));
   Print("Average Loss: ", DoubleToString(g_tradeStats.averageLoss, 2));
   Print("Max Profit: ", DoubleToString(g_tradeStats.maxProfit, 2));
   Print("Max Drawdown: ", DoubleToString(g_tradeStats.maxDrawdown, 2));
   Print("Max Consecutive Wins: ", g_tradeStats.maxConsecutiveWins);
   Print("Max Consecutive Losses: ", g_tradeStats.maxConsecutiveLosses);
   Print("Current Consecutive: ", g_tradeStats.consecutiveWins > 0 ? 
         "Wins=" + (string)g_tradeStats.consecutiveWins : "Losses=" + (string)g_tradeStats.consecutiveLosses);
   Print("Active Positions: ", CountActivePositions());
   Print("EA State: ", EnumToString(g_eaState));
   Print("=====================================");
}

void ResetDailyStatistics()
{
   g_tradeStats.totalTrades = 0;
   g_tradeStats.winTrades = 0;
   g_tradeStats.loseTrades = 0;
   g_tradeStats.totalProfit = 0;
   g_tradeStats.totalLoss = 0;
   g_tradeStats.maxDrawdown = 0;
   g_tradeStats.maxProfit = 0;
   g_tradeStats.lastTradeTime = 0;
   g_tradeStats.averageWin = 0;
   g_tradeStats.averageLoss = 0;
   g_tradeStats.profitFactor = 0;
   g_tradeStats.winRate = 0;
   g_tradeStats.consecutiveWins = 0;
   g_tradeStats.consecutiveLosses = 0;
   g_tradeStats.maxConsecutiveWins = 0;
   g_tradeStats.maxConsecutiveLosses = 0;
   
   Print("Daily statistics reset");
}