# IB 60-Minute NASDAQ Strategy

A professional Inside Bar (IB) breakout trading strategy for NASDAQ on the 60-minute timeframe, implemented in MQL5 for MetaTrader 5.

## Strategy Overview

### What is an Inside Bar?

An Inside Bar is a price action pattern where:
- The high and low of the current bar are completely within the high and low of the previous bar (mother bar)
- It indicates market consolidation and potential breakout
- When price breaks out of the inside bar range, it often leads to strong directional moves

### Trading Logic

1. **Pattern Detection**: Identifies inside bars on the 60-minute timeframe
2. **Entry Signal**: Enters trades when price breaks above/below the inside bar range
3. **Position Management**: Uses dynamic stop loss and take profit based on inside bar range
4. **Risk Management**: Configurable risk per trade, daily trade limits, and loss limits

## Features

### Core Strategy Components
- Inside bar pattern detection with customizable strictness
- Breakout confirmation with buffer
- Dynamic position sizing based on risk percentage
- Stop loss placed based on inside bar range
- Take profit at multiple of inside bar range
- Trailing stop functionality

### Risk Management
- Risk per trade as percentage of account balance
- Maximum daily trades limit
- Maximum daily loss percentage
- Spread filter
- Time-based trading filter (optional)

### Position Management
- Automatic lot size calculation based on risk
- Dynamic stop loss and take profit
- Trailing stop with customizable distance and step
- Support for both long and short trades

## Installation

1. Copy `IB_60Min_NASDAQ.mq5` to your MetaTrader 5 installation directory:
   ```
   C:\Users\[YourName]\AppData\Roaming\MetaQuotes\Terminal\[TerminalID]\MQL5\Experts\
   ```

2. Restart MetaTrader 5 or refresh the Navigator panel (right-click → Refresh)

3. Find the EA in Navigator panel under "Expert Advisors"

## Setup Instructions

### 1. Chart Setup
- Symbol: NASDAQ-related instrument (e.g., NQ, US100, USTEC)
- Timeframe: H1 (60 minutes) - **REQUIRED**
- Chart type: Candlestick recommended for visual pattern confirmation

### 2. Attach EA to Chart
1. Drag and drop `IB_60Min_NASDAQ` from Navigator to the chart
2. Configure input parameters (see below)
3. Enable "Allow Algo Trading" button in MetaTrader toolbar
4. Check "Allow live trading" in EA settings

### 3. Recommended Settings for NASDAQ

#### Conservative Settings (Lower Risk)
```
Risk per trade: 0.5-1.0%
Maximum daily trades: 2-3
Stop Loss Multiplier: 1.0
Take Profit Multiplier: 2.0
Max Spread: 5-10 pips
Trailing Stop: Enabled (30 pips)
```

#### Moderate Settings (Balanced)
```
Risk per trade: 1.0-1.5%
Maximum daily trades: 3-5
Stop Loss Multiplier: 1.0
Take Profit Multiplier: 2.5
Max Spread: 10 pips
Trailing Stop: Enabled (20 pips)
```

#### Aggressive Settings (Higher Risk)
```
Risk per trade: 2.0%
Maximum daily trades: 5-7
Stop Loss Multiplier: 0.8
Take Profit Multiplier: 3.0
Max Spread: 15 pips
Trailing Stop: Enabled (15 pips)
```

## Input Parameters

### Trading Settings
- **RiskPercent** (default: 1.0): Percentage of account balance to risk per trade
- **MagicNumber** (default: 60001): Unique identifier for this EA's orders
- **TradeComment** (default: "IB-60Min-NASDAQ"): Comment added to orders

### Inside Bar Settings
- **LookbackBars** (default: 1): Number of bars to look back for pattern
- **StrictIB** (default: true): If true, inside bar must be fully contained (strict). If false, can touch boundaries
- **MinIBSizePips** (default: 10): Minimum inside bar range in pips
- **MaxIBSizePips** (default: 500): Maximum inside bar range in pips

### Entry Settings
- **BreakoutBuffer** (default: 5.0): Additional pips required for breakout confirmation
- **TradeOnClose** (default: true): Only enter on bar close (recommended)
- **AllowLongTrades** (default: true): Enable long (buy) trades
- **AllowShortTrades** (default: true): Enable short (sell) trades

### Exit Settings
- **StopLossMultiplier** (default: 1.0): Stop loss distance as multiple of IB range
- **TakeProfitMultiplier** (default: 2.0): Take profit distance as multiple of IB range
- **UseTrailingStop** (default: true): Enable trailing stop
- **TrailingStopPips** (default: 30): Trailing stop distance in pips
- **TrailingStepPips** (default: 10): Minimum price movement to adjust trailing stop

### Time Filter
- **UseTimeFilter** (default: false): Enable time-based trading filter
- **StartHour** (default: 9): Trading start hour (broker time)
- **EndHour** (default: 16): Trading end hour (broker time)

### Money Management
- **MaxSpreadPips** (default: 10.0): Maximum allowed spread in pips
- **MaxDailyTrades** (default: 3): Maximum number of trades per day
- **MaxDailyLossPct** (default: 3.0): Maximum daily loss percentage (stops trading if exceeded)

## How the Strategy Works

### Step-by-Step Process

1. **New Bar Check**: EA processes on each new 60-minute bar
2. **Daily Limit Check**: Verifies daily trade count and loss limits
3. **Time Filter**: Checks if within allowed trading hours (if enabled)
4. **Spread Check**: Ensures spread is within acceptable range
5. **Position Management**: Updates trailing stops on existing positions
6. **Pattern Detection**: Scans for inside bar patterns
7. **Entry Signal**: Waits for breakout confirmation
8. **Trade Execution**: Opens position with calculated lot size, SL, and TP

### Inside Bar Detection

The EA identifies an inside bar when:
- Current bar's high is below (or equal to, if StrictIB=false) mother bar's high
- Current bar's low is above (or equal to, if StrictIB=false) mother bar's low
- Inside bar range is between MinIBSizePips and MaxIBSizePips

### Entry Signals

**Long Entry (Buy)**:
- Price closes above inside bar high + breakout buffer
- AllowLongTrades = true
- No existing position open

**Short Entry (Sell)**:
- Price closes below inside bar low - breakout buffer
- AllowShortTrades = true
- No existing position open

### Position Sizing

Lot size is calculated automatically based on:
```
Risk Amount = Account Balance × RiskPercent / 100
Stop Loss Distance = |Entry Price - Stop Loss|
Lot Size = Risk Amount / (Stop Loss Distance in ticks × Tick Value)
```

### Stop Loss Placement

- **Long trades**: Below inside bar low - (IB range × StopLossMultiplier × 0.2)
- **Short trades**: Above inside bar high + (IB range × StopLossMultiplier × 0.2)

### Take Profit Placement

- **Long trades**: Entry Price + (IB range × TakeProfitMultiplier)
- **Short trades**: Entry Price - (IB range × TakeProfitMultiplier)

## Trading Guidelines

### Best Practices

1. **Always use on 60-minute timeframe** - This is critical for the strategy
2. **Start with conservative settings** - Test with 0.5-1% risk per trade
3. **Backtest before live trading** - Use MetaTrader Strategy Tester
4. **Monitor spread** - NASDAQ can have varying spreads; adjust MaxSpreadPips accordingly
5. **Consider time filter** - Enable during high liquidity hours (e.g., US market hours)
6. **Use trailing stop** - Helps capture extended moves while protecting profits

### NASDAQ-Specific Considerations

- **High volatility**: NASDAQ can be very volatile; consider wider stops
- **Trading hours**: Most active during US market hours (14:30-21:00 UTC)
- **News events**: Be cautious around major economic announcements
- **Spread**: Can widen during news or low liquidity periods
- **Overnight gaps**: Consider closing positions before market close if preferred

### Risk Management Tips

1. **Never risk more than 1-2%** per trade initially
2. **Set realistic daily loss limits** (3-5% recommended)
3. **Limit daily trades** to avoid overtrading
4. **Monitor account regularly** - Don't set and forget
5. **Keep trading journal** - Track performance and adjust parameters

## Monitoring & Troubleshooting

### Chart Display

The EA displays real-time information on the chart:
- Daily trade count
- Daily P&L
- Open positions
- Current spread
- Inside bar status
- Inside bar levels (when detected)

### Common Issues

**EA not trading:**
- Check "Allow Algo Trading" is enabled
- Verify "Allow live trading" in EA properties
- Check Experts tab in Terminal for error messages
- Ensure chart is on H1 timeframe

**Trades not opening:**
- Check spread (may exceed MaxSpreadPips)
- Verify daily limits not exceeded
- Check if time filter is active
- Ensure sufficient margin available

**Unexpected results:**
- Verify symbol specifications match your broker
- Check point/pip calculations for your symbol
- Review trade history in Terminal

## Backtesting

### How to Backtest

1. Open MetaTrader 5 Strategy Tester (Ctrl+R)
2. Select `IB_60Min_NASDAQ` EA
3. Choose NASDAQ symbol (e.g., NQ, US100)
4. Set timeframe to H1
5. Select date range (minimum 6 months recommended)
6. Set initial deposit and execution mode
7. Click "Start"

### Optimization

You can optimize these parameters:
- RiskPercent
- StopLossMultiplier
- TakeProfitMultiplier
- TrailingStopPips
- BreakoutBuffer
- MinIBSizePips / MaxIBSizePips

**Note**: Avoid over-optimization (curve fitting). Test optimized parameters on out-of-sample data.

## Important Disclaimers

⚠️ **Trading Risk Warning**:
- Trading involves substantial risk of loss
- Past performance does not guarantee future results
- Only trade with money you can afford to lose
- This EA is provided for educational purposes
- Always test thoroughly on demo account before live trading

⚠️ **No Warranty**:
- This software is provided "as is" without any warranties
- Developer is not responsible for any trading losses
- Users are responsible for their own trading decisions

## Support & Updates

- Review the code comments for detailed implementation details
- Test thoroughly before live deployment
- Keep a trading journal to track EA performance
- Adjust parameters based on changing market conditions

## Version History

- **v1.00** - Initial release
  - Inside Bar detection on H1 timeframe
  - Breakout entry system
  - Dynamic position sizing
  - Trailing stop functionality
  - Daily risk controls
  - Time and spread filters

## License

Copyright (c) 2025 Stargerty Trading System

---

**Happy Trading! 📈**

Remember: This EA is a tool to assist your trading. Always combine automated trading with proper risk management and market understanding.
