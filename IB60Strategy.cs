#region Using declarations
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Xml.Serialization;
using NinjaTrader.Cbi;
using NinjaTrader.Gui;
using NinjaTrader.Gui.Chart;
using NinjaTrader.Gui.SuperDom;
using NinjaTrader.Gui.Tools;
using NinjaTrader.Data;
using NinjaTrader.NinjaScript;
using NinjaTrader.Core.FloatingPoint;
using NinjaTrader.NinjaScript.Indicators;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

namespace NinjaTrader.NinjaScript.Strategies
{
    public class IB60Strategy : Strategy
    {
        #region Variables
        // IB tracking
        private double ibHigh = 0;
        private double ibLow = 0;
        private bool ibFormed = false;
        private bool tradeTakenToday = false;
        private DateTime currentDay = DateTime.MinValue;
        private DateTime ibStartTime = DateTime.MinValue;
        private DateTime ibEndTime = DateTime.MinValue;
        private bool longBreakout = false;
        private bool shortBreakout = false;
        private bool openingCandleBullish = false;
        private bool openingCandleSet = false;
        
        // Partial TP tracking
        private Order mainOrder = null;
        private double initialQuantity = 0;
        private bool tp1Hit = false;
        private bool tp2Hit = false;
        private bool movedToBreakEven = false;
        #endregion

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Description = @"Initial Balance Breakout 60min Strategy";
                Name = "IB60Strategy";
                Calculate = Calculate.OnBarClose;
                EntriesPerDirection = 1;
                EntryHandling = EntryHandling.AllEntries;
                IsExitOnSessionCloseStrategy = false;
                ExitOnSessionCloseSeconds = 30;
                IsFillLimitOnTouch = false;
                MaximumBarsLookBack = MaximumBarsLookBack.TwoHundredFiftySix;
                OrderFillResolution = OrderFillResolution.Standard;
                Slippage = 0;
                StartBehavior = StartBehavior.WaitUntilFlat;
                TimeInForce = TimeInForce.Gtc;
                TraceOrders = false;
                RealtimeErrorHandling = RealtimeErrorHandling.StopCancelClose;
                StopTargetHandling = StopTargetHandling.PerEntryExecution;
                BarsRequiredToTrade = 20;
                IsInstantiatedOnEachOptimizationIteration = true;

                // Trading Session
                SessionStartHour = 9;
                SessionStartMinute = 30;
                SessionEndHour = 16;
                SessionEndMinute = 0;
                
                // Strategy Settings
                IBPeriodMinutes = 60;
                BreakoutByClose = true;
                
                // Risk Management
                RiskPercent = 1.0;
                FixedLotSize = 1;
                StopLossPercent = 0.0;
                UseTrailingStop = false;
                TrailingStopPercent = 0.5;
                
                // Trade Management
                OneTradePerDay = true;
                CloseAtSessionEnd = true;
                UseOpeningCandleFilter = true;
                
                // Partial Take Profit
                UsePartialTP = true;
                TP1_Multiplier = 0.5;
                TP1_ClosePercent = 33.0;
                TP2_Multiplier = 1.0;
                TP2_ClosePercent = 33.0;
                TP3_Multiplier = 2.0;
                MoveToBreakEven = true;
            }
            else if (State == State.Configure)
            {
                // Add 30-minute data series for breakout detection
                AddDataSeries(BarsPeriodType.Minute, 30);
            }
        }

        protected override void OnBarUpdate()
        {
            if (CurrentBars[0] < BarsRequiredToTrade)
                return;

            // Work with primary bars (default timeframe)
            if (BarsInProgress != 0)
                return;

            DateTime now = Time[0];
            DateTime todayDate = now.Date;

            // Check if new day
            if (todayDate != currentDay)
            {
                // New day - reset variables
                currentDay = todayDate;
                ibFormed = false;
                tradeTakenToday = false;
                ibHigh = 0;
                ibLow = 0;
                longBreakout = false;
                shortBreakout = false;
                openingCandleSet = false;
                
                // Reset partial TP tracking
                mainOrder = null;
                initialQuantity = 0;
                tp1Hit = false;
                tp2Hit = false;
                movedToBreakEven = false;
                
                // Calculate IB start and end times for today
                ibStartTime = todayDate.AddHours(SessionStartHour).AddMinutes(SessionStartMinute);
                ibEndTime = ibStartTime.AddMinutes(IBPeriodMinutes);
                
                Print(string.Format("New day: {0:yyyy-MM-dd} | IB Period: {1:HH:mm} - {2:HH:mm}", 
                    todayDate, ibStartTime, ibEndTime));
            }

            // Check if we're in trading session
            if (!IsInTradingSession(now))
            {
                if (CloseAtSessionEnd && Position.MarketPosition != MarketPosition.Flat)
                {
                    ExitLong();
                    ExitShort();
                    Print("Position closed at session end");
                }
                return;
            }

            // Form Initial Balance after period ends
            if (!ibFormed && now >= ibEndTime.AddMinutes(1))
            {
                UpdateInitialBalance();
                
                if (ibHigh > 0 && ibLow > 0)
                {
                    ibFormed = true;
                    Print(string.Format("✓ IB Formed - High: {0} Low: {1} Range: {2} ticks", 
                        ibHigh, ibLow, (ibHigh - ibLow) / TickSize));
                    
                    // Analyze opening candle direction
                    if (UseOpeningCandleFilter && !openingCandleSet)
                    {
                        AnalyzeOpeningCandle();
                    }
                }
            }

            // Check for breakout after IB is formed
            if (ibFormed && (!OneTradePerDay || !tradeTakenToday))
            {
                CheckForBreakout();
            }

            // Manage partial take profit
            if (UsePartialTP && Position.MarketPosition != MarketPosition.Flat)
            {
                ManagePartialTP();
            }
        }

        #region Helper Methods
        
        private bool IsInTradingSession(DateTime time)
        {
            TimeSpan currentTime = time.TimeOfDay;
            TimeSpan startTime = new TimeSpan(SessionStartHour, SessionStartMinute, 0);
            TimeSpan endTime = new TimeSpan(SessionEndHour, SessionEndMinute, 0);
            
            return currentTime >= startTime && currentTime < endTime;
        }

        private void UpdateInitialBalance()
        {
            Print(string.Format("Looking for IB candles. IB Period: {0:HH:mm} - {1:HH:mm}", 
                ibStartTime, ibEndTime));
            
            int candlesFound = 0;
            
            // Look through 30-minute bars to find IB period
            for (int i = 0; i < Math.Min(10, CurrentBars[1]); i++)
            {
                DateTime candleTime = Times[1][i];
                DateTime candleEndTime = candleTime.AddMinutes(30);
                
                // Check if this candle is from today and within IB period
                if (candleTime.Date == currentDay && 
                    candleTime >= ibStartTime && 
                    candleTime < ibEndTime)
                {
                    double high = Highs[1][i];
                    double low = Lows[1][i];
                    
                    if (ibHigh == 0 || high > ibHigh)
                        ibHigh = high;
                    
                    if (ibLow == 0 || low < ibLow)
                        ibLow = low;
                    
                    candlesFound++;
                    Print(string.Format("  >>> IB M30 Candle {0} at bar {1}: {2:HH:mm} H={3} L={4}", 
                        candlesFound, i, candleTime, high, low));
                }
            }
            
            if (candlesFound > 0)
            {
                Print(string.Format(">>> IB Formed from {0} M30 candles: H={1} L={2}", 
                    candlesFound, ibHigh, ibLow));
            }
            else
            {
                Print("!!! IB NOT FOUND - No M30 candles in IB period");
            }
        }

        private void AnalyzeOpeningCandle()
        {
            // Find the 60-minute IB candle
            for (int i = 0; i < Math.Min(10, CurrentBar); i++)
            {
                if (Times[0][i].Date == currentDay && 
                    Times[0][i] >= ibStartTime && 
                    Times[0][i] < ibEndTime)
                {
                    double ibOpen = Opens[0][i];
                    double ibClose = Closes[0][i];
                    openingCandleBullish = (ibClose > ibOpen);
                    openingCandleSet = true;
                    
                    string direction = openingCandleBullish ? "Bullish" : "Bearish";
                    Print(string.Format("✓ Opening Candle (60min): {0} | Open: {1} Close: {2}", 
                        direction, ibOpen, ibClose));
                    break;
                }
            }
        }

        private void CheckForBreakout()
        {
            if (Position.MarketPosition != MarketPosition.Flat)
                return;

            double close = Close[0];
            double high = High[0];
            double low = Low[0];

            // Check for long breakout
            if (!longBreakout)
            {
                bool breakout = BreakoutByClose ? (close > ibHigh) : (high > ibHigh);
                
                // Apply opening candle filter
                if (UseOpeningCandleFilter && !openingCandleBullish)
                {
                    if (breakout)
                        Print("⊘ Long breakout ignored - Opening candle was bearish");
                    breakout = false;
                }
                
                if (breakout)
                {
                    longBreakout = true;
                    OpenLongPosition();
                    tradeTakenToday = true;
                    return;
                }
            }

            // Check for short breakout
            if (!shortBreakout)
            {
                bool breakout = BreakoutByClose ? (close < ibLow) : (low < ibLow);
                
                // Apply opening candle filter
                if (UseOpeningCandleFilter && openingCandleBullish)
                {
                    if (breakout)
                        Print("⊘ Short breakout ignored - Opening candle was bullish");
                    breakout = false;
                }
                
                if (breakout)
                {
                    shortBreakout = true;
                    OpenShortPosition();
                    tradeTakenToday = true;
                }
            }
        }

        private void OpenLongPosition()
        {
            double price = Close[0];
            double sl = StopLossPercent > 0 ? 
                price - (price * StopLossPercent / 100.0) : ibLow;
            
            double ibRange = ibHigh - ibLow;
            double tpMultiplier = UsePartialTP ? TP3_Multiplier : 2.0;
            double tp = price + (ibRange * tpMultiplier);
            
            int quantity = CalculateQuantity(price - sl);
            initialQuantity = quantity;
            
            EnterLong(quantity, "IB60 Long");
            SetStopLoss(CalculationMode.Price, sl);
            SetProfitTarget(CalculationMode.Price, tp);
            
            Print(string.Format("Long position opened at {0} SL: {1} TP: {2} Qty: {3}", 
                price, sl, tp, quantity));
        }

        private void OpenShortPosition()
        {
            double price = Close[0];
            double sl = StopLossPercent > 0 ? 
                price + (price * StopLossPercent / 100.0) : ibHigh;
            
            double ibRange = ibHigh - ibLow;
            double tpMultiplier = UsePartialTP ? TP3_Multiplier : 2.0;
            double tp = price - (ibRange * tpMultiplier);
            
            int quantity = CalculateQuantity(sl - price);
            initialQuantity = quantity;
            
            EnterShort(quantity, "IB60 Short");
            SetStopLoss(CalculationMode.Price, sl);
            SetProfitTarget(CalculationMode.Price, tp);
            
            Print(string.Format("Short position opened at {0} SL: {1} TP: {2} Qty: {3}", 
                price, sl, tp, quantity));
        }

        private int CalculateQuantity(double slDistance)
        {
            if (RiskPercent <= 0)
                return FixedLotSize;
            
            double accountBalance = Account.Get(AccountItem.CashValue, Currency.UsDollar);
            double riskAmount = accountBalance * RiskPercent / 100.0;
            
            double slInTicks = slDistance / TickSize;
            int quantity = (int)(riskAmount / (slInTicks * Instrument.MasterInstrument.PointValue));
            
            return Math.Max(1, quantity);
        }

        private void ManagePartialTP()
        {
            if (Position.MarketPosition == MarketPosition.Flat)
                return;

            double entryPrice = Position.AveragePrice;
            double currentPrice = Close[0];
            int currentQuantity = Position.Quantity;
            
            double ibRange = ibHigh - ibLow;
            bool isLong = (Position.MarketPosition == MarketPosition.Long);
            
            // Calculate profit in IB range multiples
            double profitMultiple = isLong ? 
                (currentPrice - entryPrice) / ibRange : 
                (entryPrice - currentPrice) / ibRange;
            
            // Check TP1
            if (!tp1Hit && profitMultiple >= TP1_Multiplier)
            {
                int closeQuantity = (int)(initialQuantity * TP1_ClosePercent / 100.0);
                
                if (closeQuantity > 0 && closeQuantity <= currentQuantity)
                {
                    if (isLong)
                        ExitLong(closeQuantity, "TP1", "IB60 Long");
                    else
                        ExitShort(closeQuantity, "TP1", "IB60 Short");
                    
                    tp1Hit = true;
                    Print(string.Format("✓ TP1 Hit ({0}x IB): Closed {1}% ({2} contracts) at {3}", 
                        TP1_Multiplier, TP1_ClosePercent, closeQuantity, currentPrice));
                    
                    // Move to break-even after TP1
                    if (MoveToBreakEven && !movedToBreakEven)
                    {
                        SetStopLoss(CalculationMode.Price, entryPrice);
                        movedToBreakEven = true;
                        Print(string.Format("✓ Stop Loss moved to Break-Even: {0}", entryPrice));
                    }
                }
            }
            
            // Check TP2
            if (tp1Hit && !tp2Hit && profitMultiple >= TP2_Multiplier)
            {
                int closeQuantity = (int)(currentQuantity * TP2_ClosePercent / 100.0);
                
                if (closeQuantity > 0 && closeQuantity <= currentQuantity)
                {
                    if (isLong)
                        ExitLong(closeQuantity, "TP2", "IB60 Long");
                    else
                        ExitShort(closeQuantity, "TP2", "IB60 Short");
                    
                    tp2Hit = true;
                    Print(string.Format("✓ TP2 Hit ({0}x IB): Closed {1}% of remaining ({2} contracts) at {3}", 
                        TP2_Multiplier, TP2_ClosePercent, closeQuantity, currentPrice));
                }
            }
        }
        
        #endregion

        #region Properties
        
        [NinjaScriptProperty]
        [Range(0, 23)]
        [Display(Name="Session Start Hour", Description="Session Start Hour (Local Time)", Order=1, GroupName="Trading Session")]
        public int SessionStartHour { get; set; }

        [NinjaScriptProperty]
        [Range(0, 59)]
        [Display(Name="Session Start Minute", Order=2, GroupName="Trading Session")]
        public int SessionStartMinute { get; set; }

        [NinjaScriptProperty]
        [Range(0, 23)]
        [Display(Name="Session End Hour", Order=3, GroupName="Trading Session")]
        public int SessionEndHour { get; set; }

        [NinjaScriptProperty]
        [Range(0, 59)]
        [Display(Name="Session End Minute", Order=4, GroupName="Trading Session")]
        public int SessionEndMinute { get; set; }

        [NinjaScriptProperty]
        [Range(1, 240)]
        [Display(Name="IB Period (Minutes)", Order=1, GroupName="Strategy Settings")]
        public int IBPeriodMinutes { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Breakout By Close", Description="Breakout measured by close vs high/low", Order=2, GroupName="Strategy Settings")]
        public bool BreakoutByClose { get; set; }

        [NinjaScriptProperty]
        [Range(0, 100)]
        [Display(Name="Risk Percent", Description="Risk % per trade (0 = use fixed size)", Order=1, GroupName="Risk Management")]
        public double RiskPercent { get; set; }

        [NinjaScriptProperty]
        [Range(1, int.MaxValue)]
        [Display(Name="Fixed Lot Size", Order=2, GroupName="Risk Management")]
        public int FixedLotSize { get; set; }

        [NinjaScriptProperty]
        [Range(0, 100)]
        [Display(Name="Stop Loss %", Description="Stop Loss % of entry (0 = use IB range)", Order=3, GroupName="Risk Management")]
        public double StopLossPercent { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Use Trailing Stop", Order=4, GroupName="Risk Management")]
        public bool UseTrailingStop { get; set; }

        [NinjaScriptProperty]
        [Range(0.1, 10)]
        [Display(Name="Trailing Stop %", Order=5, GroupName="Risk Management")]
        public double TrailingStopPercent { get; set; }

        [NinjaScriptProperty]
        [Display(Name="One Trade Per Day", Order=1, GroupName="Trade Management")]
        public bool OneTradePerDay { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Close At Session End", Order=2, GroupName="Trade Management")]
        public bool CloseAtSessionEnd { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Use Opening Candle Filter", Order=3, GroupName="Trade Management")]
        public bool UseOpeningCandleFilter { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Use Partial TP", Order=1, GroupName="Partial Take Profit")]
        public bool UsePartialTP { get; set; }

        [NinjaScriptProperty]
        [Range(0.1, 10)]
        [Display(Name="TP1 Multiplier", Order=2, GroupName="Partial Take Profit")]
        public double TP1_Multiplier { get; set; }

        [NinjaScriptProperty]
        [Range(1, 100)]
        [Display(Name="TP1 Close %", Order=3, GroupName="Partial Take Profit")]
        public double TP1_ClosePercent { get; set; }

        [NinjaScriptProperty]
        [Range(0.1, 10)]
        [Display(Name="TP2 Multiplier", Order=4, GroupName="Partial Take Profit")]
        public double TP2_Multiplier { get; set; }

        [NinjaScriptProperty]
        [Range(1, 100)]
        [Display(Name="TP2 Close %", Order=5, GroupName="Partial Take Profit")]
        public double TP2_ClosePercent { get; set; }

        [NinjaScriptProperty]
        [Range(0.1, 10)]
        [Display(Name="TP3 Multiplier", Order=6, GroupName="Partial Take Profit")]
        public double TP3_Multiplier { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Move To Break-Even", Order=7, GroupName="Partial Take Profit")]
        public bool MoveToBreakEven { get; set; }
        
        #endregion
    }
}
