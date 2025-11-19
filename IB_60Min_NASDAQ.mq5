//+------------------------------------------------------------------+
//|                                           IB_60Min_NASDAQ.mq5    |
//|                                 Inside Bar 60-Minute Strategy    |
//|                                       For NASDAQ Trading          |
//+------------------------------------------------------------------+
#property copyright "Stargerty Trading System"
#property link      ""
#property version   "1.00"
#property description "Inside Bar breakout strategy for 60-minute timeframe"
#property description "Optimized for NASDAQ index trading"

//--- Input Parameters
input group "=== Trading Settings ==="
input double   RiskPercent = 1.0;                  // Risk per trade (%)
input int      MagicNumber = 60001;                // Magic number for orders
input string   TradeComment = "IB-60Min-NASDAQ";   // Order comment

input group "=== Inside Bar Settings ==="
input int      LookbackBars = 1;                   // Bars to look back for IB pattern
input bool     StrictIB = true;                    // Strict IB (high/low fully inside)
input int      MinIBSizePips = 10;                 // Minimum IB size in pips
input int      MaxIBSizePips = 500;                // Maximum IB size in pips

input group "=== Entry Settings ==="
input double   BreakoutBuffer = 5.0;               // Breakout buffer in pips
input bool     TradeOnClose = true;                // Enter on bar close only
input bool     AllowLongTrades = true;             // Allow long trades
input bool     AllowShortTrades = true;            // Allow short trades

input group "=== Exit Settings ==="
input double   StopLossMultiplier = 1.0;           // SL = IB range * multiplier
input double   TakeProfitMultiplier = 2.0;         // TP = IB range * multiplier
input bool     UseTrailingStop = true;             // Use trailing stop
input double   TrailingStopPips = 30;              // Trailing stop distance (pips)
input double   TrailingStepPips = 10;              // Trailing step (pips)

input group "=== Time Filter ==="
input bool     UseTimeFilter = false;              // Enable time filter
input int      StartHour = 9;                      // Trading start hour (broker time)
input int      EndHour = 16;                       // Trading end hour (broker time)

input group "=== Money Management ==="
input double   MaxSpreadPips = 10.0;               // Maximum spread allowed (pips)
input int      MaxDailyTrades = 3;                 // Maximum trades per day
input double   MaxDailyLossPct = 3.0;              // Max daily loss % (stop trading)

//--- Global Variables
datetime lastBarTime = 0;
int dailyTradeCount = 0;
double dailyPnL = 0.0;
datetime currentDay = 0;
bool insideBarDetected = false;
double insideBarHigh = 0.0;
double insideBarLow = 0.0;
datetime insideBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== IB 60-Minute NASDAQ Strategy Initialized ===");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   Print("Risk per trade: ", RiskPercent, "%");
   Print("Magic Number: ", MagicNumber);

   // Verify we're on 60-minute timeframe
   if(_Period != PERIOD_H1)
   {
      Alert("Warning: This EA is designed for H1 (60-minute) timeframe!");
      Print("Current timeframe: ", EnumToString(_Period));
   }

   // Initialize tracking variables
   lastBarTime = iTime(_Symbol, _Period, 0);
   ResetDailyCounters();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== IB 60-Minute NASDAQ Strategy Stopped ===");
   Print("Reason: ", getUninitReasonText(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   if(!IsNewBar()) return;

   // Reset daily counters if new day
   CheckNewDay();

   // Check daily limits
   if(dailyTradeCount >= MaxDailyTrades)
   {
      Comment("Daily trade limit reached (", dailyTradeCount, "/", MaxDailyTrades, ")");
      return;
   }

   if(dailyPnL <= -MaxDailyLossPct * AccountInfoDouble(ACCOUNT_BALANCE) / 100.0)
   {
      Comment("Daily loss limit reached. Stopping trading.");
      return;
   }

   // Check time filter
   if(UseTimeFilter && !IsWithinTradingHours())
   {
      return;
   }

   // Check spread
   if(!IsSpreadAcceptable())
   {
      Comment("Spread too high: ", GetCurrentSpreadPips(), " pips");
      return;
   }

   // Manage existing positions
   ManagePositions();

   // Check if we already have an open position
   if(CountOpenPositions() > 0)
   {
      return;
   }

   // Detect Inside Bar pattern
   DetectInsideBar();

   // Check for entry signals
   if(insideBarDetected)
   {
      CheckEntrySignals();
   }

   // Update comment
   UpdateComment();
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                        |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if new trading day                                           |
//+------------------------------------------------------------------+
void CheckNewDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   datetime today = StringToTime(IntegerToString(dt.year) + "." +
                                  IntegerToString(dt.mon) + "." +
                                  IntegerToString(dt.day));

   if(today != currentDay)
   {
      currentDay = today;
      ResetDailyCounters();
   }
}

//+------------------------------------------------------------------+
//| Reset daily counters                                               |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
   dailyTradeCount = 0;
   dailyPnL = 0.0;
   Print("Daily counters reset");
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                      |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   return (dt.hour >= StartHour && dt.hour < EndHour);
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                      |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable()
{
   double spreadPips = GetCurrentSpreadPips();
   return (spreadPips <= MaxSpreadPips);
}

//+------------------------------------------------------------------+
//| Get current spread in pips                                         |
//+------------------------------------------------------------------+
double GetCurrentSpreadPips()
{
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return spread / 10.0; // Convert to pips
}

//+------------------------------------------------------------------+
//| Detect Inside Bar pattern                                          |
//+------------------------------------------------------------------+
void DetectInsideBar()
{
   // Get current bar and mother bar data
   int motherBarIndex = LookbackBars + 1;
   int insideBarIndex = LookbackBars;

   double motherHigh = iHigh(_Symbol, _Period, motherBarIndex);
   double motherLow = iLow(_Symbol, _Period, motherBarIndex);
   double motherRange = motherHigh - motherLow;

   double ibHigh = iHigh(_Symbol, _Period, insideBarIndex);
   double ibLow = iLow(_Symbol, _Period, insideBarIndex);
   double ibRange = ibHigh - ibLow;

   // Convert ranges to pips
   double motherRangePips = motherRange / _Point / 10.0;
   double ibRangePips = ibRange / _Point / 10.0;

   // Check if it's an inside bar
   bool isInsideBar = false;

   if(StrictIB)
   {
      // Strict: high and low must be fully inside mother bar
      isInsideBar = (ibHigh < motherHigh && ibLow > motherLow);
   }
   else
   {
      // Relaxed: high and low can touch mother bar boundaries
      isInsideBar = (ibHigh <= motherHigh && ibLow >= motherLow);
   }

   // Check size constraints
   if(isInsideBar)
   {
      if(ibRangePips < MinIBSizePips || ibRangePips > MaxIBSizePips)
      {
         isInsideBar = false;
      }
   }

   // Update inside bar status
   if(isInsideBar)
   {
      datetime ibTime = iTime(_Symbol, _Period, insideBarIndex);

      // Only set new inside bar if it's different from the last one
      if(ibTime != insideBarTime)
      {
         insideBarDetected = true;
         insideBarHigh = ibHigh;
         insideBarLow = ibLow;
         insideBarTime = ibTime;

         Print("Inside Bar detected at ", TimeToString(ibTime));
         Print("IB High: ", insideBarHigh, " | IB Low: ", insideBarLow);
         Print("IB Range: ", DoubleToString(ibRangePips, 1), " pips");
      }
   }
}

//+------------------------------------------------------------------+
//| Check for entry signals                                            |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
   if(!insideBarDetected) return;

   double currentClose = iClose(_Symbol, _Period, 1);
   double currentHigh = iHigh(_Symbol, _Period, 1);
   double currentLow = iLow(_Symbol, _Period, 1);

   double breakoutBufferPoints = BreakoutBuffer * _Point * 10;

   // Check for bullish breakout (long entry)
   if(AllowLongTrades && currentClose > (insideBarHigh + breakoutBufferPoints))
   {
      Print("Bullish breakout detected! Close: ", currentClose, " > IB High: ", insideBarHigh);
      OpenTrade(ORDER_TYPE_BUY);
      insideBarDetected = false; // Reset after entry
      return;
   }

   // Check for bearish breakout (short entry)
   if(AllowShortTrades && currentClose < (insideBarLow - breakoutBufferPoints))
   {
      Print("Bearish breakout detected! Close: ", currentClose, " < IB Low: ", insideBarLow);
      OpenTrade(ORDER_TYPE_SELL);
      insideBarDetected = false; // Reset after entry
      return;
   }
}

//+------------------------------------------------------------------+
//| Open trade                                                         |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
{
   double lotSize = CalculateLotSize(orderType);
   if(lotSize <= 0)
   {
      Print("Invalid lot size calculated: ", lotSize);
      return;
   }

   double entryPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLoss = CalculateStopLoss(orderType, entryPrice);
   double takeProfit = CalculateTakeProfit(orderType, entryPrice);

   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = orderType;
   request.price = entryPrice;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = TradeComment;
   request.type_filling = ORDER_FILLING_FOK;

   // Try FOK, if fails try IOC
   if(!OrderSend(request, result))
   {
      request.type_filling = ORDER_FILLING_IOC;
      if(!OrderSend(request, result))
      {
         request.type_filling = ORDER_FILLING_RETURN;
         OrderSend(request, result);
      }
   }

   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
   {
      Print("Trade opened successfully!");
      Print("Type: ", EnumToString(orderType), " | Lot: ", lotSize, " | Entry: ", entryPrice);
      Print("SL: ", stopLoss, " | TP: ", takeProfit);
      dailyTradeCount++;
   }
   else
   {
      Print("Trade failed! Error code: ", result.retcode, " - ", result.comment);
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                        |
//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_ORDER_TYPE orderType)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPercent / 100.0;

   double entryPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLoss = CalculateStopLoss(orderType, entryPrice);

   double slDistance = MathAbs(entryPrice - stopLoss);
   if(slDistance == 0) return 0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   double lotSize = riskAmount / (slDistance / tickSize * tickValue);

   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                                |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   double ibRange = insideBarHigh - insideBarLow;
   double slDistance = ibRange * StopLossMultiplier;

   double stopLoss;
   if(orderType == ORDER_TYPE_BUY)
   {
      stopLoss = insideBarLow - slDistance * 0.2; // Place SL below IB low
   }
   else
   {
      stopLoss = insideBarHigh + slDistance * 0.2; // Place SL above IB high
   }

   return NormalizeDouble(stopLoss, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate take profit                                              |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   double ibRange = insideBarHigh - insideBarLow;
   double tpDistance = ibRange * TakeProfitMultiplier;

   double takeProfit;
   if(orderType == ORDER_TYPE_BUY)
   {
      takeProfit = entryPrice + tpDistance;
   }
   else
   {
      takeProfit = entryPrice - tpDistance;
   }

   return NormalizeDouble(takeProfit, _Digits);
}

//+------------------------------------------------------------------+
//| Manage open positions (trailing stop, etc.)                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      if(UseTrailingStop)
      {
         ApplyTrailingStop(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Apply trailing stop to position                                    |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;

   double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double positionSL = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double trailingStopPoints = TrailingStopPips * _Point * 10;
   double trailingStepPoints = TrailingStepPips * _Point * 10;

   double newSL = 0;
   bool shouldModify = false;

   if(positionType == POSITION_TYPE_BUY)
   {
      double trailPrice = currentBid - trailingStopPoints;
      if(trailPrice > positionSL + trailingStepPoints)
      {
         newSL = NormalizeDouble(trailPrice, _Digits);
         shouldModify = true;
      }
   }
   else // SELL
   {
      double trailPrice = currentAsk + trailingStopPoints;
      if(trailPrice < positionSL - trailingStepPoints || positionSL == 0)
      {
         newSL = NormalizeDouble(trailPrice, _Digits);
         shouldModify = true;
      }
   }

   if(shouldModify)
   {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};

      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = _Symbol;
      request.sl = newSL;
      request.tp = PositionGetDouble(POSITION_TP);

      if(OrderSend(request, result))
      {
         Print("Trailing stop applied. New SL: ", newSL);
      }
   }
}

//+------------------------------------------------------------------+
//| Count open positions for this EA                                   |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
//| Update chart comment                                               |
//+------------------------------------------------------------------+
void UpdateComment()
{
   string commentText = "=== IB 60-Min NASDAQ Strategy ===\n";
   commentText += "Daily Trades: " + IntegerToString(dailyTradeCount) + "/" + IntegerToString(MaxDailyTrades) + "\n";
   commentText += "Daily P&L: $" + DoubleToString(dailyPnL, 2) + "\n";
   commentText += "Open Positions: " + IntegerToString(CountOpenPositions()) + "\n";
   commentText += "Spread: " + DoubleToString(GetCurrentSpreadPips(), 1) + " pips\n";
   commentText += "Inside Bar: " + (insideBarDetected ? "Detected" : "None") + "\n";

   if(insideBarDetected)
   {
      commentText += "IB High: " + DoubleToString(insideBarHigh, _Digits) + "\n";
      commentText += "IB Low: " + DoubleToString(insideBarLow, _Digits) + "\n";
   }

   Comment(commentText);
}

//+------------------------------------------------------------------+
//| Get uninit reason text                                             |
//+------------------------------------------------------------------+
string getUninitReasonText(int reasonCode)
{
   string text = "";

   switch(reasonCode)
   {
      case REASON_PROGRAM: text = "EA terminated"; break;
      case REASON_REMOVE: text = "EA removed from chart"; break;
      case REASON_RECOMPILE: text = "EA recompiled"; break;
      case REASON_CHARTCHANGE: text = "Symbol or timeframe changed"; break;
      case REASON_CHARTCLOSE: text = "Chart closed"; break;
      case REASON_PARAMETERS: text = "Input parameters changed"; break;
      case REASON_ACCOUNT: text = "Account changed"; break;
      default: text = "Unknown reason"; break;
   }

   return text;
}
//+------------------------------------------------------------------+
