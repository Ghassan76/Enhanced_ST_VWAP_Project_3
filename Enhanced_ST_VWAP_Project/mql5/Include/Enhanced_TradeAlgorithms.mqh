//+------------------------------------------------------------------+
//|                                       Enhanced_TradeAlgorithms.mqh |
//|              Enhanced Trading Algorithms with FSM Architecture     |
//+------------------------------------------------------------------+
#property copyright "Enhanced Trading Algorithms © 2025"
#property link      "https://www.mql5.com"
#property version   "6.00"

#include <Trade\Trade.mqh>

//────────────────────────────────────────────────────────────────────
//  ENHANCED ENUMS, STRUCTS, CONSTANTS
//────────────────────────────────────────────────────────────────────
enum EA_STATE { 
   ST_READY = 0, ST_IN_TRADE, ST_FROZEN, ST_COOLDOWN, ST_ARMING 
};

enum DIR { 
   DIR_NONE = 0, DIR_BUY = 1, DIR_SELL = -1 
};

enum FREEZE_REASON { 
   FREEZE_TRADE_CLOSE = 0, 
   FREEZE_DATA_MISSING, 
   FREEZE_MANUAL,
   FREEZE_DAILY_LIMIT,
   FREEZE_CONNECTION_LOST
};

enum MarginMode {
   FREEMARGIN = 0,
   LOT = 1
};

// Constants
#define MAX_SESSIONS 4
#define RETRY_ATTEMPTS 5
#define RETRY_DELAY_MS 100
#define SECONDS_PER_DAY 86400
#define SECONDS_PER_MINUTE 60

//────────────────────────────────────────────────────────────────────
//  ENHANCED STRUCTURES
//────────────────────────────────────────────────────────────────────
struct SessionTime
{
   bool   enabled;
   int    startHour;
   int    startMinute;
   int    endHour;
   int    endMinute;
   string description;
   
   SessionTime() : enabled(false), startHour(0), startMinute(0), 
                   endHour(0), endMinute(0), description("") {}
};

struct PositionTracker
{
   ulong ticket;
   int slModifications;
   int tpModifications;
   ulong lastTickTime;
   bool breakEvenExecuted;
   datetime openTime;
   double openPrice;
   
   PositionTracker() : ticket(0), slModifications(0), tpModifications(0), 
                      lastTickTime(0), breakEvenExecuted(false),
                      openTime(0), openPrice(0.0) {}
};

struct TradeStats
{
   int totalTrades;
   int winTrades;
   int loseTrades;
   double totalProfit;
   double totalLoss;
   double maxDrawdown;
   double maxProfit;
   datetime lastTradeTime;
   double averageWin;
   double averageLoss;
   double profitFactor;
   double winRate;
   int consecutiveWins;
   int consecutiveLosses;
   int maxConsecutiveWins;
   int maxConsecutiveLosses;
   
   TradeStats()
   {
      totalTrades = winTrades = loseTrades = 0;
      totalProfit = totalLoss = maxDrawdown = maxProfit = 0.0;
      lastTradeTime = 0;
      averageWin = averageLoss = profitFactor = winRate = 0.0;
      consecutiveWins = consecutiveLosses = 0;
      maxConsecutiveWins = maxConsecutiveLosses = 0;
   }
};

//────────────────────────────────────────────────────────────────────
//  GLOBAL VARIABLES
//────────────────────────────────────────────────────────────────────
// Core EA state
EA_STATE g_eaState = ST_READY;
DIR g_currentBias = DIR_NONE;
datetime g_freezeUntil = 0;
datetime g_cooldownUntil = 0;
FREEZE_REASON g_freezeReason = FREEZE_TRADE_CLOSE;
datetime g_lastSignalTime = 0;

// Position tracking
PositionTracker g_positions[];
int g_positionCount = 0;

// Trade management
CTrade trade;

// Global Variables prefix
string GV_PREFIX = "";

//────────────────────────────────────────────────────────────────────
//  UTILITY FUNCTIONS
//────────────────────────────────────────────────────────────────────
string GV(const string tag, const ulong mag) 
{ 
   return _Symbol + "_" + tag + "_" + (string)mag; 
}

datetime DayFloor(datetime t) 
{ 
   return (datetime)((t / SECONDS_PER_DAY) * SECONDS_PER_DAY); 
}

double NormalizeLots(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(minLot <= 0.0 || maxLot <= 0.0 || stepLot <= 0.0) return 0.0;
   
   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = MathFloor(lots / stepLot) * stepLot;
   return NormalizeDouble(lots, 2);
}

string StateToString(EA_STATE state)
{
   switch(state) {
      case ST_READY:     return "READY";
      case ST_IN_TRADE:  return "IN_TRADE";
      case ST_FROZEN:    return "FROZEN";
      case ST_COOLDOWN:  return "COOLDOWN";
      case ST_ARMING:    return "ARMING";
      default:           return "UNKNOWN";
   }
}

//────────────────────────────────────────────────────────────────────
//  EA STATE MANAGEMENT
//────────────────────────────────────────────────────────────────────
void SetEAState(EA_STATE newState, FREEZE_REASON reason = FREEZE_TRADE_CLOSE)
{
   if(g_eaState != newState)
   {
      EA_STATE oldState = g_eaState;
      g_eaState = newState;
      g_freezeReason = reason;
      
      Print("EA State changed: ", StateToString(oldState), " -> ", StateToString(newState));
      
      // Save state to global variables
      GlobalVariableSet(GV("state", trade.RequestMagic()), (double)g_eaState);
      GlobalVariableSet(GV("reason", trade.RequestMagic()), (double)g_freezeReason);
   }
}

EA_STATE GetEAState()
{
   return g_eaState;
}

bool IsEAReadyToTrade()
{
   datetime currentTime = TimeCurrent();
   
   // Handle timed states
   if(g_eaState == ST_FROZEN && currentTime >= g_freezeUntil)
   {
      SetEAState(ST_ARMING);
   }
   
   if(g_eaState == ST_COOLDOWN && currentTime >= g_cooldownUntil)
   {
      SetEAState(ST_ARMING);
   }
   
   if(g_eaState == ST_ARMING)
   {
      SetEAState(ST_READY);
   }
   
   return (g_eaState == ST_READY);
}

void ConfigureStateDurations(int freezeMinutes, int cooldownMinutes)
{
   // State durations are configured via input parameters
   // This function can be used for runtime adjustments if needed
}

//────────────────────────────────────────────────────────────────────
//  POSITION MANAGEMENT
//────────────────────────────────────────────────────────────────────
int CountActivePositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == trade.RequestMagic())
         {
            count++;
         }
      }
   }
   return count;
}

bool CanOpenNewPosition()
{
   // Check if EA is ready to trade
   if(!IsEAReadyToTrade())
      return false;
   
   // Check if we already have positions (single trade logic)
   if(CountActivePositions() > 0)
      return false;
   
   return true;
}

ulong GetActivePositionTicket()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == trade.RequestMagic())
         {
            return ticket;
         }
      }
   }
   return 0;
}

//────────────────────────────────────────────────────────────────────
//  ENHANCED POSITION OPERATIONS
//────────────────────────────────────────────────────────────────────
bool BuyPositionOpen(bool openNow, string symbol, datetime signalTime, 
                     double lot, MarginMode mmMode, int slippage, 
                     int sl, int tp, ulong magic)
{
   if(!CanOpenNewPosition())
   {
      Print("Cannot open BUY position - conditions not met");
      return false;
   }
   
   double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(price <= 0)
   {
      Print("Invalid ASK price for BUY order");
      return false;
   }
   
   // Normalize lot size
   lot = NormalizeLots(lot);
   if(lot <= 0)
   {
      Print("Invalid lot size: ", lot);
      return false;
   }
   
   // Calculate SL and TP prices
   double stopLoss = (sl > 0) ? price - sl * _Point : 0;
   double takeProfit = (tp > 0) ? price + tp * _Point : 0;
   
   // Execute trade
   trade.SetExpertMagicNumber(magic);
   trade.SetDeviationInPoints(slippage);
   
   bool result = trade.Buy(lot, symbol, price, stopLoss, takeProfit, "Enhanced ST&VWAP BUY");
   
   if(result)
   {
      ulong ticket = trade.ResultOrder();
      SetEAState(ST_IN_TRADE);
      g_currentBias = DIR_BUY;
      Print("BUY position opened successfully. Ticket: ", ticket);
      return true;
   }
   else
   {
      Print("Failed to open BUY position. Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      return false;
   }
}

bool SellPositionOpen(bool openNow, string symbol, datetime signalTime, 
                      double lot, MarginMode mmMode, int slippage, 
                      int sl, int tp, ulong magic)
{
   if(!CanOpenNewPosition())
   {
      Print("Cannot open SELL position - conditions not met");
      return false;
   }
   
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(price <= 0)
   {
      Print("Invalid BID price for SELL order");
      return false;
   }
   
   // Normalize lot size
   lot = NormalizeLots(lot);
   if(lot <= 0)
   {
      Print("Invalid lot size: ", lot);
      return false;
   }
   
   // Calculate SL and TP prices
   double stopLoss = (sl > 0) ? price + sl * _Point : 0;
   double takeProfit = (tp > 0) ? price - tp * _Point : 0;
   
   // Execute trade
   trade.SetExpertMagicNumber(magic);
   trade.SetDeviationInPoints(slippage);
   
   bool result = trade.Sell(lot, symbol, price, stopLoss, takeProfit, "Enhanced ST&VWAP SELL");
   
   if(result)
   {
      ulong ticket = trade.ResultOrder();
      SetEAState(ST_IN_TRADE);
      g_currentBias = DIR_SELL;
      Print("SELL position opened successfully. Ticket: ", ticket);
      return true;
   }
   else
   {
      Print("Failed to open SELL position. Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      return false;
   }
}

bool BuyPositionClose(bool closeNow, string symbol, int slippage, ulong magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == magic &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            trade.SetDeviationInPoints(slippage);
            bool result = trade.PositionClose(ticket);
            
            if(result)
            {
               Print("BUY position closed successfully. Ticket: ", ticket);
               return true;
            }
            else
            {
               Print("Failed to close BUY position. Ticket: ", ticket, " Error: ", trade.ResultRetcode());
            }
         }
      }
   }
   return false;
}

bool SellPositionClose(bool closeNow, string symbol, int slippage, ulong magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == magic &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            trade.SetDeviationInPoints(slippage);
            bool result = trade.PositionClose(ticket);
            
            if(result)
            {
               Print("SELL position closed successfully. Ticket: ", ticket);
               return true;
            }
            else
            {
               Print("Failed to close SELL position. Ticket: ", ticket, " Error: ", trade.ResultRetcode());
            }
         }
      }
   }
   return false;
}

//────────────────────────────────────────────────────────────────────
//  POSITION TRACKING AND TRAILING
//────────────────────────────────────────────────────────────────────
void RegisterPositionTracker(ulong ticket)
{
   int size = ArraySize(g_positions);
   ArrayResize(g_positions, size + 1);
   
   g_positions[size].ticket = ticket;
   g_positions[size].slModifications = 0;
   g_positions[size].tpModifications = 0;
   g_positions[size].lastTickTime = GetTickCount();
   g_positions[size].breakEvenExecuted = false;
   
   if(PositionSelectByTicket(ticket))
   {
      g_positions[size].openTime = (datetime)PositionGetInteger(POSITION_TIME);
      g_positions[size].openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   }
   
   g_positionCount++;
}

void RemovePositionTracker(ulong ticket)
{
   for(int i = 0; i < ArraySize(g_positions); i++)
   {
      if(g_positions[i].ticket == ticket)
      {
         // Shift remaining elements
         for(int j = i; j < ArraySize(g_positions) - 1; j++)
         {
            g_positions[j] = g_positions[j + 1];
         }
         ArrayResize(g_positions, ArraySize(g_positions) - 1);
         g_positionCount--;
         break;
      }
   }
}

//────────────────────────────────────────────────────────────────────
//  BREAK-EVEN AND TRAILING FUNCTIONS
//────────────────────────────────────────────────────────────────────
void ProcessBreakEven(double breakEvenPercent, double offsetPercent)
{
   for(int i = 0; i < ArraySize(g_positions); i++)
   {
      ulong ticket = g_positions[i].ticket;
      
      if(g_positions[i].breakEvenExecuted)
         continue;
         
      if(!PositionSelectByTicket(ticket))
      {
         RemovePositionTracker(ticket);
         continue;
      }
      
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      
      if(currentTP == 0) continue; // No TP set
      
      double tpDistance = MathAbs(currentTP - openPrice);
      double profitDistance = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);
      
      if(profitDistance >= tpDistance * breakEvenPercent / 100.0)
      {
         double newSL = openPrice + (isBuy ? 1 : -1) * tpDistance * offsetPercent / 100.0;
         
         if(trade.PositionModify(ticket, newSL, currentTP))
         {
            g_positions[i].breakEvenExecuted = true;
            Print("Break-even executed for ticket: ", ticket, " New SL: ", newSL);
         }
      }
   }
}

void ProcessAdvancedTrailing(double trailStartPercent, int trailStepPoints, int maxSteps)
{
   for(int i = 0; i < ArraySize(g_positions); i++)
   {
      ulong ticket = g_positions[i].ticket;
      
      if(!PositionSelectByTicket(ticket))
      {
         RemovePositionTracker(ticket);
         continue;
      }
      
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      
      if(currentTP == 0) continue; // No TP set
      
      double tpDistance = MathAbs(currentTP - openPrice);
      double profitDistance = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);
      
      if(profitDistance >= tpDistance * trailStartPercent / 100.0)
      {
         double trailStep = trailStepPoints * _Point;
         double newSL = currentSL + (isBuy ? trailStep : -trailStep);
         
         // Ensure minimum distance from current price
         double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
         if(isBuy && currentPrice - newSL < minDistance)
            newSL = currentPrice - minDistance;
         else if(!isBuy && newSL - currentPrice < minDistance)
            newSL = currentPrice + minDistance;
         
         if((isBuy && newSL > currentSL) || (!isBuy && newSL < currentSL))
         {
            if(trade.PositionModify(ticket, newSL, currentTP))
            {
               Print("Trailing stop updated for ticket: ", ticket, " New SL: ", newSL);
            }
         }
      }
   }
}

//────────────────────────────────────────────────────────────────────
//  LOT CALCULATION
//────────────────────────────────────────────────────────────────────
double CalculateOptimalLot(double riskPercent, double slPoints, string symbol)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0) return 0.01;
   
   double riskAmount = equity * riskPercent / 100.0;
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue <= 0 || tickSize <= 0 || slPoints <= 0)
      return 0.01;
   
   double valuePerPoint = tickValue / tickSize;
   double lotSize = riskAmount / (slPoints * valuePerPoint);
   
   return NormalizeLots(lotSize);
}

//────────────────────────────────────────────────────────────────────
//  SESSION MANAGEMENT
//────────────────────────────────────────────────────────────────────
bool IsInSession(const SessionTime &session, datetime currentTime)
{
   if(!session.enabled)
      return false;
   
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   int currentMinutes = dt.hour * 60 + dt.min;
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

//────────────────────────────────────────────────────────────────────
//  DAILY STATISTICS MANAGEMENT
//────────────────────────────────────────────────────────────────────
void ResetDailyStatistics()
{
   // Reset daily counters
   GlobalVariableSet(GV("dayTrades", trade.RequestMagic()), 0);
   GlobalVariableSet(GV("dayProfit", trade.RequestMagic()), 0.0);
   GlobalVariableSet(GV("dayLoss", trade.RequestMagic()), 0.0);
   GlobalVariableSet(GV("dayStamp", trade.RequestMagic()), (double)DayFloor(TimeCurrent()));
}

void UpdateTradeStats(double profit)
{
   // Update daily statistics
   double dayTrades = GlobalVariableGet(GV("dayTrades", trade.RequestMagic()));
   double dayProfit = GlobalVariableGet(GV("dayProfit", trade.RequestMagic()));
   double dayLoss = GlobalVariableGet(GV("dayLoss", trade.RequestMagic()));
   
   dayTrades++;
   if(profit > 0)
      dayProfit += profit;
   else
      dayLoss += MathAbs(profit);
   
   GlobalVariableSet(GV("dayTrades", trade.RequestMagic()), dayTrades);
   GlobalVariableSet(GV("dayProfit", trade.RequestMagic()), dayProfit);
   GlobalVariableSet(GV("dayLoss", trade.RequestMagic()), dayLoss);
   
   Print("Trade statistics updated: Trades=", (int)dayTrades, " Profit=", dayProfit, " Loss=", dayLoss);
}

void PrintTradeStatistics()
{
   double dayTrades = GlobalVariableGet(GV("dayTrades", trade.RequestMagic()));
   double dayProfit = GlobalVariableGet(GV("dayProfit", trade.RequestMagic()));
   double dayLoss = GlobalVariableGet(GV("dayLoss", trade.RequestMagic()));
   
   Print("═══ Daily Trade Statistics ═══");
   Print("Total Trades: ", (int)dayTrades);
   Print("Total Profit: ", DoubleToString(dayProfit, 2));
   Print("Total Loss: ", DoubleToString(dayLoss, 2));
   Print("Net P&L: ", DoubleToString(dayProfit - dayLoss, 2));
   
   if(dayTrades > 0)
   {
      Print("Average per trade: ", DoubleToString((dayProfit - dayLoss) / dayTrades, 2));
   }
}

//────────────────────────────────────────────────────────────────────
//  HISTORY LOADING
//────────────────────────────────────────────────────────────────────
bool LoadHistory(datetime startTime, string symbol, ENUM_TIMEFRAMES timeframe)
{
   int bars = Bars(symbol, timeframe);
   if(bars < 100) // Need minimum bars
   {
      // Force load more history
      datetime time[];
      return CopyTime(symbol, timeframe, startTime, TimeCurrent(), time) > 0;
   }
   return true;
}