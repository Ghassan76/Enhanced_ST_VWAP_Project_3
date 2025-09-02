//+------------------------------------------------------------------+
//|                                        Enhanced_ST_VWAP_EA.mq5 |
//|              Enhanced SuperTrend & VWAP Expert Advisor with FSM |
//+------------------------------------------------------------------+
#property copyright "Enhanced ST&VWAP Expert Advisor © 2025"
#property link      "https://www.mql5.com"
#property version   "7.00"
#property description "Enhanced EA with Finite State Machine Architecture & Single Trade Logic"

//+------------------------------------------------------------------+
//| Include Files                                                    |
//+------------------------------------------------------------------+
#include <Enhanced_TradeAlgorithms.mqh>

//+------------------------------------------------------------------+
//| Enhanced Input Parameters                                        |
//+------------------------------------------------------------------+
// General Settings
input group "═══ General Settings ═══";
input ulong   MagicNumber                 = 567890;     // Magic number for trades
input bool    VerboseLogs                 = true;       // Verbose logging mode
input bool    EnableEntry                 = true;       // Master enable switch
input bool    EnableBuy                   = true;       // Allow long trades
input bool    EnableSell                  = true;       // Allow short trades

// Time and Day Filters
input group "═══ Time and Day Filters ═══";
input bool    UseTimeFilter               = true;       // Use time filter
input int     BeginHour                   = 15;         // Trading start hour
input int     BeginMinute                 = 0;          // Trading start minute
input int     EndHour                     = 22;         // Trading end hour
input int     EndMinute                   = 59;         // Trading end minute
input bool    TradeSun                    = false;      // Trade on Sunday
input bool    TradeMon                    = true;       // Trade on Monday
input bool    TradeTue                    = true;       // Trade on Tuesday
input bool    TradeWed                    = true;       // Trade on Wednesday
input bool    TradeThu                    = true;       // Trade on Thursday
input bool    TradeFri                    = true;       // Trade on Friday
input bool    TradeSat                    = false;      // Trade on Saturday

// Multiple Trading Sessions
input group "═══ Multiple Trading Sessions ═══";
input bool    Session1_Enable             = false;      // Enable session 1
input int     Session1_StartHour          = 9;          // Session 1 start hour
input int     Session1_StartMinute        = 0;          // Session 1 start minute
input int     Session1_EndHour            = 12;         // Session 1 end hour
input int     Session1_EndMinute          = 0;          // Session 1 end minute

input bool    Session2_Enable             = false;      // Enable session 2
input int     Session2_StartHour          = 13;         // Session 2 start hour
input int     Session2_StartMinute        = 0;          // Session 2 start minute
input int     Session2_EndHour            = 17;         // Session 2 end hour
input int     Session2_EndMinute          = 0;          // Session 2 end minute

input bool    Session3_Enable             = false;      // Enable session 3
input int     Session3_StartHour          = 20;         // Session 3 start hour
input int     Session3_StartMinute        = 0;          // Session 3 start minute
input int     Session3_EndHour            = 23;         // Session 3 end hour
input int     Session3_EndMinute          = 0;          // Session 3 end minute

input bool    Session4_Enable             = false;      // Enable session 4
input int     Session4_StartHour          = 0;          // Session 4 start hour
input int     Session4_StartMinute        = 0;          // Session 4 start minute
input int     Session4_EndHour            = 6;          // Session 4 end hour
input int     Session4_EndMinute          = 0;          // Session 4 end minute

// Market Conditions
input group "═══ Market Conditions ═══";
input int     MaxSpreadPts                = 50;         // Maximum spread in points
input bool    EnableVolatilityFilter      = true;       // Enable volatility filter
input double  MinVolatilityThreshold      = 0.5;        // Minimum volatility threshold

// Position Sizing
input group "═══ Position Sizing ═══";
input bool    DynamicLots                 = true;       // Use dynamic lot sizing
input double  RiskPct                     = 1.0;        // Risk percentage for dynamic lots
input double  FixedLot                    = 0.10;       // Fixed lot size
input int     SlippagePts                 = 30;         // Order slippage

// Stop Loss & Take Profit
input group "═══ Stop Loss & Take Profit ═══";
input bool    UseMoneyTargets             = false;      // Use money-based SL/TP
input double  MoneySLAmount               = 50.0;       // Stop loss in money
input double  MoneyTPAmount               = 100.0;      // Take profit in money
input double  PointsSL                    = 500;        // Stop loss in points
input double  PointsTP                    = 1000;       // Take profit in points

// Enhanced State Management
input group "═══ State Management ═══";
input int     FreezeDurationMinutes       = 10;         // Freeze duration after issues
input int     PostTradeCooldownMin        = 2;          // Cooldown after trade close
input bool    FreezeOnDataMissing         = true;       // Freeze on missing data
input bool    EnableConnectionMonitor     = true;       // Monitor connection status

// Enhanced Smart Trailing with Break-Even
input group "═══ Enhanced Smart Trailing ═══";
input bool    EnableBreakEven             = true;       // Enable break-even functionality
input bool    EnableSmartTrailing         = true;       // Enable smart trailing functionality
input double  BreakEvenPercent            = 40.0;       // Profit % to trigger break-even
input double  BESLPctOfTP                 = 5.0;        // Break-even SL offset as % of TP span
input double  TrailStartPercent           = 60.0;       // Profit % to start trailing
input int     TrailingSLStepPoints        = 100;        // Step size for SL trailing (points)
input int     MaxTrailingSteps            = 10;         // Maximum trailing steps
input int     CheckIntervalSec            = 30;         // Timer interval for trailing checks

// Modification Limits
input group "═══ Modification Limits ═══";
input int     MaxSLModifications          = 5;          // Max SL changes per position (-1 = unlimited)
input int     MaxTPModifications          = 3;          // Max TP changes per position (-1 = unlimited)
input bool    LogModificationLimits       = true;       // Log when limits are reached

// Daily Risk Management
input group "═══ Daily Risk Management ═══";
input bool    EnableMaxTradesPerDay       = true;       // Enable daily trade limit
input int     MaxTradesPerDay             = 5;          // Maximum trades per day
input bool    EnableProfitCap             = false;      // Enable daily profit cap
input double  DailyProfitTarget           = 200.0;      // Daily profit target
input bool    EnableLossLimit             = true;       // Enable daily loss limit
input double  DailyLossLimit              = 100.0;      // Daily loss limit

// SuperTrend & VWAP Indicator Parameters - CLEAN PARAMETERS (NO SEPARATORS)
input group "═══ SuperTrend & VWAP Parameters ═══";
input ENUM_TIMEFRAMES InpIndTimeframe     = PERIOD_H1;  // Indicator timeframe
input int     ATRPeriod                   = 22;         // ATR period for SuperTrend
input double  STMultiplier                = 3.0;        // SuperTrend multiplier
input ENUM_APPLIED_PRICE SourcePrice      = PRICE_MEDIAN; // Price for SuperTrend calculation
input bool    TakeWicksIntoAccount        = true;       // Consider wicks in calculation
input bool    EnableVWAPFilter            = true;       // Enable VWAP filtering
input ENUM_APPLIED_PRICE VWAPPriceMethod  = PRICE_TYPICAL; // VWAP calculation price
input double  MinVolumeThreshold          = 1.0;        // Minimum volume for VWAP
input bool    ResetVWAPDaily              = true;       // Reset VWAP daily
input int     VWAPLookbackPeriod          = 100;        // VWAP calculation lookback period
input uint    SignalBar                   = 1;          // Bar number for signal (0=current, 1=previous)

// Enhanced Signal Filtering
input group "═══ Enhanced Signal Filtering ═══";
input double  MinPointsFromVWAP           = 20.0;       // Minimum distance from VWAP in points
input bool    EnableSignalConfirmation    = true;       // Require signal confirmation
input int     SignalConfirmationBars      = 2;          // Bars for signal confirmation
input bool    EnableTrendFilter           = true;       // Enable trend direction filter
input int     TrendFilterPeriod           = 50;         // Period for trend filter

// Performance Optimization
input group "═══ Performance Optimization ═══";
input bool    OptimizeCalculations        = true;       // Optimize calculations
input bool    EnablePerformanceMonitor    = true;       // Monitor EA performance
input int     StatisticsUpdateInterval    = 60;         // Statistics update interval (seconds)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
int TimeShiftSec;                                        // Timeframe shift in seconds
int STVWAPHandle;                                        // ST&VWAP indicator handle
int min_rates_total;                                     // Minimum rates required

SessionTime g_sessions[4];                               // Trading sessions
TradeStats g_dailyStats;                                 // Daily statistics
datetime g_lastDayReset = 0;                            // Last day reset timestamp

// Signal tracking variables - FIXED FOR PROPER SINGLE TRADE LOGIC
static bool BUY_Signal = false, SELL_Signal = false;    // Current signal flags
static datetime g_lastBarTime = 0;                       // Last processed bar time
static datetime g_lastSignalProcessed = 0;               // Last signal processed time

// Performance monitoring
static datetime g_lastPerformanceUpdate = 0;
static int g_totalTicks = 0;
static int g_processedTicks = 0;

// Connection monitoring
static datetime g_lastConnectionCheck = 0;
static bool g_connectionLost = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("═══ Initializing Enhanced ST&VWAP EA v7.0 ═══");
    
    // Initialize trading algorithms
    trade.SetExpertMagicNumber(MagicNumber);

    // Configure state durations
    ConfigureStateDurations(FreezeDurationMinutes, PostTradeCooldownMin);
    
    // FIXED: Get handle for Enhanced ST&VWAP indicator with CLEAN PARAMETERS
    STVWAPHandle = iCustom(_Symbol, InpIndTimeframe, "Enhanced_ST_VWAP_Indicator",
                          ATRPeriod, STMultiplier, SourcePrice, TakeWicksIntoAccount,
                          VWAPPriceMethod, MinVolumeThreshold, ResetVWAPDaily,
                          VWAPLookbackPeriod, EnableVWAPFilter, true, MinPointsFromVWAP);
    
    if(STVWAPHandle == INVALID_HANDLE)
    {
        Print("CRITICAL ERROR: Failed to get Enhanced ST&VWAP indicator handle");
        return(INIT_FAILED);
    }
    
    // Initialize timeframe parameters
    TimeShiftSec = PeriodSeconds(InpIndTimeframe);
    min_rates_total = int(ATRPeriod + SignalBar + 20);
    
    // Initialize trading sessions
    InitializeSessions();
    
    // Initialize daily statistics
    ResetDailyStatistics();
    
    // Set initial EA state to READY
    SetEAState(ST_READY);
    
    // Validate input parameters
    if(!ValidateInputParameters())
    {
        Print("CRITICAL ERROR: Invalid input parameters detected");
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    // Set timer for periodic operations
    if(CheckIntervalSec > 0)
        EventSetTimer(CheckIntervalSec);
    
    // Print initialization summary
    PrintInitializationSummary();
    
    Print("═══ Enhanced ST&VWAP EA v7.0 initialized successfully ═══");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("═══ Deinitializing Enhanced ST&VWAP EA v7.0 ═══");
    
    // Kill timer
    EventKillTimer();
    
    // Clean up global variables
    GlobalVariableDel_(_Symbol);
    
    // Release indicator handle
    if(STVWAPHandle != INVALID_HANDLE)
        IndicatorRelease(STVWAPHandle);
    
    // Print final statistics
    if(VerboseLogs)
    {
        PrintTradeStatistics();
        PrintPerformanceSummary();
    }
    
    Print("Enhanced ST&VWAP EA deinitialized. Reason: ", GetDeinitReasonText(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function - ENHANCED WITH PROPER FSM                 |
//+------------------------------------------------------------------+
void OnTick()
{
    g_totalTicks++;
    
    // Connection monitoring
    if(EnableConnectionMonitor && !MonitorConnection())
        return;
    
    // FINITE STATE MACHINE - Handle current state
    ProcessStateMachine();
    
    // Only process signals if EA is READY
    if(GetEAState() != ST_READY)
    {
        if(VerboseLogs && g_totalTicks % 1000 == 0) // Log every 1000 ticks to avoid spam
            Print("EA not ready to trade. State: ", StateToString(GetEAState()));
        return;
    }
    
    g_processedTicks++;
    
    // Check daily statistics reset
    CheckDailyReset();
    
    // Check daily risk limits
    if(!CheckDailyLimits())
        return;
    
    // Check market conditions
    if(!CheckMarketConditions())
        return;
    
    // Check time filters
    if(!CheckTimeFilters())
        return;
    
    // Check indicator data availability
    if(BarsCalculated(STVWAPHandle) < min_rates_total)
    {
        if(FreezeOnDataMissing)
        {
            Print("WARNING: Insufficient indicator data. Bars calculated: ", BarsCalculated(STVWAPHandle), " Required: ", min_rates_total);
            SetEAState(ST_FROZEN, FREEZE_DATA_MISSING);
        }
        return;
    }
    
    // Load history for proper indicator calculation
    LoadHistory(TimeCurrent() - PeriodSeconds(InpIndTimeframe) - 1, _Symbol, InpIndTimeframe);
    
    // Process trading signals with FSM logic
    ProcessTradingSignalsWithFSM();
    
    // Process advanced position management
    ProcessAdvancedPositionManagement();
    
    // Update performance statistics periodically
    if(EnablePerformanceMonitor && TimeCurrent() - g_lastPerformanceUpdate >= StatisticsUpdateInterval)
    {
        UpdatePerformanceStatistics();
        g_lastPerformanceUpdate = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| ENHANCED FINITE STATE MACHINE PROCESSOR                         |
//+------------------------------------------------------------------+
void ProcessStateMachine()
{
    EA_STATE currentState = GetEAState();
    datetime currentTime = TimeCurrent();
    
    switch(currentState)
    {
        case ST_READY:
            // Ready to accept signals - main processing happens in OnTick
            break;
            
        case ST_IN_TRADE:
            // Check if position still exists
            if(CountActivePositions() == 0)
            {
                // Position was closed - enter cooldown or freeze
                if(PostTradeCooldownMin > 0)
                {
                    g_cooldownUntil = currentTime + PostTradeCooldownMin * 60;
                    SetEAState(ST_COOLDOWN);
                    Print("Position closed - entering cooldown until: ", TimeToString(g_cooldownUntil));
                }
                else
                {
                    g_freezeUntil = currentTime + FreezeDurationMinutes * 60;
                    SetEAState(ST_FROZEN, FREEZE_TRADE_CLOSE);
                    Print("Position closed - entering freeze until: ", TimeToString(g_freezeUntil));
                }
            }
            break;
            
        case ST_FROZEN:
            // Check if freeze period expired
            if(currentTime >= g_freezeUntil)
            {
                SetEAState(ST_ARMING);
                Print("Freeze period expired - entering arming state");
            }
            break;
            
        case ST_COOLDOWN:
            // Check if cooldown period expired
            if(currentTime >= g_cooldownUntil)
            {
                SetEAState(ST_ARMING);
                Print("Cooldown period expired - entering arming state");
            }
            break;
            
        case ST_ARMING:
            // Reset signal flags and move to ready state
            BUY_Signal = false;
            SELL_Signal = false;
            SetEAState(ST_READY);
            Print("EA armed and ready for new signals");
            break;
    }
}

//+------------------------------------------------------------------+
//| ENHANCED TRADING SIGNAL PROCESSING WITH FSM                     |
//+------------------------------------------------------------------+
void ProcessTradingSignalsWithFSM()
{
    // Only process signals if EA is READY
    if(GetEAState() != ST_READY)
        return;
    
    // Detect new bar
    datetime curBarTime = iTime(_Symbol, InpIndTimeframe, 0);
    bool isNewBar = (curBarTime != g_lastBarTime);
    
    // Only process on new bar or if no previous bar processed
    if(!isNewBar && g_lastBarTime != 0)
        return;
        
    g_lastBarTime = curBarTime;
    
    // Reset signal flags for new bar
    BUY_Signal = false;
    SELL_Signal = false;
    
    // Get signal from indicator
    double signal[1];
    if(CopyBuffer(STVWAPHandle, 6, SignalBar, 1, signal) <= 0) // Buffer 6 is SignalBuffer
    {
        if(VerboseLogs) Print("Failed to copy signal buffer from indicator");
        return;
    }
    
    datetime signalTime = iTime(_Symbol, InpIndTimeframe, SignalBar);
    double price = iClose(_Symbol, InpIndTimeframe, SignalBar);
    
    // Process signal only if it's new and different from last processed
    if(signalTime <= g_lastSignalProcessed)
        return;
    
    int signalDirection = (signal[0] > 0) ? 1 : (signal[0] < 0) ? -1 : 0;
    
    if(signalDirection == 0)
        return; // No signal
    
    // Enhanced signal validation
    if(!ValidateSignalConditions(signalTime, price, signalDirection))
        return;
    
    // Set signal flags based on direction
    if(signalDirection > 0 && EnableBuy && EnableEntry)
    {
        // Additional confirmation for BUY signals
        if(EnableSignalConfirmation && !ConfirmBullishSignal())
        {
            if(VerboseLogs) Print("BUY signal confirmation failed");
            return;
        }
        BUY_Signal = true;
        g_lastSignalProcessed = signalTime;
        if(VerboseLogs) Print("VALID BUY signal detected at ", TimeToString(signalTime), " Price: ", DoubleToString(price, _Digits));
    }
    else if(signalDirection < 0 && EnableSell && EnableEntry)
    {
        // Additional confirmation for SELL signals
        if(EnableSignalConfirmation && !ConfirmBearishSignal())
        {
            if(VerboseLogs) Print("SELL signal confirmation failed");
            return;
        }
        SELL_Signal = true;
        g_lastSignalProcessed = signalTime;
        if(VerboseLogs) Print("VALID SELL signal detected at ", TimeToString(signalTime), " Price: ", DoubleToString(price, _Digits));
    }
    
    // Execute trades based on signals
    ExecuteTradesWithFSM();
}

//+------------------------------------------------------------------+
//| EXECUTE TRADES WITH FSM LOGIC                                   |
//+------------------------------------------------------------------+
void ExecuteTradesWithFSM()
{
    // CRITICAL: Only execute if EA is READY and no positions exist
    if(GetEAState() != ST_READY || CountActivePositions() > 0)
        return;
    
    // Calculate lot size
    double lotSize = DynamicLots ? CalculateOptimalLot(RiskPct, PointsSL, _Symbol) : FixedLot;
    MarginMode mmMode = DynamicLots ? FREEMARGIN : LOT;
    
    // Execute BUY signal
    if(BUY_Signal)
    {
        int sl = UseMoneyTargets ? CalculatePointsFromMoney(MoneySLAmount, true) : (int)PointsSL;
        int tp = UseMoneyTargets ? CalculatePointsFromMoney(MoneyTPAmount, false) : (int)PointsTP;
        
        if(BuyPositionOpen(true, _Symbol, TimeCurrent(), lotSize, mmMode, SlippagePts, sl, tp, MagicNumber))
        {
            SetEAState(ST_IN_TRADE);
            g_dailyStats.totalTrades++;
            BUY_Signal = false; // Clear signal after execution
            
            // Register position for trailing
            ulong ticket = GetActivePositionTicket();
            if(ticket > 0 && (EnableBreakEven || EnableSmartTrailing))
                RegisterPositionTracker(ticket);
            
            Print("SUCCESS: BUY position opened. Lot: ", lotSize, " SL: ", sl, " TP: ", tp, " EA State: IN_TRADE");
        }
        else
        {
            Print("FAILED: Could not open BUY position");
            BUY_Signal = false; // Clear signal after failed attempt
        }
    }
    
    // Execute SELL signal
    if(SELL_Signal)
    {
        int sl = UseMoneyTargets ? CalculatePointsFromMoney(MoneySLAmount, true) : (int)PointsSL;
        int tp = UseMoneyTargets ? CalculatePointsFromMoney(MoneyTPAmount, false) : (int)PointsTP;
        
        if(SellPositionOpen(true, _Symbol, TimeCurrent(), lotSize, mmMode, SlippagePts, sl, tp, MagicNumber))
        {
            SetEAState(ST_IN_TRADE);
            g_dailyStats.totalTrades++;
            SELL_Signal = false; // Clear signal after execution
            
            // Register position for trailing
            ulong ticket = GetActivePositionTicket();
            if(ticket > 0 && (EnableBreakEven || EnableSmartTrailing))
                RegisterPositionTracker(ticket);
            
            Print("SUCCESS: SELL position opened. Lot: ", lotSize, " SL: ", sl, " TP: ", tp, " EA State: IN_TRADE");
        }
        else
        {
            Print("FAILED: Could not open SELL position");
            SELL_Signal = false; // Clear signal after failed attempt
        }
    }
}

//+------------------------------------------------------------------+
//| Validate signal conditions                                       |
//+------------------------------------------------------------------+
bool ValidateSignalConditions(datetime signalTime, double price, int dir)
{
    // Trend filter validation
    if(EnableTrendFilter && !ValidateTrendDirection(price, dir))
    {
        if(VerboseLogs) Print("Signal rejected by trend filter");
        return false;
    }

    // Volatility filter validation
    if(EnableVolatilityFilter && !ValidateVolatility())
    {
        if(VerboseLogs) Print("Signal rejected by volatility filter");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Confirm bullish signal                                           |
//+------------------------------------------------------------------+
bool ConfirmBullishSignal()
{
    if(!EnableSignalConfirmation) return true;
    
    // Check multiple bars for confirmation
    double close[];
    double st[];
    double vwap[];
    
    if(CopyClose(_Symbol, InpIndTimeframe, SignalBar, SignalConfirmationBars, close) < SignalConfirmationBars)
        return false;
        
    if(CopyBuffer(STVWAPHandle, 0, SignalBar, SignalConfirmationBars, st) < SignalConfirmationBars)
        return false;
        
    if(CopyBuffer(STVWAPHandle, 2, SignalBar, SignalConfirmationBars, vwap) < SignalConfirmationBars)
        return false;
    
    // Confirm price is above SuperTrend and VWAP
    for(int i = 0; i < SignalConfirmationBars; i++)
    {
        if(close[i] <= st[i] || (EnableVWAPFilter && close[i] <= vwap[i]))
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Confirm bearish signal                                           |
//+------------------------------------------------------------------+
bool ConfirmBearishSignal()
{
    if(!EnableSignalConfirmation) return true;
    
    // Check multiple bars for confirmation
    double close[];
    double st[];
    double vwap[];
    
    if(CopyClose(_Symbol, InpIndTimeframe, SignalBar, SignalConfirmationBars, close) < SignalConfirmationBars)
        return false;
        
    if(CopyBuffer(STVWAPHandle, 0, SignalBar, SignalConfirmationBars, st) < SignalConfirmationBars)
        return false;
        
    if(CopyBuffer(STVWAPHandle, 2, SignalBar, SignalConfirmationBars, vwap) < SignalConfirmationBars)
        return false;
    
    // Confirm price is below SuperTrend and VWAP
    for(int i = 0; i < SignalConfirmationBars; i++)
    {
        if(close[i] >= st[i] || (EnableVWAPFilter && close[i] >= vwap[i]))
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate trend direction                                         |
//+------------------------------------------------------------------+
bool ValidateTrendDirection(double currentPrice, int dir)
{
    double ma[];
    int maHandle = iMA(_Symbol, InpIndTimeframe, TrendFilterPeriod, 0, MODE_EMA, PRICE_CLOSE);
    
    if(maHandle == INVALID_HANDLE)
        return true; // Skip validation if can't create MA
        
    if(CopyBuffer(maHandle, 0, SignalBar, 1, ma) < 1)
    {
        IndicatorRelease(maHandle);
        return true;
    }
    
    bool trendOK = true;

    if(dir > 0 && currentPrice < ma[0])
        trendOK = false;
    if(dir < 0 && currentPrice > ma[0])
        trendOK = false;

    IndicatorRelease(maHandle);
    return trendOK;
}

//+------------------------------------------------------------------+
//| Validate volatility conditions                                  |
//+------------------------------------------------------------------+
bool ValidateVolatility()
{
    double atr[];
    int atrHandle = iATR(_Symbol, InpIndTimeframe, 14);
    
    if(atrHandle == INVALID_HANDLE)
        return true;
        
    if(CopyBuffer(atrHandle, 0, SignalBar, 1, atr) < 1)
    {
        IndicatorRelease(atrHandle);
        return true;
    }
    
    double volatility = atr[0] / _Point;
    bool volatilityOK = volatility >= MinVolatilityThreshold;
    
    IndicatorRelease(atrHandle);
    return volatilityOK;
}

//+------------------------------------------------------------------+
//| Process advanced position management                             |
//+------------------------------------------------------------------+
void ProcessAdvancedPositionManagement()
{
    // Only process if we have positions
    if(CountActivePositions() == 0)
        return;
        
    // Break-even management
    if(EnableBreakEven)
        ProcessBreakEven(BreakEvenPercent, BESLPctOfTP);
    
    // Advanced trailing management
    if(EnableSmartTrailing)
        ProcessAdvancedTrailing(TrailStartPercent, TrailingSLStepPoints, MaxTrailingSteps);
}

//+------------------------------------------------------------------+
//| Enhanced market conditions check                                 |
//+------------------------------------------------------------------+
bool CheckMarketConditions()
{
    // Check spread
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    if(spread > MaxSpreadPts)
    {
        if(VerboseLogs && g_totalTicks % 1000 == 0) 
            Print("Market conditions unfavorable - Spread too high: ", spread, " > ", MaxSpreadPts);
        return false;
    }
    
    // Check trading hours (basic market open check)
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    if(time.day_of_week == 0 || time.day_of_week == 6) // Weekend
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Enhanced time filters check                                     |
//+------------------------------------------------------------------+
bool CheckTimeFilters()
{
    datetime currentTime = TimeCurrent();
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);
    
    // Check day of week filter
    if(!CheckDayFilter(timeStruct.day_of_week))
        return false;
    
    // Check main time filter
    if(UseTimeFilter && !CheckTimeRange(timeStruct.hour, timeStruct.min, BeginHour, BeginMinute, EndHour, EndMinute))
        return false;
    
    // Check trading sessions
    bool inSession = false;
    for(int i = 0; i < 4; i++)
    {
        if(IsInSession(g_sessions[i], currentTime))
        {
            inSession = true;
            break;
        }
    }
    
    // If any session is enabled, we must be in at least one session
    bool anySessionEnabled = Session1_Enable || Session2_Enable || Session3_Enable || Session4_Enable;
    if(anySessionEnabled && !inSession)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check day of week filter                                        |
//+------------------------------------------------------------------+
bool CheckDayFilter(int dayOfWeek)
{
    switch(dayOfWeek)
    {
        case 0: return TradeSun; // Sunday
        case 1: return TradeMon; // Monday
        case 2: return TradeTue; // Tuesday
        case 3: return TradeWed; // Wednesday
        case 4: return TradeThu; // Thursday
        case 5: return TradeFri; // Friday
        case 6: return TradeSat; // Saturday
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check time range                                                 |
//+------------------------------------------------------------------+
bool CheckTimeRange(int hour, int minute, int startHour, int startMinute, int endHour, int endMinute)
{
    int currentMinutes = hour * 60 + minute;
    int startMinutes = startHour * 60 + startMinute;
    int endMinutes = endHour * 60 + endMinute;
    
    if(startMinutes <= endMinutes)
    {
        return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    }
    else // Overnight session
    {
        return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
}

//+------------------------------------------------------------------+
//| Enhanced daily limits check                                     |
//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
    // Get daily statistics
    double dayTrades = GlobalVariableGet(GV("dayTrades", MagicNumber));
    double dayProfit = GlobalVariableGet(GV("dayProfit", MagicNumber));
    double dayLoss = GlobalVariableGet(GV("dayLoss", MagicNumber));
    
    // Check maximum trades per day
    if(EnableMaxTradesPerDay && dayTrades >= MaxTradesPerDay)
    {
        if(VerboseLogs) Print("Daily trade limit reached: ", (int)dayTrades, "/", MaxTradesPerDay);
        SetEAState(ST_FROZEN, FREEZE_DAILY_LIMIT);
        return false;
    }
    
    // Check daily profit target
    if(EnableProfitCap && (dayProfit - dayLoss) >= DailyProfitTarget)
    {
        if(VerboseLogs) Print("Daily profit target reached: ", DoubleToString(dayProfit - dayLoss, 2));
        SetEAState(ST_FROZEN, FREEZE_DAILY_LIMIT);
        return false;
    }
    
    // Check daily loss limit
    if(EnableLossLimit && (dayProfit - dayLoss) <= -DailyLossLimit)
    {
        if(VerboseLogs) Print("Daily loss limit reached: ", DoubleToString(dayProfit - dayLoss, 2));
        SetEAState(ST_FROZEN, FREEZE_DAILY_LIMIT);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Monitor connection status                                        |
//+------------------------------------------------------------------+
bool MonitorConnection()
{
    datetime currentTime = TimeCurrent();
    
    // Check connection every 30 seconds
    if(currentTime - g_lastConnectionCheck < 30)
        return !g_connectionLost;
        
    g_lastConnectionCheck = currentTime;
    
    // Check terminal connection
    if(!TerminalInfoInteger(TERMINAL_CONNECTED))
    {
        if(!g_connectionLost)
        {
            Print("WARNING: Terminal connection lost!");
            SetEAState(ST_FROZEN, FREEZE_CONNECTION_LOST);
            g_connectionLost = true;
        }
        return false;
    }
    
    // Check if we were disconnected but now reconnected
    if(g_connectionLost)
    {
        Print("Connection restored!");
        SetEAState(ST_READY);
        g_connectionLost = false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate points from money amount                               |
//+------------------------------------------------------------------+
int CalculatePointsFromMoney(double moneyAmount, bool isStopLoss)
{
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickValue > 0 && tickSize > 0)
    {
        double points = (moneyAmount * tickSize) / (tickValue * _Point);
        return (int)NormalizeDouble(points, 0);
    }
    
    return isStopLoss ? (int)PointsSL : (int)PointsTP;
}

//+------------------------------------------------------------------+
//| Initialize trading sessions                                      |
//+------------------------------------------------------------------+
void InitializeSessions()
{
    g_sessions[0].enabled = Session1_Enable;
    g_sessions[0].startHour = Session1_StartHour;
    g_sessions[0].startMinute = Session1_StartMinute;
    g_sessions[0].endHour = Session1_EndHour;
    g_sessions[0].endMinute = Session1_EndMinute;
    g_sessions[0].description = "Session 1";
    
    g_sessions[1].enabled = Session2_Enable;
    g_sessions[1].startHour = Session2_StartHour;
    g_sessions[1].startMinute = Session2_StartMinute;
    g_sessions[1].endHour = Session2_EndHour;
    g_sessions[1].endMinute = Session2_EndMinute;
    g_sessions[1].description = "Session 2";
    
    g_sessions[2].enabled = Session3_Enable;
    g_sessions[2].startHour = Session3_StartHour;
    g_sessions[2].startMinute = Session3_StartMinute;
    g_sessions[2].endHour = Session3_EndHour;
    g_sessions[2].endMinute = Session3_EndMinute;
    g_sessions[2].description = "Session 3";
    
    g_sessions[3].enabled = Session4_Enable;
    g_sessions[3].startHour = Session4_StartHour;
    g_sessions[3].startMinute = Session4_StartMinute;
    g_sessions[3].endHour = Session4_EndHour;
    g_sessions[3].endMinute = Session4_EndMinute;
    g_sessions[3].description = "Session 4";
}

//+------------------------------------------------------------------+
//| Validate input parameters                                       |
//+------------------------------------------------------------------+
bool ValidateInputParameters()
{
    bool valid = true;
    
    if(RiskPct <= 0 || RiskPct > 100)
    {
        Print("ERROR: Invalid risk percentage: ", RiskPct);
        valid = false;
    }
    
    if(FixedLot <= 0)
    {
        Print("ERROR: Invalid fixed lot size: ", FixedLot);
        valid = false;
    }
    
    if(PointsSL <= 0 || PointsTP <= 0)
    {
        Print("ERROR: Invalid SL/TP values. SL: ", PointsSL, " TP: ", PointsTP);
        valid = false;
    }
    
    if(ATRPeriod <= 0 || STMultiplier <= 0)
    {
        Print("ERROR: Invalid SuperTrend parameters. ATR: ", ATRPeriod, " Multiplier: ", STMultiplier);
        valid = false;
    }
    
    return valid;
}

//+------------------------------------------------------------------+
//| Print initialization summary                                     |
//+------------------------------------------------------------------+
void PrintInitializationSummary()
{
    if(!VerboseLogs) return;
    
    Print("═══ EA Configuration Summary ═══");
    Print("Magic Number: ", MagicNumber);
    Print("Symbol: ", _Symbol);
    Print("Indicator Timeframe: ", EnumToString(InpIndTimeframe));
    Print("Position Sizing: ", DynamicLots ? "Dynamic (" + DoubleToString(RiskPct, 1) + "%)" : "Fixed (" + DoubleToString(FixedLot, 2) + " lots)");
    Print("SL/TP: ", PointsSL, "/", PointsTP, " points");
    Print("SuperTrend: ATR=", ATRPeriod, " Multiplier=", STMultiplier);
    Print("VWAP Filter: ", EnableVWAPFilter ? "Enabled" : "Disabled");
    Print("Break-Even: ", EnableBreakEven ? "Enabled (" + DoubleToString(BreakEvenPercent, 1) + "%)" : "Disabled");
    Print("Smart Trailing: ", EnableSmartTrailing ? "Enabled" : "Disabled");
    Print("Daily Limits: Trades=", EnableMaxTradesPerDay ? (string)MaxTradesPerDay : "Unlimited", 
          " Loss=", EnableLossLimit ? DoubleToString(DailyLossLimit, 2) : "Unlimited");
    Print("Time Filter: ", UseTimeFilter ? StringFormat("%02d:%02d-%02d:%02d", BeginHour, BeginMinute, EndHour, EndMinute) : "Disabled");
    Print("FSM Architecture: ENABLED");
    Print("Single Trade Logic: ENABLED");
    Print("═══ Configuration Complete ═══");
}

//+------------------------------------------------------------------+
//| Check and reset daily statistics                                 |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
    datetime currentTime = TimeCurrent();
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);
    
    datetime currentDay = StringToTime(StringFormat("%04d.%02d.%02d", timeStruct.year, timeStruct.mon, timeStruct.day));
    
    if(currentDay != g_lastDayReset)
    {
        if(VerboseLogs && g_lastDayReset != 0)
        {
            Print("═══ End of Trading Day Statistics ═══");
            PrintTradeStatistics();
        }
            
        ResetDailyStatistics();
        g_lastDayReset = currentDay;
        
        if(VerboseLogs)
            Print("═══ New Trading Day Started: ", TimeToString(currentDay, TIME_DATE), " ═══");
    }
}

//+------------------------------------------------------------------+
//| Update performance statistics                                    |
//+------------------------------------------------------------------+
void UpdatePerformanceStatistics()
{
    if(!VerboseLogs) return;
    
    double tickEfficiency = g_totalTicks > 0 ? (double)g_processedTicks / g_totalTicks * 100.0 : 0;
    
    Print("═══ Performance Statistics ═══");
    Print("EA State: ", StateToString(GetEAState()));
    Print("Total Ticks: ", g_totalTicks);
    Print("Processed Ticks: ", g_processedTicks, " (", DoubleToString(tickEfficiency, 2), "%)");
    Print("Active Positions: ", CountActivePositions());
    Print("Memory Usage: ", TerminalInfoInteger(TERMINAL_MEMORY_USED), " MB");
    Print("═══ Performance Update Complete ═══");
}

//+------------------------------------------------------------------+
//| Print performance summary                                        |
//+------------------------------------------------------------------+
void PrintPerformanceSummary()
{
    Print("═══ Final Performance Summary ═══");
    Print("Total Ticks Received: ", g_totalTicks);
    Print("Total Ticks Processed: ", g_processedTicks);
    double efficiency = g_totalTicks > 0 ? (double)g_processedTicks / g_totalTicks * 100.0 : 0;
    Print("Processing Efficiency: ", DoubleToString(efficiency, 2), "%");
    Print("Final EA State: ", StateToString(GetEAState()));
    Print("═══ Performance Summary Complete ═══");
}

//+------------------------------------------------------------------+
//| Get deinitialization reason text                                |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
{
    switch(reason)
    {
        case REASON_PROGRAM: return "EA terminated by user";
        case REASON_REMOVE: return "EA removed from chart";
        case REASON_RECOMPILE: return "EA recompiled";
        case REASON_CHARTCHANGE: return "Chart symbol/period changed";
        case REASON_CHARTCLOSE: return "Chart closed";
        case REASON_PARAMETERS: return "Input parameters changed";
        case REASON_ACCOUNT: return "Account changed";
        case REASON_TEMPLATE: return "Template changed";
        case REASON_INITFAILED: return "Initialization failed";
        case REASON_CLOSE: return "Terminal closed";
        default: return "Unknown reason (" + (string)reason + ")";
    }
}

//+------------------------------------------------------------------+
//| Handle trade transactions                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    // Handle position close events for our magic number
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(HistoryDealSelect(trans.deal))
        {
            if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) == MagicNumber)
            {
                double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
                ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
                
                if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
                {
                    // Position closed - update statistics
                    UpdateTradeStats(profit);
                    
                    // Remove from position tracker
                    ulong ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
                    RemovePositionTracker(ticket);
                    
                    if(VerboseLogs)
                    {
                        Print("═══ Trade Closed ═══");
                        Print("Ticket: ", ticket);
                        Print("Profit: ", DoubleToString(profit, 2));
                        Print("New Balance: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
                        Print("Active Positions: ", CountActivePositions());
                        Print("EA State will change in next tick");
                        Print("═══ Trade Close Complete ═══");
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Periodic position management
    if(EnableBreakEven || EnableSmartTrailing)
    {
        ProcessAdvancedPositionManagement();
    }
    
    // Periodic connection check
    if(EnableConnectionMonitor)
    {
        MonitorConnection();
    }
    
    // Periodic performance update
    if(EnablePerformanceMonitor && TimeCurrent() - g_lastPerformanceUpdate >= StatisticsUpdateInterval)
    {
        UpdatePerformanceStatistics();
        g_lastPerformanceUpdate = TimeCurrent();
    }
}