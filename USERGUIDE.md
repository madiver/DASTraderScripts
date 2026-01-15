# USER GUIDE

## OVERVIEW

These scripts are the hotkeys I use in DAS Trader for active, discretionary day trading. They focus on fast, repeatable order entry with guard rails and are designed around a single active symbol at a time. I treat the ice breaker (Buy IB) entries as the first test of a trade thesis; while DAS allows multiple positions, these hotkeys assume one symbol and may behave unpredictably otherwise.

These scripts are designed for LONG positions only. Shorting is not supported.

Repository structure: the `hotkeys/` folder contains the `.das` hotkey scripts, `keymap.yaml` defines the key bindings and metadata, and `other scripts/` contains support scripts like the timer. A `.das` file is plain text you can paste into the DAS Trader Script Editor. The `keymap.yaml` can be compiled into a `Hotkey.htk` using the DAS Hotkey Tools VS Code extension, or you can skip the compiler and copy the scripts manually.

These scripts assume you have a primary montage window named `Primary_OE` (Primary Order Entry). If that montage name does not exist, many scripts will fail or behave incorrectly. You can reference my DAS Trader desktop and chart settings here: https://github.com/madiver/DASTraderConfig

Regardless of the method you choose, the timer script must be installed manually in DAS Trader under "Timer Event Scripts." I also recommend adding `ExecHotKey("Set Global Variables");` to your Desktop Load Scripts so globals are initialized every time DAS starts.

Important: update `$TRSIM` and `$LIVEACT` in `hotkeys/set_global_variables.das` with your actual account identifiers if they are not already populated. `$LIVEACT` is used by the timer for live-only daily loss guards and `$TRSIM` is shown in the config display. Also verify that any `%%SIMULATED%%` and `%%LIVE%%` placeholders have been replaced in the SIM/LIVE switch and session scripts (the VS Code extension handles this during build; if you copy scripts manually, you must replace them yourself).

By default (`$useTimerArming = 1`), a buy hotkey sends the limit order, records entry context, and returns immediately. A timer-driven handler then waits for a fill and arms stop loss / take profit on subsequent 1-second ticks. If `$useTimerArming = 0`, the buy hotkey polls for a fill up to `$maxPolls * $pollMs`; if nothing fills, the order is canceled and the script exits without arming any protection. If a partial fill meets `$minFillShares`, the remainder is canceled (when enabled) and the scripts proceed as if the trade is active, using the average entry price for subsequent calculations.

Stops are placed as STOP/SLP orders routed to the broker, which means the stop logic lives on the broker side once submitted. Take-profit is implemented with DAS alerts that fire when price reaches the configured R target and then execute the Take Profit hotkey; those alerts are client-side and require DAS to remain open with live data.

## GLOBAL VARIABLES

All core settings live in `hotkeys/set_global_variables.das`. If you change a
value, rerun "Set Global Variables" so the globals refresh in DAS.

Variables by category:

Runtime counters and modes:
- `$oneSecondScriptCnt`: internal counter used by `other scripts/timer.das`.
- `$rehab`: enables rehab mode to block scale-ins and larger live entries.

Feature toggles and entry guards:
- `$useSlippageMargin`: enables the stop-vs-bid margin check in buy scripts.
- `$slipTicksMin`: minimum tick margin for slippage checks.
- `$slipSpreadFrac`: fraction of spread added to the slippage margin.
- `$acceptPartial`: allows partial fills within the polling window.
- `$minFillShares`: minimum shares to accept when partial fills are allowed.
- `$cancelRemainderOnPartial`: cancels the unfilled remainder before arming stops.
- `$usePerTradeRiskCap`: blocks entries if projected risk exceeds `$riskCapDollars`.
- `$useSpreadCheck`: enables spread-vs-R safety checks before entries.
- `$useAutoStop`: toggles auto stop placement.
- `$useTakeProfit`: toggles take-profit alerts/executor behavior.
- `$resetStopOnCancel`: re-arms the stop after `cancel_all.das` if long.
- `$useTimerArming`: uses timer-based entry arming (1) or inline polling (0).

Risk and execution:
- `$entryOffset`: bid/ask offset for the "plus" entry scripts.
- `$exitOffset`: bid offset for Bid- sells and non-dynamic stop-limit offsets.
- `$stopLossTrigger`: fixed 1R risk per share (used when dynamic stops are off).
- `$takeProfitFactor`: R multiple for take-profit alerts.
- `$takeProfitSize`: fraction of the position to sell on a TP trigger.

Dynamic stop settings (buy_ib only):
- `$dynamicStop`: enables spread-based R for buy IB entries.
- `$dynamicStopMult`: multiplier for the spread-based R.
- `$dynamicStopActive`: runtime flag set when a dynamic trade is active.
- `$dynamicStopR`: stored dynamic R used for stops and TP during the trade.

Account tokens:
- `$TRSIM`: SIM account identifier.
- `$LIVEACT`: LIVE account identifier.

Sizing and risk limits:
- `$qtyMult`: position size multiplier.
- `$maxPositionSize`: maximum total position size in shares.
- `$riskCapDollars`: maximum projected risk per trade in dollars.
- `$maxDailyLoss`: daily loss lock threshold.

Order fill polling:
- `$pollMs`: polling interval in milliseconds.
- `$maxPolls`: maximum number of polls before canceling an unfilled order.
  These are used when `$useTimerArming = 0`.

Timer-based entry arming (runtime):
- `$entryPending`, `$entryStage`, `$entryTicks`, `$entryMaxTicks`: timer state and timeout for arming stops/TP after fills.
- `$entrySymbol`, `$entryPosBefore`, `$entryAvgBefore`, `$entryScaleIn`, `$entryDynR`: captured entry context used by the timer handler.

`Set Global Variables` also runs `Initialize Session Equity` to seed the daily
loss baseline used by the timer script.

Use "Show Config" to view the current runtime values.

## BUY ORDERS

Sizing philosophy: start small to probe the trade, add only when it is working, and cap exposure with hard limits. Base sizing is a 50-share clip multiplied by `$qtyMult`. Buy 25 uses half of that clip, Buy 50 uses the full clip, and Buy IB (ice breaker) uses roughly one quarter of the 50-share clip (rounded to 5-share lots). This keeps the sizing deterministic and proportional to your 1R risk. In rehab mode (`$rehab = 1`), live trading is restricted to ice breaker entries and scale-ins are blocked.

Rehab mode is a safety throttle for live trading. When enabled (`$rehab = 1`), the scripts block scale-ins and prevent larger clip entries in live accounts, forcing you to trade only ice breaker size while you reset discipline or reduce risk after a drawdown. You set it by changing `$rehab` in `hotkeys/set_global_variables.das` and re-running "Set Global Variables" (or restarting DAS).

### Ice breaker, half, and full size

- Buy IB scripts are the ice breaker entries. They size at roughly one quarter
  of the 50-share base clip after applying `$qtyMult` and then round to 5-share
  lots with a 5-share minimum. In formula form: `ibShares = round5(50 * $qtyMult * 0.25)`.
- Buy 25 uses `25 * $qtyMult` shares; Buy 50 uses `50 * $qtyMult` shares. These
  are the base clip sizes for normal entries and adds.
- All buy scripts enforce `$maxPositionSize` and `$riskCapDollars` before
  sending an order.
- "Plus" versions use `$entryOffset` to price above bid or ask.

### Scaling-in logic

Scaling in means adding shares after an initial entry once the trade is working
and risk is reduced. These scripts only allow scale-ins when the existing
position has moved at least 1R in your favor.

- The profit gate is measured as `BID - AvgCost >= R` for longs. R is
  `$stopLossTrigger` for normal trades or the dynamic R when enabled for Buy IB.
- When adding to a position, the scripts arm the scale-in BE stop
  (`Set Auto Stop BE Scale 1/1`) so the combined position is protected.
- Live rehab mode (`$rehab = 1`) blocks scale-ins entirely.
- Entries are rejected if `$maxPositionSize` or `$riskCapDollars` would be
  exceeded after the add.
- Spread safety checks and slippage margins guard entries before an order is
  sent.

## SELL ORDERS

Sell hotkeys are designed for manual partials and exits on long positions. They
cancel existing orders for the symbol to avoid conflicting routes, then send a
limit order. Partial sell hotkeys re-arm stops/TP after a full fill so the
remaining position stays protected.

### Standard sell orders

- Ask sells place a limit order at the current Ask (price first).
- Bid- sells place a limit order at Bid minus `$exitOffset` (fill priority).
- Bid- prices are snapped to valid tick sizes and clamped to non-negative values.
- After a full fill on partial sells, the scripts re-arm `Set Auto Stop` and
  `Set Take Profit` if those features are enabled.

### Break-even stop losses / sell orders

Break-even (BE) scripts move protection to breakeven once a position is working.

- For the standard BE scripts (1/1 and 1/2), if price has not reached the BE
  trigger (currently `$0.03` above avg cost), they place a BE limit sell.
- Once price clears the trigger, those scripts place a stop-limit above
  breakeven (stop at avg + offset, limit at avg).
- The scale-in BE script uses a stop-limit even before the trigger (stop at
  avg cost), then moves to a stop above BE once the trigger is cleared.
- Variants protect the full position or a fraction (1/1, 1/2, or scale-in
  versions), and they honor `$useAutoStop`.

## STOP LOSSES

### Standard stop losses

`Set Auto Stop` places a stop-limit order at 1R below avg cost for long
positions. R is `$stopLossTrigger` when dynamic stops are inactive. The script
uses the montage average cost when available and falls back to the entry
reference price or last price if AvgCost is lagging. It cancels existing sell
orders for the symbol before placing the new stop.

When dynamic stops are inactive, the stop-limit offset uses `$exitOffset`. The
order is snapped to valid tick sizes and sent as a STOP/SLP order.

### Dynamic stop losses

Dynamic stops are only supported for Buy IB entries due to the added risk of
spread-based sizing, and they only activate when `$dynamicStop == 1`. They are
intended for parabolic movers where spreads and intraday swings expand sharply
as price accelerates.

- R is computed once at order send: `R = spread * $dynamicStopMult`.
- R is fixed for the life of the trade and reused for scale-ins.
- The stop trigger uses the dynamic R.
- Adaptive stop-limit offsets are used only when a dynamic stop is active; the
  offset is derived from the live spread at stop placement and capped by an
  internal maximum.
- Dynamic state is cleared when flat by the timer script.

## TAKE PROFIT

Take-profit is implemented as a DAS price alert that triggers an execution
hotkey. It is not a resting broker-side order.

`Set Take Profit` builds the alert using an R-based distance:
- Distance is `R * $takeProfitFactor`.
- R is `$stopLossTrigger` for normal trades or dynamic R when active.
- The alert watches last sale and fires above the target for longs.

When the alert fires, `Take Profit Executor`:
- Cancels existing sell orders for the symbol.
- Sells a partial position sized by `$takeProfitSize`.
- Re-arms stops and (if needed) re-establishes the TP alert after the fill.

Stale take-profit alerts are cleaned up by the timer script a few seconds after
the position is flat.

## OTHER GUARD RAILS

These controls help prevent low-quality fills and oversized risk.

- Spread checks: reject entries when spread is too large relative to R
  (`$useSpreadCheck`).
- Slippage margin: requires the planned stop to sit below bid by a minimum
  tick/spread buffer (`$useSlippageMargin`, `$slipTicksMin`, `$slipSpreadFrac`).
- Max daily loss: a daily lock prevents new entries after a drawdown threshold
  (`$maxDailyLoss`). The lock is enforced by the timer script.
- Per-trade risk cap: blocks entries when projected risk exceeds
  `$riskCapDollars` (`$usePerTradeRiskCap`).

## TIMER SCRIPT

`other scripts/timer.das` does three things:

1) Enforces the daily loss lock (live account only) using the session equity
   baseline.
2) Runs `Timer Entry Handler` each tick to arm stops/TP after fills when
   `$useTimerArming = 1`.
3) Clears take-profit alerts and dynamic stop state when flat.

Installation: add this script to DAS Trader's timer so it runs every second.
It is not installed automatically by the hotkey build. Ensure
`hotkeys/timer_entry_handler.das` is included in your keymap because the timer
calls it via `ExecHotkey`.

## UTILITIES & TOGGLES

These scripts handle configuration, safety toggles, and convenience actions.
The SIM/LIVE mode hotkeys read the account from the Primary_OE montage and set
your account context accordingly so your entries and guards apply to the correct
account. Use them at the start of a session (and when switching environments)
to avoid sending orders to the wrong account.

Safety toggles:
- `toggle_stp_feature.das` and `toggle_tp_feature.das` enable/disable auto stops
  and take-profit alerts.
- `toggle_spread_check_feature.das` enables/disables the spread safety guard.
- `toggle_dynamic_stop.das` enables/disables dynamic R for Buy IB entries.

Account and session:
- `set_global_variables.das` refreshes all global settings and initializes the
  session equity baseline.
- `switch_to_sim.das` and `switch_to_live.das` set the Primary_OE account.
- `initialize_session_equity.das` and `reset_starting_equity.das` manage the
  daily-loss baseline.
- `session_max_loss_check.das` and `check_pnl.das` report session status.

Order control:
- `cancel_all.das` cancels working orders and re-arms stops; 
  `cancel_all_no_stops.das` cancels without re-arming.
- `gtfo.das` attempts an aggressive limit exit for the full position.

UI and convenience:
- `show_config.das` displays current globals and account mode.
- `select_primary_order_entry.das` focuses the Primary_OE montage.
- `toggle_position_window.das` opens/closes the DAS Position window.

## OTHER NOTES

### Script-induced latency

Fast entry and exit are important to my strategy, so reducing latency matters.
These scripts still introduce small delays because they wait to confirm fills
and enforce guard rails. With `$useTimerArming = 1`, entry hotkeys return
immediately, but stops/TP are armed on the next timer tick, so there can be a
brief unprotected window (up to ~1 second plus DAS processing). Set
`$useTimerArming = 0` and tune `$pollMs` and `$maxPolls` if you prefer inline
polling and more immediate protection.

### Waiting for fills on buy orders

When `$useTimerArming = 1`, the timer handler waits for a position to appear
before arming stops/TP. When `$useTimerArming = 0`, buy orders poll for fills
and can accept partials based on `$acceptPartial` and `$minFillShares`. If the
fill criteria are not met in time, the order is canceled and the script exits
without arming stops.

Both modes intentionally wait for a fill before arming protection to avoid
mismatched AvgCost. Bypassing the fill check risks placing protection against a
position that does not exist yet, or against a partial fill that later changes
your average cost. The fill check avoids racing conditions between the order,
the montage position, and AvgCost updates.

### Pre-market / after-hours stops (LIMITP)

Current stop scripts use STOP route and SLP (stop-limit) orders. DAS behavior
for stops outside regular hours can vary by broker. If your broker supports
LIMITP (price-triggered limit orders outside regular hours), it can be an
important safety feature because it allows stop logic to function in the
pre-market and after-hours session, where volatility can be high and liquidity
thin. This is especially relevant for gap moves, news catalysts, and parabolic
setups that can reverse quickly outside the main session.

These scripts submit STOP/SLP orders; whether those behave as LIMITP in
pre-market or after-hours depends on your broker and DAS configuration. If you
trade outside regular hours, verify your broker's behavior and consider a
LIMITP-based workflow tailored to your setup.

