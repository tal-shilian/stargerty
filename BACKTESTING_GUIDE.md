# Liquidity Sweep Strategy - Backtesting Guide

## 🚀 How to Run Backtest on TradingView

### Step 1: Load the Strategy
1. Open **TradingView** (https://www.tradingview.com)
2. Click **Pine Editor** at the bottom of the screen
3. Click **"New"** → **"Blank indicator"**
4. Copy all code from `liquidity_sweep_strategy.pine`
5. Paste into the Pine Editor
6. Click **"Save"** and give it a name
7. Click **"Add to Chart"**

### Step 2: Configure Strategy Settings
Click the **gear icon** ⚙️ next to the strategy name on your chart to access settings:

#### **Properties Tab:**
- **Initial Capital**: $10,000 (default)
- **Order Size**: 10% of equity (default)
- **Commission**: 0.1% per trade
- **Slippage**: 2 ticks
- **Pyramiding**: 0 (no adding to positions)

#### **Inputs Tab - Key Settings:**

**Timeframe Settings:**
- Higher Timeframe 1: `60` (1 hour)
- Higher Timeframe 2: `240` (4 hours)
- Use Session Highs/Lows: ✅ Enabled

**Session Settings:**
- Trading Session: `0930-1600` (US market hours)
- Premarket Session: `0400-0930`
- Timezone: `America/New_York`

**Liquidity Settings:**
- Liquidity Sweep Lookback: `20` bars
- Sweep Buffer: `0.1%`

**Confirmation Settings:**
- Confirmation Candles Required: `5`
- Entry Confirmation Candles: `1`
- Fibonacci Extension Level: `0.79`

**Risk Management:**
- Risk:Reward Ratio: `2.0`
- Stop Loss (ATR Multiplier): `1.5`
- ATR Length: `14`
- Close Position at End of Session: ✅ Enabled
- Max Bars in Trade: `50` (0 to disable)

### Step 3: Choose Your Timeframe
Recommended timeframes for backtesting:
- **5-minute chart** (for intraday trading)
- **15-minute chart** (for swing entries)
- **1-hour chart** (for position trading)

### Step 4: Select Your Instrument
Works best on:
- **Forex pairs**: EUR/USD, GBP/USD, USD/JPY
- **Indices**: SPY, QQQ, ES1!, NQ1!
- **Crypto**: BTC/USD, ETH/USD

### Step 5: Run the Backtest
1. Click **"Strategy Tester"** tab at the bottom
2. Select date range (e.g., last 1-2 years)
3. Review performance metrics:
   - **Net Profit**
   - **Profit Factor**
   - **Max Drawdown**
   - **Win Rate**
   - **Average Trade**
   - **Sharpe Ratio**

## 📊 Understanding the Results

### Key Metrics to Watch:
- **Profit Factor** > 1.5 (good), > 2.0 (excellent)
- **Win Rate** > 50% (with 2:1 RR)
- **Max Drawdown** < 20% of capital
- **Total Trades** > 30 (for statistical significance)

### Visual Indicators on Chart:
- 🟡 **Yellow lines**: Session highs/lows (liquidity levels)
- 🔵 **Blue background**: Trading session
- 🟡 **Yellow background**: Premarket session
- 🟢 **"LIQ SWEEP"** label: Liquidity sweep detected
- 🔵 **"CONF 1-5"** labels: Confirmation candles
- 🟣 **"CONT"** label: Continuation confirmed
- 🟢 **"LONG ENTRY"** / 🔴 **"SHORT ENTRY"**: Trade entries
- **Green/Red lines**: Entry price, Stop Loss, Take Profit

## 🎯 Optimization Tips

### 1. Adjust Confirmation Requirements
- **More conservative**: Increase `Confirmation Candles Required` to 7-8
- **More aggressive**: Decrease to 3-4

### 2. Modify Risk:Reward
- **Higher RR**: Set to 3:1 or 4:1 (fewer wins, bigger profits)
- **Lower RR**: Set to 1.5:1 (more wins, smaller profits)

### 3. Fine-tune Stop Loss
- **Tighter stops**: Decrease ATR multiplier to 1.0
- **Wider stops**: Increase to 2.0-2.5

### 4. Session Optimization
- Test different session times for your timezone
- Enable/disable premarket trading
- Adjust max bars in trade based on your timeframe

### 5. Liquidity Sweep Sensitivity
- **More sweeps**: Increase lookback period to 30-50
- **Fewer sweeps**: Decrease to 10-15
- Adjust sweep buffer % (0.05% - 0.3%)

## 📈 Strategy Performance Checklist

Before going live, ensure:
- [ ] Backtested on at least 1 year of data
- [ ] Tested on multiple instruments
- [ ] Profit factor > 1.5
- [ ] Max drawdown acceptable for your risk tolerance
- [ ] At least 50+ trades in backtest
- [ ] Forward tested on demo account for 1-2 weeks
- [ ] Understand all entry/exit rules
- [ ] Risk per trade = 1-2% of account

## 🔧 Troubleshooting

### No Trades Appearing?
- Check if you're on the correct timeframe (5m-1h recommended)
- Verify session times match your instrument's trading hours
- Reduce confirmation candle requirements
- Increase liquidity sweep lookback period

### Too Many Trades?
- Increase confirmation candle requirements
- Tighten sweep buffer %
- Enable "Close Position at End of Session"
- Reduce max bars in trade

### Poor Win Rate?
- Increase risk:reward ratio
- Add more confirmation requirements
- Adjust stop loss (wider stops)
- Check if instrument is trending or ranging

## 📝 Strategy Logic Summary

1. **Liquidity Sweep**: Price wicks above/below key levels then reverses
2. **5 Confirmations**: BOS, iFVG, or Fib extension (2 of 3 required)
3. **Continuation**: EQ or FVG pattern (or 5min manipulation if premarket)
4. **Entry Confirmation**: 1 more confirmation candle
5. **Enter Trade**: Long or Short based on sweep direction
6. **Exit**: Take profit at 2:1 RR or stop loss hit

## 🎓 Next Steps

1. **Backtest** on your preferred instruments
2. **Optimize** parameters for best results
3. **Forward test** on demo account
4. **Paper trade** for 2-4 weeks
5. **Go live** with small position sizes
6. **Scale up** as you gain confidence

---

**⚠️ Risk Warning**: Past performance does not guarantee future results. Always use proper risk management and never risk more than you can afford to lose.

**📧 Support**: Review the strategy code comments for detailed explanations of each component.
