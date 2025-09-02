//+------------------------------------------------------------------+
//|                                     Enhanced_ST_VWAP_Indicator.mq5 |
//|              Complete Enhanced SuperTrend with VWAP Filter & Advanced Dashboard |
//+------------------------------------------------------------------+
#property copyright "Enhanced SuperTrend with VWAP Filter & Dashboard © 2025"
#property link "https://www.mql5.com"
#property version "5.00"
#property indicator_chart_window
#property indicator_plots 6
#property indicator_buffers 9

#property indicator_type1 DRAW_COLOR_LINE
#property indicator_style1 STYLE_SOLID
#property indicator_width1 3
#property indicator_color1 clrLimeGreen, clrRed

#property indicator_type2 DRAW_LINE
#property indicator_style2 STYLE_SOLID
#property indicator_width2 2
#property indicator_color2 clrGold

#property indicator_type3 DRAW_ARROW
#property indicator_style3 STYLE_SOLID
#property indicator_width3 3
#property indicator_color3 clrDodgerBlue

#property indicator_type4 DRAW_ARROW
#property indicator_style4 STYLE_SOLID
#property indicator_width4 3
#property indicator_color4 clrWhite

#property indicator_type5 DRAW_ARROW
#property indicator_style5 STYLE_SOLID
#property indicator_width5 2
#property indicator_color5 clrGray

#property indicator_type6 DRAW_NONE

//--- Enhanced Input Parameters ---
input group "═══ SuperTrend Settings ═══";
input int ATRPeriod = 22;                    // ATR period for SuperTrend
input double Multiplier = 3.0;               // SuperTrend multiplier
input ENUM_APPLIED_PRICE SourcePrice = PRICE_MEDIAN; // Price for SuperTrend calculation
input bool TakeWicksIntoAccount = true;      // Consider wicks in calculation

input group "═══ VWAP Settings ═══";
input ENUM_APPLIED_PRICE VWAPPriceMethod = PRICE_TYPICAL; // VWAP calculation price
input double MinVolumeThreshold = 1.0;       // Minimum volume for VWAP
input bool ResetVWAPDaily = true;            // Reset VWAP daily
input int VWAPLookbackPeriod = 100;         // VWAP calculation lookback

input group "═══ VWAP Filter Settings ═══";
input bool EnableVWAPFilter = true;          // Enable VWAP filtering
input bool ShowVWAPLine = true;              // Show VWAP line on chart
input double MinPointsFromVWAP = 0.0;        // Minimum distance from VWAP in points

input group "═══ Time Window Settings ═══";
input bool EnableTimeWindow = false;         // Enable time window filtering
input int StartHour = 9;                     // Trading start hour
input int StartMinute = 30;                  // Trading start minute
input int EndHour = 16;                      // Trading end hour
input int EndMinute = 0;                     // Trading end minute
enum TimeWindowMode
{
    MODE_DASHBOARD_ONLY = 0,                 // Dashboard only
    MODE_SIGNALS_ONLY = 1,                   // Signals only
    MODE_BOTH = 2                            // Both dashboard and signals
};
input TimeWindowMode WindowMode = MODE_DASHBOARD_ONLY;

input group "═══ Performance Settings ═══";
input bool EnableWinRate = true;             // Enable win rate calculation
input double WinThresholdPoints = 10.0;      // Target threshold in points for win condition
input int SignalLifetimeBars = 200;         // Signal arrow lifetime in bars
input bool EnableAdvancedStats = true;       // Enable advanced statistics

input group "═══ Enhanced Dashboard Settings ═══";
input bool ShowDashboard = true;             // Show dashboard
input int DashboardX = 20;                   // Dashboard X position
input int DashboardY = 30;                   // Dashboard Y position
input int DashboardWidth = 420;              // Dashboard width
input int DashboardHeight = 500;             // Dashboard height
input color DashboardBackColor = C'25,25,25'; // Dashboard background color
input color DashboardBorderColor = clrGray;  // Dashboard border color
input color DashboardTextColor = clrWhite;   // Dashboard text color

input group "═══ Column Layout Settings ═══";
input int LabelXOffset = 10;                 // Label column X position
input int LabelFontSize = 9;                 // Label font size
input int ValueXOffset = 260;                // Value column X position  
input int ValueFontSize = 9;                 // Value font size
input string DashboardFont = "Consolas";     // Dashboard font

input group "═══ Visual Feedback Settings ═══";
input bool EnableVisualFeedback = true;      // Enable visual signal feedback
input int CircleWidth = 3;                   // Signal circle width
input color RejectionColor = clrGray;        // Rejected signal color
input color BullishAcceptColor = clrDodgerBlue; // Bullish accepted signal color
input color BearishAcceptColor = clrWhite;   // Bearish accepted signal color

input group "═══ Advanced Settings ═══";
input bool ShowDebugInfo = false;            // Show debug information
input int MaxObjectsOnChart = 500;           // Maximum objects on chart
input bool ShowTooltips = true;              // Show signal tooltips
input int ObjectCleanupThreshold = 250;      // Object cleanup threshold
input bool OptimizeCalculations = true;      // Optimize calculations for performance

input group "═══ Alert Settings ═══";
input bool EnableAlerts = false;             // Enable alerts
input bool AlertSound = true;                // Alert sound
input bool AlertPopup = true;                // Alert popup
input string AlertSoundFile = "alert.wav";   // Alert sound file

//--- Enhanced Indicator Buffers ---
double STBuffer[];                           // SuperTrend line
double STColorBuffer[];                      // SuperTrend color indexes
double VWAPBuffer[];                         // VWAP values
double BuyArrowBuffer[];                     // Accepted buy arrows
double SellArrowBuffer[];                    // Accepted sell arrows
double RejectArrowBuffer[];                  // Rejected arrows
double SignalBuffer[];                       // Signal buffer for EA
double TrendBuffer[];                        // Trend direction buffer
double StrengthBuffer[];                     // Signal strength buffer

//--- Enhanced Global Variables ---
int atrHandle;                               // ATR indicator handle
datetime g_currentDay = 0;                  // Current day for VWAP reset
double g_sumPV = 0.0;                       // Price * Volume sum
double g_sumV = 0.0;                        // Volume sum

// Enhanced Signal Statistics
struct SignalStats
{
   int totalSignals;
   int acceptedSignals; 
   int rejectedSignals;
   int bullishSignals;
   int bearishSignals;
   int bullishAccepted;
   int bearishAccepted;
   int bullishRejected;
   int bearishRejected;
   
   // Performance tracking
   double totalPoints;
   double winningPoints;
   double losingPoints;
   int winningSignals;
   int losingSignals;
   double averageWin;
   double averageLoss;
   double winRate;
   double profitFactor;
   
   // Recent performance
   double last10SignalsPoints;
   int last10Index;
   double last10Array[10];
   
   SignalStats() 
   {
      totalSignals = acceptedSignals = rejectedSignals = 0;
      bullishSignals = bearishSignals = bullishAccepted = bearishAccepted = 0;
      bullishRejected = bearishRejected = 0;
      totalPoints = winningPoints = losingPoints = 0;
      winningSignals = losingSignals = 0;
      averageWin = averageLoss = winRate = profitFactor = 0;
      last10SignalsPoints = 0;
      last10Index = 0;
      ArrayInitialize(last10Array, 0);
   }
};

SignalStats g_signalStats;

// Market condition tracking
struct MarketCondition
{
   double volatility;
   double trendStrength;
   bool isHighVolatility;
   bool isStrongTrend;
   string marketPhase;
   double efficiency;
   
   MarketCondition()
   {
      volatility = trendStrength = efficiency = 0;
      isHighVolatility = isStrongTrend = false;
      marketPhase = "Neutral";
   }
};

MarketCondition g_marketCondition;

// Performance optimization variables
static int g_lastCalculatedBar = -1;
static datetime g_lastDashboardUpdate = 0;
const int DASHBOARD_UPDATE_INTERVAL = 1; // seconds

// Object management
string g_objectPrefix = "STVWAP_";

//+------------------------------------------------------------------+
//| Enhanced Custom indicator initialization                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize ATR handle
   atrHandle = iATR(NULL, 0, ATRPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator handle");
      return(INIT_FAILED);
   }

   // Set indicator buffers
   SetIndexBuffer(0, STBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, STColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, VWAPBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, BuyArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, SellArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, RejectArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, SignalBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, TrendBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, StrengthBuffer, INDICATOR_CALCULATIONS);

   // Set plot properties
   PlotIndexSetInteger(3, PLOT_ARROW, 233);  // Up arrow for buy signals
   PlotIndexSetInteger(4, PLOT_ARROW, 234);  // Down arrow for sell signals
   PlotIndexSetInteger(5, PLOT_ARROW, 159);  // Dot for rejected signals
   if(!ShowVWAPLine)
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);

   // Set array directions to time series (0 = current bar)
   ArraySetAsSeries(STBuffer, true);
   ArraySetAsSeries(STColorBuffer, true);
   ArraySetAsSeries(VWAPBuffer, true);
   ArraySetAsSeries(BuyArrowBuffer, true);
   ArraySetAsSeries(SellArrowBuffer, true);
   ArraySetAsSeries(RejectArrowBuffer, true);
   ArraySetAsSeries(SignalBuffer, true);
   ArraySetAsSeries(TrendBuffer, true);
   ArraySetAsSeries(StrengthBuffer, true);

   // Set indicator properties
   IndicatorSetString(INDICATOR_SHORTNAME, "Enhanced ST&VWAP v5.0");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   // Initialize dashboard
   if(ShowDashboard)
      CreateDashboard();

   Print("Enhanced ST&VWAP Indicator v5.0 initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Enhanced Custom indicator deinitialization                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release ATR handle
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);

   // Clean up dashboard objects
   CleanupDashboard();
   
   // Clean up signal objects
   CleanupSignalObjects();

   Print("Enhanced ST&VWAP Indicator deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Enhanced Custom indicator iteration                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total <= ATRPeriod)
      return(0);

   int start = (prev_calculated == 0) ? rates_total - 1 : rates_total - prev_calculated;

   // Performance optimization: skip if same bar already calculated
   if(OptimizeCalculations && start == g_lastCalculatedBar && prev_calculated > 0)
      return(rates_total);

   double atr[];
   ArraySetAsSeries(atr, true);

   // Main calculation loop using time series indexing
   for(int shift = start; shift >= 0; --shift)
   {
      // Initialize buffers
      BuyArrowBuffer[shift] = EMPTY_VALUE;
      SellArrowBuffer[shift] = EMPTY_VALUE;
      RejectArrowBuffer[shift] = EMPTY_VALUE;
      SignalBuffer[shift] = 0.0;
      TrendBuffer[shift] = 0.0;
      StrengthBuffer[shift] = 0.0;

      // Enhanced VWAP calculation with lookback period
      CalculateEnhancedVWAP(shift, rates_total, time, high, low, close, tick_volume);

      // Get ATR value
      if(CopyBuffer(atrHandle, 0, shift, 1, atr) <= 0)
         atr[0] = close[shift] * 0.001; // Fallback value

      double atrValue = atr[0];
      if(atrValue <= 0)
         atrValue = close[shift] * 0.001; // 0.1% fallback

      // Enhanced SuperTrend calculation
      CalculateEnhancedSuperTrend(shift, rates_total, high, low, close, open, atrValue);

      // Enhanced signal processing with market condition analysis
      ProcessEnhancedSignals(shift, time, high, low, close);
   }

   // Update market condition analysis using latest bar
   if(rates_total > ATRPeriod + 20)
      UpdateMarketCondition(0, high, low, close);

   // Update dashboard
   if(ShowDashboard && rates_total > 0)
      UpdateDashboard(0);

   // Clean up old signal objects periodically
   static int cleanupCounter = 0;
   if(++cleanupCounter >= ObjectCleanupThreshold)
   {
      CleanupOldSignalObjects();
      cleanupCounter = 0;
   }

   g_lastCalculatedBar = start;
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Enhanced VWAP calculation with lookback period                  |
//+------------------------------------------------------------------+
void CalculateEnhancedVWAP(int shift, int rates_total, const datetime &time[],
                          const double &high[], const double &low[], const double &close[], const long &tick_volume[])
{
   MqlDateTime t;
   TimeToStruct(time[shift], t);
   datetime day = StringToTime(StringFormat("%04d.%02d.%02d", t.year, t.mon, t.day));
   
   // Reset VWAP daily or use lookback period
   if(ResetVWAPDaily && day != g_currentDay)
   {
      g_currentDay = day;
      g_sumPV = 0.0;
      g_sumV = 0.0;
   }
   else if(!ResetVWAPDaily)
   {
      int endShift = shift + VWAPLookbackPeriod - 1;
      if(endShift < rates_total)
      {
         double sumPV = 0.0;
         double sumV = 0.0;

         for(int j = endShift; j >= shift; --j)
         {
            double price = GetVWAPPrice(j, high, low, close);
            double vol = (double)tick_volume[j];
            if(vol < MinVolumeThreshold) vol = MinVolumeThreshold;

            sumPV += price * vol;
            sumV += vol;
         }

         VWAPBuffer[shift] = sumV > 0 ? sumPV / sumV : close[shift];
         return;
      }
   }

   // Standard VWAP calculation
   double price = GetVWAPPrice(shift, high, low, close);
   double vol = (double)tick_volume[shift];
   if(vol < MinVolumeThreshold) vol = MinVolumeThreshold;
   
   g_sumPV += price * vol;
   g_sumV += vol;
   VWAPBuffer[shift] = g_sumV > 0 ? g_sumPV / g_sumV : price;
}

//+------------------------------------------------------------------+
//| Get VWAP price based on price method                            |
//+------------------------------------------------------------------+
double GetVWAPPrice(int shift, const double &high[], const double &low[], const double &close[])
{
   switch(VWAPPriceMethod)
   {
      case PRICE_CLOSE: return close[shift];
      case PRICE_HIGH: return high[shift];
      case PRICE_LOW: return low[shift];
      case PRICE_MEDIAN: return (high[shift] + low[shift]) / 2.0;
      case PRICE_TYPICAL: return (high[shift] + low[shift] + close[shift]) / 3.0;
      case PRICE_WEIGHTED: return (high[shift] + low[shift] + close[shift] + close[shift]) / 4.0;
      default: return (high[shift] + low[shift] + close[shift]) / 3.0;
   }
}

//+------------------------------------------------------------------+
//| Enhanced SuperTrend calculation                                 |
//+------------------------------------------------------------------+
void CalculateEnhancedSuperTrend(int shift, int rates_total, const double &high[], const double &low[],
                                const double &close[], const double &open[], double atrValue)
{
   // Get source price
   double src = GetSourcePrice(shift, high, low, close, open);

   // Consider wicks or body only
   double highPrice = TakeWicksIntoAccount ? high[shift] : MathMax(open[shift], close[shift]);
   double lowPrice = TakeWicksIntoAccount ? low[shift] : MathMin(open[shift], close[shift]);

   // Calculate SuperTrend levels
   double longStop = src - Multiplier * atrValue;
   double shortStop = src + Multiplier * atrValue;

   int direction = 1; // Default bullish

   if(shift + 1 < rates_total)
   {
      double prevST = STBuffer[shift + 1];
      int prevDir = (int)STColorBuffer[shift + 1] == 0 ? 1 : -1;

      // Adjust stops based on previous values
      longStop = prevDir == 1 ? MathMax(longStop, prevST) : longStop;
      shortStop = prevDir == -1 ? MathMin(shortStop, prevST) : shortStop;

      // Determine direction change
      if(prevDir == 1)
         direction = (lowPrice < prevST) ? -1 : 1;
      else
         direction = (highPrice > prevST) ? 1 : -1;
   }

   // Set SuperTrend values
   STBuffer[shift] = (direction == 1) ? longStop : shortStop;
   STColorBuffer[shift] = (direction == 1) ? 0 : 1;
   TrendBuffer[shift] = direction;

   // Calculate trend strength
   if(shift + 10 < rates_total)
   {
      double priceChange = MathAbs(close[shift] - close[shift + 10]);
      double atrAvg = 0;
      for(int j = 0; j < 10; j++)
      {
         double tempATR[];
         if(CopyBuffer(atrHandle, 0, shift + j, 1, tempATR) > 0)
            atrAvg += tempATR[0];
      }
      atrAvg /= 10.0;
      StrengthBuffer[shift] = atrAvg > 0 ? priceChange / atrAvg : 0;
   }
}

//+------------------------------------------------------------------+
//| Get source price based on price method                          |
//+------------------------------------------------------------------+
double GetSourcePrice(int shift, const double &high[], const double &low[],
                     const double &close[], const double &open[])
{
   switch(SourcePrice)
   {
      case PRICE_CLOSE: return close[shift];
      case PRICE_OPEN: return open[shift];
      case PRICE_HIGH: return high[shift];
      case PRICE_LOW: return low[shift];
      case PRICE_MEDIAN: return (high[shift] + low[shift]) / 2.0;
      case PRICE_TYPICAL: return (high[shift] + low[shift] + close[shift]) / 3.0;
      case PRICE_WEIGHTED: return (high[shift] + low[shift] + close[shift] + close[shift]) / 4.0;
      default: return (high[shift] + low[shift]) / 2.0;
   }
}

//+------------------------------------------------------------------+
//| Enhanced signal processing with market condition analysis       |
//+------------------------------------------------------------------+
void ProcessEnhancedSignals(int shift, const datetime &time[], const double &high[],
                           const double &low[], const double &close[])
{
   if(shift + 1 >= Bars(_Symbol, PERIOD_CURRENT)) return;

   double prevST = STBuffer[shift + 1];
   int prevDir = (int)STColorBuffer[shift + 1] == 0 ? 1 : -1;
   int currentDir = (int)STColorBuffer[shift] == 0 ? 1 : -1;

   // Check for direction change (signal generation)
   if(currentDir != prevDir)
   {
      bool vwapOK = true;
      bool timeOK = true;

      // VWAP filter validation
      if(EnableVWAPFilter)
      {
         double distPoints = MathAbs(close[shift] - VWAPBuffer[shift]) / _Point;
         if(currentDir == 1)
            vwapOK = close[shift] > VWAPBuffer[shift] && distPoints >= MinPointsFromVWAP;
         else
            vwapOK = close[shift] < VWAPBuffer[shift] && distPoints >= MinPointsFromVWAP;
      }

      // Time window validation
      if(EnableTimeWindow && (WindowMode == MODE_SIGNALS_ONLY || WindowMode == MODE_BOTH))
         timeOK = IsInTimeWindow(time[shift]);

      // Market condition validation
      bool marketOK = IsMarketConditionFavorable(shift);

      // Update signal statistics
      g_signalStats.totalSignals++;

      if(vwapOK && timeOK && marketOK)
      {
         g_signalStats.acceptedSignals++;

         if(currentDir == 1)
         {
            g_signalStats.bullishSignals++;
            g_signalStats.bullishAccepted++;
            BuyArrowBuffer[shift] = low[shift] - 2 * _Point;
            SignalBuffer[shift] = 1.0;
            if(EnableVisualFeedback)
               CreateSignalObject(shift, time[shift], BuyArrowBuffer[shift], "BUY", BullishAcceptColor);
         }
         else
         {
            g_signalStats.bearishSignals++;
            g_signalStats.bearishAccepted++;
            SellArrowBuffer[shift] = high[shift] + 2 * _Point;
            SignalBuffer[shift] = -1.0;
            if(EnableVisualFeedback)
               CreateSignalObject(shift, time[shift], SellArrowBuffer[shift], "SELL", BearishAcceptColor);
         }

         if(EnableAlerts)
         {
            string alertMsg = StringFormat("ST&VWAP %s Signal at %.5f",
                                         currentDir == 1 ? "BUY" : "SELL", close[shift]);
            if(AlertPopup) Alert(alertMsg);
            if(AlertSound) PlaySound(AlertSoundFile);
         }
      }
      else
      {
         g_signalStats.rejectedSignals++;

         if(currentDir == 1)
         {
            g_signalStats.bullishSignals++;
            g_signalStats.bullishRejected++;
         }
         else
         {
            g_signalStats.bearishSignals++;
            g_signalStats.bearishRejected++;
         }

         RejectArrowBuffer[shift] = currentDir == 1 ? low[shift] - _Point : high[shift] + _Point;
         if(EnableVisualFeedback)
            CreateSignalObject(shift, time[shift], RejectArrowBuffer[shift], "REJECTED", RejectionColor);
      }

      if(EnableWinRate && EnableAdvancedStats)
         UpdatePerformanceStats(shift, currentDir, close);
   }
}

//+------------------------------------------------------------------+
//| Check if current time is within trading window                  |
//+------------------------------------------------------------------+
bool IsInTimeWindow(datetime time)
{
   MqlDateTime t;
   TimeToStruct(time, t);
   
   int currentMinutes = t.hour * 60 + t.min;
   int startMinutes = StartHour * 60 + StartMinute;
   int endMinutes = EndHour * 60 + EndMinute;
   
   if(startMinutes <= endMinutes)
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
   else // Overnight session
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
}

//+------------------------------------------------------------------+
//| Check if market condition is favorable for trading              |
//+------------------------------------------------------------------+
bool IsMarketConditionFavorable(int shift)
{
   // Basic market condition checks
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   // Check spread
   if(spread > 10) // 10 points max spread
      return false;
   
   // Check volatility using trend strength
   if(StrengthBuffer[shift] < 0.5) // Low volatility threshold
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Update market condition analysis                                |
//+------------------------------------------------------------------+
void UpdateMarketCondition(int shift, const double &high[], const double &low[], const double &close[])
{
   if(shift + 20 >= Bars(_Symbol, PERIOD_CURRENT)) return;

   // Calculate volatility (ATR-based)
   double atr[];
   if(CopyBuffer(atrHandle, 0, shift + 19, 20, atr) == 20)
   {
      double avgATR = 0;
      for(int i = 0; i < 20; i++)
         avgATR += atr[i];
      avgATR /= 20.0;

      g_marketCondition.volatility = avgATR;
      g_marketCondition.isHighVolatility = avgATR > (close[shift] * 0.001); // 0.1% threshold
   }

   // Calculate trend strength
   double priceChange = MathAbs(close[shift] - close[shift + 10]);
   double range = 0;
   for(int i = shift + 9; i >= shift; --i)
      range += high[i] - low[i];
   range /= 10.0;

   g_marketCondition.trendStrength = range > 0 ? priceChange / range : 0;
   g_marketCondition.isStrongTrend = g_marketCondition.trendStrength > 0.7;

   // Determine market phase
   if(g_marketCondition.isHighVolatility && g_marketCondition.isStrongTrend)
      g_marketCondition.marketPhase = "Trending";
   else if(g_marketCondition.isHighVolatility)
      g_marketCondition.marketPhase = "Volatile";
   else if(g_marketCondition.isStrongTrend)
      g_marketCondition.marketPhase = "Quiet Trend";
   else
      g_marketCondition.marketPhase = "Consolidation";

   // Calculate efficiency
   double directionalMovement = MathAbs(close[shift] - close[shift + 20]);
   double totalMovement = 0;
   for(int i = shift + 19; i >= shift; --i)
      totalMovement += MathAbs(close[i] - close[i + 1]);

   g_marketCondition.efficiency = totalMovement > 0 ? directionalMovement / totalMovement : 0;
}

//+------------------------------------------------------------------+
//| Update performance statistics                                   |
//+------------------------------------------------------------------+
void UpdatePerformanceStats(int index, int direction, const double &close[])
{
   // This is a simplified performance tracking
   // In real trading, this would track actual trade results
   
   static int lastSignalIndex = -1;
   static int lastDirection = 0;
   
   if(lastSignalIndex >= 0 && lastDirection != 0)
   {
      // Calculate hypothetical profit/loss
      double points = 0;
      if(lastDirection == 1) // Previous was buy
         points = (close[index] - close[lastSignalIndex]) / _Point;
      else // Previous was sell
         points = (close[lastSignalIndex] - close[index]) / _Point;
      
      // Update statistics
      if(points >= WinThresholdPoints)
      {
         g_signalStats.winningSignals++;
         g_signalStats.winningPoints += points;
      }
      else
      {
         g_signalStats.losingSignals++;
         g_signalStats.losingPoints += MathAbs(points);
      }
      
      g_signalStats.totalPoints += points;
      
      // Update last 10 signals tracking
      g_signalStats.last10Array[g_signalStats.last10Index] = points;
      g_signalStats.last10Index = (g_signalStats.last10Index + 1) % 10;
      
      // Calculate last 10 performance
      g_signalStats.last10SignalsPoints = 0;
      for(int i = 0; i < 10; i++)
         g_signalStats.last10SignalsPoints += g_signalStats.last10Array[i];
      
      // Update derived statistics
      if(g_signalStats.winningSignals + g_signalStats.losingSignals > 0)
      {
         g_signalStats.winRate = (double)g_signalStats.winningSignals / 
                                (g_signalStats.winningSignals + g_signalStats.losingSignals) * 100.0;
      }
      
      if(g_signalStats.winningSignals > 0)
         g_signalStats.averageWin = g_signalStats.winningPoints / g_signalStats.winningSignals;
         
      if(g_signalStats.losingSignals > 0)
         g_signalStats.averageLoss = g_signalStats.losingPoints / g_signalStats.losingSignals;
         
      if(g_signalStats.losingPoints > 0)
         g_signalStats.profitFactor = g_signalStats.winningPoints / g_signalStats.losingPoints;
   }
   
   lastSignalIndex = index;
   lastDirection = direction;
}

//+------------------------------------------------------------------+
//| Create enhanced dashboard                                        |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   // Create dashboard background
   string bgName = g_objectPrefix + "Dashboard_BG";
   if(ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, DashboardX);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, DashboardY);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, DashboardWidth);
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, DashboardHeight);
      ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, DashboardBackColor);
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, DashboardBorderColor);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Update enhanced dashboard                                        |
//+------------------------------------------------------------------+
void UpdateDashboard(int lastBar)
{
   if(!ShowDashboard || TimeCurrent() - g_lastDashboardUpdate < DASHBOARD_UPDATE_INTERVAL)
      return;
   
   g_lastDashboardUpdate = TimeCurrent();
   
   // Create dashboard text elements
   string lines[];
   ArrayResize(lines, 0);
   
   // Header
   AddDashboardLine(lines, "═══ Enhanced ST&VWAP v5.0 ═══");
   AddDashboardLine(lines, "");
   
   // Current market data
   AddDashboardLine(lines, "═══ Market Data ═══");
   AddDashboardLine(lines, StringFormat("Price: %.5f", SymbolInfoDouble(_Symbol, SYMBOL_BID)));
   AddDashboardLine(lines, StringFormat("SuperTrend: %.5f", STBuffer[lastBar]));
   AddDashboardLine(lines, StringFormat("VWAP: %.5f", VWAPBuffer[lastBar]));
   AddDashboardLine(lines, StringFormat("Trend: %s", TrendBuffer[lastBar] > 0 ? "BULLISH" : "BEARISH"));
   AddDashboardLine(lines, StringFormat("Spread: %.1f pts", (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));
   AddDashboardLine(lines, "");
   
   // Signal statistics
   AddDashboardLine(lines, "═══ Signal Statistics ═══");
   AddDashboardLine(lines, StringFormat("Total Signals: %d", g_signalStats.totalSignals));
   AddDashboardLine(lines, StringFormat("Accepted: %d (%.1f%%)", g_signalStats.acceptedSignals, 
                    g_signalStats.totalSignals > 0 ? (double)g_signalStats.acceptedSignals / g_signalStats.totalSignals * 100 : 0));
   AddDashboardLine(lines, StringFormat("Rejected: %d (%.1f%%)", g_signalStats.rejectedSignals,
                    g_signalStats.totalSignals > 0 ? (double)g_signalStats.rejectedSignals / g_signalStats.totalSignals * 100 : 0));
   AddDashboardLine(lines, StringFormat("Bullish: %d (%d/%d)", g_signalStats.bullishSignals, 
                    g_signalStats.bullishAccepted, g_signalStats.bullishRejected));
   AddDashboardLine(lines, StringFormat("Bearish: %d (%d/%d)", g_signalStats.bearishSignals,
                    g_signalStats.bearishAccepted, g_signalStats.bearishRejected));
   AddDashboardLine(lines, "");
   
   // Performance metrics (if enabled)
   if(EnableAdvancedStats)
   {
      AddDashboardLine(lines, "═══ Performance Metrics ═══");
      AddDashboardLine(lines, StringFormat("Win Rate: %.1f%%", g_signalStats.winRate));
      AddDashboardLine(lines, StringFormat("Profit Factor: %.2f", g_signalStats.profitFactor));
      AddDashboardLine(lines, StringFormat("Avg Win: %.1f pts", g_signalStats.averageWin));
      AddDashboardLine(lines, StringFormat("Avg Loss: %.1f pts", g_signalStats.averageLoss));
      AddDashboardLine(lines, StringFormat("Total Points: %.1f", g_signalStats.totalPoints));
      AddDashboardLine(lines, StringFormat("Last 10 Signals: %.1f pts", g_signalStats.last10SignalsPoints));
      AddDashboardLine(lines, "");
   }
   
   // Market condition
   AddDashboardLine(lines, "═══ Market Condition ═══");
   AddDashboardLine(lines, StringFormat("Phase: %s", g_marketCondition.marketPhase));
   AddDashboardLine(lines, StringFormat("Volatility: %s", g_marketCondition.isHighVolatility ? "HIGH" : "NORMAL"));
   AddDashboardLine(lines, StringFormat("Trend Strength: %.2f", g_marketCondition.trendStrength));
   AddDashboardLine(lines, StringFormat("Efficiency: %.2f", g_marketCondition.efficiency));
   AddDashboardLine(lines, "");
   
   // Time window info
   if(EnableTimeWindow)
   {
      AddDashboardLine(lines, "═══ Time Window ═══");
      bool inWindow = IsInTimeWindow(TimeCurrent());
      AddDashboardLine(lines, StringFormat("Status: %s", inWindow ? "ACTIVE" : "INACTIVE"));
      AddDashboardLine(lines, StringFormat("Window: %02d:%02d - %02d:%02d", 
                       StartHour, StartMinute, EndHour, EndMinute));
      AddDashboardLine(lines, "");
   }
   
   // System info
   AddDashboardLine(lines, "═══ System Info ═══");
   AddDashboardLine(lines, StringFormat("Last Update: %s", TimeToString(TimeCurrent(), TIME_MINUTES)));
   AddDashboardLine(lines, StringFormat("Bars Processed: %d", lastBar + 1));
   AddDashboardLine(lines, StringFormat("Objects: %d", ObjectsTotal(0, -1, -1)));
   
   // Display all lines
   DisplayDashboardLines(lines);
}

//+------------------------------------------------------------------+
//| Add line to dashboard                                            |
//+------------------------------------------------------------------+
void AddDashboardLine(string &lines[], string text)
{
   int size = ArraySize(lines);
   ArrayResize(lines, size + 1);
   lines[size] = text;
}

//+------------------------------------------------------------------+
//| Display dashboard lines                                          |
//+------------------------------------------------------------------+
void DisplayDashboardLines(const string &lines[])
{
   for(int i = 0; i < ArraySize(lines); i++)
   {
      string objName = g_objectPrefix + "Line_" + (string)i;
      
      if(ObjectFind(0, objName) < 0)
         ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, DashboardX + LabelXOffset);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, DashboardY + 25 + (i * 16));
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetString(0, objName, OBJPROP_TEXT, lines[i]);
      ObjectSetString(0, objName, OBJPROP_FONT, DashboardFont);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, LabelFontSize);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, DashboardTextColor);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Create signal object with tooltip                               |
//+------------------------------------------------------------------+
void CreateSignalObject(int barIndex, datetime time, double price, string signalType, color signalColor)
{
   static int signalCount = 0;
   signalCount++;

   string objName = g_objectPrefix + "Signal_" + IntegerToString(signalCount);

   if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, price))
   {
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, (signalType=="BUY") ? 233 : (signalType=="SELL" ? 234 : 159));
      ObjectSetInteger(0, objName, OBJPROP_COLOR, signalColor);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, CircleWidth);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);

      if(ShowTooltips)
      {
         string tooltip = StringFormat("%s Signal\nTime: %s\nPrice: %.5f\nST: %.5f\nVWAP: %.5f",
                                       signalType, TimeToString(time), price,
                                       STBuffer[barIndex], VWAPBuffer[barIndex]);
         ObjectSetString(0, objName, OBJPROP_TOOLTIP, tooltip);
      }
   }
}

//+------------------------------------------------------------------+
//| Clean up old signal objects                                     |
//+------------------------------------------------------------------+
void CleanupOldSignalObjects()
{
   datetime cutoffTime = TimeCurrent() - SignalLifetimeBars * PeriodSeconds(PERIOD_CURRENT);
   
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, -1);
      if(StringFind(objName, g_objectPrefix + "Signal_") == 0)
      {
         datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
         if(objTime < cutoffTime)
            ObjectDelete(0, objName);
      }
   }
}

//+------------------------------------------------------------------+
//| Clean up all signal objects                                     |
//+------------------------------------------------------------------+
void CleanupSignalObjects()
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, -1);
      if(StringFind(objName, g_objectPrefix + "Signal_") == 0)
         ObjectDelete(0, objName);
   }
}

//+------------------------------------------------------------------+
//| Clean up dashboard                                              |
//+------------------------------------------------------------------+
void CleanupDashboard()
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, -1);
      if(StringFind(objName, g_objectPrefix) == 0)
         ObjectDelete(0, objName);
   }
   
   Comment(""); // Clear comment area
}