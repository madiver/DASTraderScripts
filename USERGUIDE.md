# USER GUIDE

## OVERVIEW

These scripts are the hotkeys I use in DAS Trader for active, discretionary day trading. They focus on fast, repeatable order entry with guard rails and are designed around a single active symbol at a time. I treat the ice breaker (Buy IB) entries as the first test of a trade thesis; while DAS allows multiple positions, these hotkeys assume one symbol and may behave unpredictably otherwise.

These scripts are designed for LONG positions only. Shorting is not supported.

Repository structure: the `hotkeys/` folder contains the `.das` hotkey scripts, `keymap.yaml` defines the key bindings and metadata, and `other scripts/` contains support scripts like the timer. A `.das` file is plain text you can paste into the DAS Trader Script Editor. The `keymap.yaml` can be compiled into a `Hotkey.htk` using the DAS Hotkey Tools VS Code extension, or you can skip the compiler and copy the scripts manually.

These scripts assume you have a primary montage window named `Primary_OE` (Primary Order Entry). If that montage name does not exist, many scripts will fail or behave incorrectly. You can reference my DAS Trader desktop and chart settings here: https://github.com/madiver/DASTraderConfig

Regardless of the method you choose, the timer script must be installed manually in DAS Trader under "Timer Event Scripts," and the chart script must be installed manually under the chart "Scripting" section (see details below). I also recommend adding `ExecHotKey("Set Global Variables");` to your Desktop Load Scripts so globals are initialized every time DAS starts.

## QUICK START

1) Build or import hotkeys:
   - Use the DAS Hotkey Tools VS Code extension to compile `keymap.yaml` into `Hotkey.htk`, then load it in DAS, or
   - Copy/paste the `.das` scripts into DAS manually.
2) If you use the VS Code extension, set these settings first:
   - `dasHotkeyTools.outputPath` (required).
   - `dasHotkeyTools.liveAccount` and `dasHotkeyTools.simulatedAccount` for `%%LIVE%%` / `%%SIMULATED%%` substitution.
   - Optional: `dasHotkeyTools.placeholders.failOnMissing` to block builds when placeholders are unresolved.
3) Ensure your montage is named `Primary_OE`, the timer script `other scripts/timer.das` is installed under Timer Event Scripts, and the chart script `other scripts/chart_1m.das` is installed as a 1-minute Chart Script.
4) Run `switch_to_sim.das` or `switch_to_live.das` to bind the session account.
5) Run `set_global_variables.das` to initialize globals and the daily-loss baseline.
6) Use `show_config.das` to confirm account mode, defaults, and guard states.

Important: update `$TRSIM` and `$LIVEACT` in `hotkeys/set_global_variables.das` with your actual account identifiers if they are not already populated. `$LIVEACT` is used by the timer for guard rails and `$TRSIM` is shown in the config display. `$applyLiveGuardsToSim` controls whether the live-only guards (daily loss, hijack, rehab) also apply in SIM; it defaults to `1`. Set it to `0` if you want those guards to run only in LIVE. Also verify that any `%%SIMULATED%%` and `%%LIVE%%` placeholders have been replaced in the SIM/LIVE switch and session scripts (the VS Code extension handles this during build; if you copy scripts manually, you must replace them yourself).

By default (`$useTimerArming = 1`), a buy hotkey sends the limit order, records entry context, and returns immediately. A timer-driven handler then waits for a fill and arms stop loss / take profit on subsequent 1-second ticks. If position size increases on later ticks, the handler cancels existing sell orders, re-arms the stop, and only re-arms TP when the TP reset conditions are met. If no fill appears within `$entryMaxTicks`, the handler cancels the working buy order and clears the pending state. If `$useTimerArming = 0`, the buy hotkey polls for a fill up to `$maxPolls * $pollMs`; if nothing fills, the order is canceled and the script exits without arming any protection. If a partial fill meets `$minFillShares`, the remainder is canceled (when enabled) and the scripts proceed as if the trade is active, using the average entry price for subsequent calculations.

Stops are placed as STOP/SLP orders routed to the broker, which means the stop logic lives on the broker side once submitted. Take-profit is implemented with DAS alerts that fire when price reaches the configured R target and then execute the Take Profit hotkey; those alerts are client-side and require DAS to remain open with live data.

## GLOBAL VARIABLES

All core settings live in `hotkeys/set_global_variables.das`. If you change a
value, rerun "Set Global Variables" so the globals refresh in DAS.

Variables by category:

Runtime counters and modes:
- `$oneSecondScriptCnt`: internal counter used by `other scripts/timer.das`.
- `$rehab`: enables rehab mode to block scale-ins and larger entries in LIVE (and SIM when `$applyLiveGuardsToSim = 1`).
- `$HIJACKED_LOCKED`: runtime lock set when hijack protection triggers.
- `$singlePositionSymbol`: runtime symbol tracked by the single-position guard.
- `$trade_ok`: runtime flag set by `Check Global Guards` for buy hotkeys.
- `$testMode`: when set to 1, buy hotkeys exit after non-market guards (no order sent).

Feature toggles and entry guards:
- `$useSlippageMargin`: enables the stop-vs-bid margin check in buy scripts.
- `$slipTicksMin`: minimum tick margin for slippage checks.
- `$slipSpreadFrac`: fraction of spread added to the slippage margin.
- `$acceptPartial`: allows partial fills within the polling window.
- `$minFillShares`: minimum shares to accept when partial fills are allowed.
- `$cancelRemainderOnPartial`: cancels the unfilled remainder before arming stops.
- `$usePerTradeRiskCap`: blocks entries if projected net risk to the planned stop exceeds `$riskCapDollars`.
- `$useSpreadCheck`: enables spread-vs-R safety checks before entries.
- `$pegToBid`: when enabled, BE limit sells can peg to bid instead of AvgCost.
- `$hijackProtection`: enables the position-size hijack backstop (LIVE, and SIM when `$applyLiveGuardsToSim = 1`).
- `$applyLiveGuardsToSim`: when set to 1 (default), apply daily loss, hijack, and rehab guards in SIM.
- `$singlePositionGuard`: when set to 1 (default), block new entries on a different symbol (script-tracked).
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
- `$takeProfitSizeRehab`: TP fraction when rehab is active (LIVE; SIM when `$applyLiveGuardsToSim = 1`).

Dynamic stop settings (buy_ib only):
- `$stopMode`: selects stop logic ("STANDARD", "DYNAMIC", or "STRUCTURED").
- `$dynamicStop`: enables spread-based R for buy IB entries.
- `$dynamicStopMult`: multiplier for the spread-based R.
- `$dynamicStopActive`: runtime flag set when a dynamic trade is active.
- `$dynamicStopR`: stored dynamic R used for stops and TP during the trade.

Structured stop settings (buy_ib only):
- `$structuredMaxLookback`: max bars to scan for the impulse.
- `$structuredMaxPullback`: max bars to evaluate the pullback.
- `$structuredBuffer`: stop buffer below the rejection/pullback low.
- `$structuredMaxStop`: max allowed stop distance (R).
- `$structuredMinImpulse`: minimum impulse body size.
- `$structuredMinClearance`: minimum clearance above stop.
- `$structuredMicroTolPct`: micro pullback tolerance (fraction of impulse body).
- `$structuredMicroTolMax`: cap for micro tolerance (absolute).
- `$structuredMicroExt`: max extension above impulse high before abort.
- `$structuredOk`: last structured validation result (1=pass, 0=fail).
- `$structuredReason`: last structured failure code.
- `$structuredType`: `"MICROPB"` or `"STDPB"` on pass.
- `$structuredStop`: last structured stop price.
- `$structuredR`: last structured R distance.
- `$structuredSymbol`: symbol used for the last structured check.

Account tokens:
- `$TRSIM`: SIM account identifier.
- `$LIVEACT`: LIVE account identifier.

Sizing and risk limits:
- `$qtyMult`: position size multiplier.
- `$maxPositionSize`: maximum total position size in shares.
- `$riskCapDollars`: maximum projected net risk per trade in dollars.
- `$maxDailyLoss`: daily loss lock threshold (equity drawdown; auto-unlocks when drawdown falls back below the limit).

Order fill polling:
- `$pollMs`: polling interval in milliseconds.
- `$maxPolls`: maximum number of polls before canceling an unfilled order.
  These are used when `$useTimerArming = 0`.

Timer-based entry arming (runtime):
- `$entryPending`, `$entryStage`, `$entryTicks`, `$entryMaxTicks`: timer state and timeout for arming stops/TP after fills. When the timeout is reached, the handler cancels the working buy order.
- `$entrySymbol`, `$entryPosBefore`, `$entryAvgBefore`, `$entryScaleIn`, `$entryDynR`: captured entry context used by the timer handler.
- `$entryRefPx`: entry reference price used as a fallback for stop placement when AvgCost lags.
- `$entryWatch`, `$entryLastPos`: track position size changes so the handler can re-arm stops/TP when size increases.

### Defaults table

Defaults are pulled from `hotkeys/set_global_variables.das` and reflect the
baseline values when you run "Set Global Variables."

| Category | Variable | Default |
| --- | --- | --- |
| Runtime | `$oneSecondScriptCnt` | `0` |
| Runtime | `$rehab` | `0` |
| Runtime | `$useTimerArming` | `1` |
| Runtime | `$timerMode` | `1` |
| Runtime | `$entryPending` | `0` |
| Runtime | `$entryStage` | `0` |
| Runtime | `$entryTicks` | `0` |
| Runtime | `$entryMaxTicks` | `10` |
| Runtime | `$entryPosBefore` | `0` |
| Runtime | `$entryAvgBefore` | `0` |
| Runtime | `$entryScaleIn` | `0` |
| Runtime | `$entryDynR` | `0` |
| Runtime | `$entrySymbol` | `""` |
| Runtime | `$tpSymbol` | `""` |
| Runtime | `$entryRefPx` | `0` |
| Runtime | `$HIJACKED_LOCKED` | `0` |
| Runtime | `$singlePositionSymbol` | `""` |
| Runtime | `$trade_ok` | `1` |
| Runtime | `$testMode` | `0` |
| Runtime | `$entryWatch` | `0` |
| Runtime | `$entryLastPos` | `0` |
| Toggles | `$useSlippageMargin` | `1` |
| Toggles | `$slipTicksMin` | `2` |
| Toggles | `$slipSpreadFrac` | `0.25` |
| Toggles | `$acceptPartial` | `1` |
| Toggles | `$minFillShares` | `1` |
| Toggles | `$cancelRemainderOnPartial` | `1` |
| Toggles | `$usePerTradeRiskCap` | `1` |
| Toggles | `$useSpreadCheck` | `1` |
| Toggles | `$pegToBid` | `0` |
| Toggles | `$hijackProtection` | `1` |
| Toggles | `$applyLiveGuardsToSim` | `1` |
| Toggles | `$singlePositionGuard` | `1` |
| Toggles | `$useAutoStop` | `"Yes"` |
| Toggles | `$useTakeProfit` | `"Yes"` |
| Toggles | `$resetStopOnCancel` | `"Yes"` |
| Risk | `$entryOffset` | `0.03` |
| Risk | `$exitOffset` | `0.10` |
| Risk | `$stopLossTrigger` | `0.10` |
| Risk | `$takeProfitFactor` | `1.0` |
| Risk | `$takeProfitSize` | `0.25` |
| Risk | `$takeProfitSizeRehab` | `0.50` |
| Dynamic stop | `$dynamicStop` | `0` |
| Dynamic stop | `$stopMode` | `"STANDARD"` |
| Dynamic stop | `$dynamicStopMult` | `2` |
| Dynamic stop | `$dynamicStopActive` | `0` |
| Dynamic stop | `$dynamicStopR` | `0` |
| Structured stop | `$structuredMaxLookback` | `5` |
| Structured stop | `$structuredMaxPullback` | `3` |
| Structured stop | `$structuredBuffer` | `0.05` |
| Structured stop | `$structuredMaxStop` | `0.40` |
| Structured stop | `$structuredMinImpulse` | `0.15` |
| Structured stop | `$structuredMinClearance` | `0.05` |
| Structured stop | `$structuredMicroTolPct` | `0.25` |
| Structured stop | `$structuredMicroTolMax` | `0.10` |
| Structured stop | `$structuredMicroExt` | `0.10` |
| Structured stop | `$structuredOk` | `0` |
| Structured stop | `$structuredReason` | `0` |
| Structured stop | `$structuredType` | `""` |
| Structured stop | `$structuredStop` | `0` |
| Structured stop | `$structuredR` | `0` |
| Structured stop | `$structuredSymbol` | `""` |
| Accounts | `$TRSIM` | `"%%SIMULATED%%"` |
| Accounts | `$LIVEACT` | `"%%LIVE%%"` |
| Sizing | `$qtyMult` | `6` |
| Sizing | `$maxPositionSize` | `500` |
| Limits | `$riskCapDollars` | `100.00` |
| Limits | `$maxDailyLoss` | `100.00` |
| Polling | `$pollMs` | `100` |
| Polling | `$maxPolls` | `20` |
| Guard | `$DAY_GUARD_OK` | `0` |

`Set Global Variables` also runs `Initialize Session Equity` to seed the daily
loss baseline used by the timer script. The session account (`$DAY_ACC`) is set
by the SIM/LIVE switch hotkeys, so run those at the start of a session to bind
the guard rails to the correct account.

Test mode: set `$testMode = 1` to run buy hotkeys through non-market guard
checks only (no order is sent). Use this for off-hours validation of lock
states and guard logic. Test mode and the test toggles are SIM-only.

Use "Show Config" to view the current runtime values.

## KEY BINDINGS

Key bindings are sourced from `keymap.yaml`. I primarily use these with a
Stream Deck, so bindings can be arbitrarily long because the Stream Deck lets
me send complex keystrokes with a single button press. If you are using a
keyboard, you will almost certainly want to modify the bindings to your
liking. "Unbound" means the script is not assigned to a hotkey in the current
map, and those entries are primarily intended for internal use by other
scripts rather than direct invocation.

| Key binding | Script | Description |
| --- | --- | --- |
| `Ctrl+Shift+Q` | `hotkeys/cancel_all.das` | Cancel orders, clear TP alerts, re-arm stops. |
| `Alt+Ctrl+Q` | `hotkeys/gtfo.das` | Emergency exit: cancel orders, sell full at bid-0.50. |
| `Ctrl+,` | `hotkeys/set_global_variables.das` | Load defaults and initialize session equity. |
| `Alt+Ctrl+S` | `hotkeys/switch_to_sim.das` | Switch montage and filters to SIM. |
| `Alt+Ctrl+L` | `hotkeys/switch_to_live.das` | Switch montage and filters to LIVE. |
| `Alt+Ctrl+.` | `hotkeys/show_config.das` | Show current globals, account mode, guard states. |
| Unbound | `hotkeys/check_global_guards.das` | Run guard checks and set `$trade_ok`. |
| Unbound | `hotkeys/cancel_all_no_stops.das` | Cancel orders and TP alerts without re-arming stops. |
| `Ctrl+Shift+1` | `hotkeys/buy_ib_bid_plus_sl.das` | Ice breaker buy at bid + offset with auto stop/TP. |
| `Ctrl+Shift+2` | `hotkeys/buy_25_bid_plus_sl.das` | Half-clip buy at bid + offset with auto stop/TP. |
| `Ctrl+Shift+3` | `hotkeys/buy_50_bid_plus_sl.das` | Full-clip buy at bid + offset with auto stop/TP. |
| `Alt+Ctrl+1` | `hotkeys/buy_ib_bid_sl.das` | Ice breaker buy at bid with auto stop/TP. |
| `Alt+Ctrl+2` | `hotkeys/buy_25_bid_sl.das` | Half-clip buy at bid with auto stop/TP. |
| `Alt+Ctrl+3` | `hotkeys/buy_50_bid_sl.das` | Full-clip buy at bid with auto stop/TP. |
| `Alt+Shift+1` | `hotkeys/buy_ib_ask_sl.das` | Ice breaker buy at ask with auto stop/TP. |
| `Alt+Shift+2` | `hotkeys/buy_25_ask_sl.das` | Half-clip buy at ask with auto stop/TP. |
| `Alt+Shift+3` | `hotkeys/buy_50_ask_sl.das` | Full-clip buy at ask with auto stop/TP. |
| `Alt+Ctrl+Shift+1` | `hotkeys/buy_ib_ask_plus_sl.das` | Ice breaker buy at ask + offset with auto stop/TP. |
| `Alt+Ctrl+Shift+2` | `hotkeys/buy_25_ask_plus_sl.das` | Half-clip buy at ask + offset with auto stop/TP. |
| `Alt+Ctrl+Shift+3` | `hotkeys/buy_50_ask_plus_sl.das` | Full-clip buy at ask + offset with auto stop/TP. |
| `Ctrl+A` | `hotkeys/sell_1_1_ask.das` | Sell full position at ask. |
| `Ctrl+S` | `hotkeys/sell_1_2_ask.das` | Sell half position at ask. |
| `Ctrl+D` | `hotkeys/sell_1_4_ask.das` | Sell quarter position at ask. |
| `Ctrl+Z` | `hotkeys/sell_1_1_bid.das` | Sell full position at bid minus offset. |
| `Ctrl+X` | `hotkeys/sell_1_2_bid.das` | Sell half position at bid minus offset. |
| `Ctrl+C` | `hotkeys/sell_1_4_bid.das` | Sell quarter position at bid minus offset. |
| `Ctrl+Shift+S` | `hotkeys/set_auto_stop.das` | Place 1R stop-limit for full position. |
| `Ctrl+Shift+B` | `hotkeys/set_auto_stop_be_1_1.das` | Breakeven stop/limit for full position. |
| Unbound | `hotkeys/set_auto_stop_be_scale_1_1.das` | Scale-in BE stop/limit for full position. |
| Unbound | `hotkeys/structured_stop_validate.das` | Structured stop validation (internal). |
| `Alt+Ctrl+Win+-` | `hotkeys/set_0_10_stop.das` | Set 1R stop-loss trigger to $0.10. |
| `Alt+Ctrl+Win+=` | `hotkeys/set_0_15_stop.das` | Set 1R stop-loss trigger to $0.15. |
| `Alt+Ctrl+Win+[` | `hotkeys/set_0_20_stop.das` | Set 1R stop-loss trigger to $0.20. |
| `Alt+Ctrl+Win+0` | `hotkeys/set_0_05_stop.das` | Set 1R stop-loss trigger to $0.05. |
| `Alt+Ctrl+B` | `hotkeys/set_auto_stop_be_1_2.das` | Breakeven stop/limit for half position. |
| `Ctrl+Shift+T` | `hotkeys/set_take_profit.das` | Create R-based take-profit alert. |
| Unbound | `hotkeys/take_profit_executor.das` | Execute TP partial when alert fires. |
| `Alt+Ctrl+Win+1` | `hotkeys/select_primary_order_entry.das` | Focus the Primary_OE montage. |
| `Alt+Ctrl+Win+P` | `hotkeys/toggle_position_window.das` | Toggle Positions windows AlwaysOnTop. |
| `Alt+Ctrl+Win+]` | `hotkeys/toggle_stp_feature.das` | Toggle auto stop-loss feature. |
| `Alt+Ctrl+Win+/` | `hotkeys/toggle_tp_feature.das` | Toggle take-profit alerts. |
| `Alt+Ctrl+Win+'` | `hotkeys/toggle_spread_check_feature.das` | Toggle spread safety guard. |
| `Ctrl+Alt+Win+D` | `hotkeys/enable_dynamic_stop_mode.das` | Enable dynamic stop mode (Buy IB only). |
| `Ctrl+Alt+Win+F` | `hotkeys/enable_standard_stop_mode.das` | Enable standard (fixed R) stop mode. |
| `Alt+Ctrl+Win+S` | `hotkeys/enable_structured_stop_mode.das` | Enable structured stop mode (IB only). |
| `Alt+Ctrl+Win+G` | `hotkeys/toggle_apply_live_guards_to_sim.das` | Toggle live-only guards in SIM. |
| `Alt+Ctrl+Win+M` | `hotkeys/toggle_single_position_guard.das` | Toggle single-symbol entry guard. |
| `Alt+Ctrl+Win+T` | `hotkeys/toggle_test_mode.das` | Toggle test mode (no order sends). |
| `Alt+Ctrl+Shift+Win+1` | `hotkeys/toggle_test_daily_loss_guard.das` | Toggle daily loss guard test. |
| `Alt+Ctrl+Shift+Win+2` | `hotkeys/toggle_test_hijack_guard.das` | Toggle hijack guard test. |
| `Alt+Ctrl+Shift+Win+3` | `hotkeys/toggle_test_single_position_guard.das` | Toggle single-position guard test. |
| `Alt+Ctrl+Shift+Win+4` | `hotkeys/toggle_test_pending_entry_guard.das` | Toggle pending-entry guard test. |
| `Alt+Ctrl+Shift+Win+5` | `hotkeys/toggle_test_max_position_guard.das` | Toggle max-position guard test. |
| `Alt+Ctrl+Win+H` | `hotkeys/enable_rehab_mode.das` | Toggle rehab mode (YES to disable). |
| Unbound | `hotkeys/hijack_exit.das` | Hijack guard exit/lock enforcement (timer-only). |
| Unbound | `hotkeys/timer_entry_handler.das` | Timer-driven stop/TP arming for entries. |
| Unbound | `hotkeys/initialize_session_equity.das` | Initialize daily-loss baseline for account. |
| `Alt+Ctrl+E` | `hotkeys/session_max_loss_check.das` | Set manual starting equity baseline. |
| `Alt+Ctrl+P` | `hotkeys/check_pnl.das` | Show session equity, PnL, and lock state. |
| `Alt+Ctrl+U` | `hotkeys/reset_starting_equity.das` | Reset starting equity baseline (confirm YES). |

## BUY ORDERS

Sizing philosophy: start small to probe the trade, add only when it is working, and cap exposure with hard limits. Base sizing is a 50-share clip multiplied by `$qtyMult`. Buy 25 uses half of that clip, Buy 50 uses the full clip, and Buy IB (ice breaker) uses roughly one quarter of the 50-share clip (rounded to 5-share lots). This keeps the sizing deterministic and proportional to your 1R risk. In rehab mode (`$rehab = 1`), trading is restricted to ice breaker entries and scale-ins are blocked in LIVE and SIM when `$applyLiveGuardsToSim = 1`.

Rehab mode is a safety throttle for live trading. When enabled (`$rehab = 1`), the scripts block scale-ins and prevent larger clip entries in live accounts, forcing you to trade only ice breaker size while you reset discipline or reduce risk after a drawdown. The same restrictions apply in SIM when `$applyLiveGuardsToSim = 1` (default). You can set the default by changing `$rehab` in `hotkeys/set_global_variables.das` and re-running "Set Global Variables" (or restarting DAS), or toggle it for the current session using the `Toggle Rehab Mode` hotkey. Disabling rehab requires typing `YES` to confirm.

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
  `$stopLossTrigger` for normal trades. Buy IB uses dynamic R when enabled; buy_25/buy_50 use dynamic R only when `dynamicStop = 1` and `dynamicStopActive = 1`, otherwise `$stopLossTrigger`.
- When adding to a position, the scripts arm the scale-in BE stop
  (`Set Auto Stop BE Scale 1/1`) so the combined position is protected.
- Rehab mode (`$rehab = 1`) blocks scale-ins entirely in LIVE and SIM when `$applyLiveGuardsToSim = 1`.
- Entries are rejected if `$maxPositionSize` or the net risk to the planned stop
  would exceed `$riskCapDollars` after the add.
- Spread safety checks and slippage margins guard entries before an order is
  sent.

### Single-position guard

When `$singlePositionGuard = 1` (default), buy hotkeys only allow one active
symbol at a time. If `$singlePositionSymbol` is set, new entries on a different
symbol are blocked. The guard also blocks when `$entryPending = 1` for another
symbol (timer staging), so you cannot start a second entry while a buy is still
waiting to fill. The pending-entry block clears when the pending entry times
out/cancels, or when the original symbol is back in Primary_OE and the position
is flat. If you switch the montage to a different symbol while an entry is
pending, the timer cancels the working buy and clears the pending state to
avoid unprotected fills.

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
They do not check `$useAutoStop`, so BE hotkeys (and TP-driven BE adjustments)
still work even when automatic stops are disabled.

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
reference price (`$entryRefPx`) or last price if AvgCost is lagging. It cancels
existing sell orders for the symbol before placing the new stop, except when
invoked in timer mode (`$timerMode`) where cancels are skipped.

When dynamic stops are inactive, the stop-limit offset uses `$exitOffset`. The
order is snapped to valid tick sizes and sent as a STOP/SLP order.

### Dynamic stop losses (experimental)

Dynamic stops are only supported for Buy IB entries due to the
added risk of spread-based sizing, and they only activate when
`$dynamicStop == 1`. They are intended for parabolic movers where spreads and
intraday swings expand sharply as price accelerates.

The stop engine now uses `$stopMode` ("STANDARD", "DYNAMIC", or "STRUCTURED") as
the selector; `enable_dynamic_stop_mode.das` and
`enable_standard_stop_mode.das` keep `$stopMode` in sync with `$dynamicStop`.
`STRUCTURED` uses the structured stop price (`$structuredStop`) and distance
(`$structuredR`) when present.

- R is computed once at order send: `R = spread * $dynamicStopMult`.
- R is fixed for the life of the trade and reused for scale-ins.
- The stop trigger uses the dynamic R.
- Adaptive stop-limit offsets are used only when a dynamic stop is active; the
  offset is derived from the live spread at stop placement and capped by an
  internal maximum.
- When `$dynamicStop = 1`, initial entries must use Buy IB; `buy_25_*` and
  `buy_50_*` only allow scale-ins.
- Dynamic state is cleared when flat by the timer script.

### Structured stop losses (experimental)

Structured stops are enabled when `$stopMode = "STRUCTURED"`
and require the `Chart_1m` window running `other scripts/chart_1m.das` so live
candle values are available. The structured validator computes a stop price
from a 1-minute impulse/pullback pattern and stores it in `$structuredStop`.

- Only Buy IB entries can open a new position in structured mode.
- Buy 25/50 hotkeys are allowed only for scale-ins (and require `$structuredR`).
- If structured data is missing at entry time, the entry is aborted.
- The stop engine uses `$structuredStop`, and TP distance uses `$structuredR`.
Mechanics summary:
- The validator first looks for a bullish impulse on the prior 1-minute bar
  (bar -1), requiring a green candle with body >= `$structuredMinImpulse` and
  dominance vs the previous bar (body > bar -2 body).
- If a valid impulse is found, it attempts a MICROPB pullback using live
  `$CURR_*` values: price must not dip below the impulse high by more than the
  bounded tolerance (`$structuredMicroTolPct` capped by `$structuredMicroTolMax`)
  and must not extend above the impulse high by more than `$structuredMicroExt`.
  The stop is anchored to the live rejection low minus `$structuredBuffer`.
- If the micro conditions fail, the validator falls back to a STDPB pullback:
  it scans back up to `$structuredMaxLookback` bars for a bullish impulse that
  dominates the next `$structuredMaxPullback` bars, then sets the stop below the
  lowest pullback low (minus `$structuredBuffer`).
- The candidate stop is rejected if price is already below it, clearance is
  below `$structuredMinClearance`, or the stop distance exceeds `$structuredMaxStop`.

## TAKE PROFIT

Take-profit is implemented as a DAS price alert that triggers an execution
hotkey. It is not a resting broker-side order.

`Set Take Profit` builds the alert using an R-based distance:
- Distance is `R * $takeProfitFactor`.
- R is `$stopLossTrigger` for normal trades or dynamic R when active.
- The alert watches last sale and fires above the target for longs.

When the alert fires, `Take Profit Executor`:
- Cancels existing sell orders for the symbol.
- Sells a partial position sized by `$takeProfitSize` (or `$takeProfitSizeRehab` when rehab is active in LIVE, and in SIM when `$applyLiveGuardsToSim = 1`).
- Re-arms stops and (if needed) re-establishes the TP alert after the fill.

Stale take-profit alerts are cleaned up by the timer script a few seconds after
the position is flat.

## OTHER GUARD RAILS

These controls help prevent low-quality fills and oversized risk.

- Spread checks: reject entries when spread is too large relative to R
  (`$useSpreadCheck`).
- Slippage margin: requires the planned stop to sit below bid by a minimum
  tick/spread buffer (`$useSlippageMargin`, `$slipTicksMin`, `$slipSpreadFrac`).
- Max daily loss: a daily lock prevents new entries while equity drawdown is at
  or above the threshold (`$maxDailyLoss`) and auto-unlocks when drawdown drops
  back below the limit. The lock is enforced by the timer script and is only
  evaluated when Primary_OE is flat, after a 2-tick settle delay to allow equity
  to update.
  Limitations: the guard uses a stored starting equity snapshot and compares it
  to the account's current Equity value. If DAS restarts or crashes mid-session,
  the baseline may be stale until you run `Reset Starting Equity` or `Set Start Equity`.
  Equity can include unrealized PnL and may lag the account window briefly, so
  the guard is a best-effort safety backstop rather than an exact match to your
  realized PnL at every moment.
- Hijack protection: if the position size exceeds `$maxPositionSize` (LIVE, and
  SIM when `$applyLiveGuardsToSim = 1`), the timer triggers GTFO, locks all
  montage order buttons, and sets `$HIJACKED_LOCKED` to block new buys. The lock
  clears only after restarting DAS or re-running `Set Global Variables`, and
  montage unlock is manual.
- Single-position guard: when `$singlePositionGuard = 1`, buy hotkeys block
  entries on a different symbol once a position is tracked. This is
  script-tracked using the Primary_OE montage; if you close a position while
  on another symbol, the lock clears when you return to the original symbol or
  re-run `Set Global Variables`. Positions opened or closed outside the hotkeys
  may not be detected until the montage returns to the active symbol.
- Per-trade risk cap: blocks entries when projected risk exceeds
  `$riskCapDollars` (`$usePerTradeRiskCap`).

SIM vs LIVE: daily loss lock, hijack protection, and rehab gating apply in LIVE
and SIM when `$applyLiveGuardsToSim = 1` (default). Set
`$applyLiveGuardsToSim = 0` to keep those three guards live-only. All other
guard rails apply in both SIM and LIVE.

### Hijack protection (position-size backstop)

This is a strict discipline backstop. It is enabled by default via
`$hijackProtection = 1` and continuously compares your position size to
`$maxPositionSize` using the `Primary_OE` montage. It applies to LIVE and to
SIM when `$applyLiveGuardsToSim = 1` (default).

If the timer detects a position larger than `$maxPositionSize`, it:
- Triggers `GTFO` to flatten.
- Locks all montage order buttons via `LockAllMontage Lock`.
- Sets `$HIJACKED_LOCKED` to block new buys.
- Plays a brief voice alert.

Reset behavior:
- `$HIJACKED_LOCKED` clears only after restarting DAS or re-running `Set Global Variables`.
- Montage lock must be manually cleared (UI lock icon or `LockAllMontage Unlock`).

## TIMER SCRIPT

`other scripts/timer.das` does four things:

1) Enforces the daily loss lock for LIVE and SIM when `$applyLiveGuardsToSim = 1`
   (default) using the session equity baseline.
2) Enforces hijack protection on position size (same scope as above).
3) Runs `Timer Entry Handler` each tick to arm stops/TP after fills when
   `$useTimerArming = 1`.
4) Clears take-profit alerts and dynamic stop state when flat.

Installation: add this script to DAS Trader's timer so it runs every second.
It is not installed automatically by the hotkey build. Ensure
`hotkeys/timer_entry_handler.das` is included in your keymap because the timer
calls it via `ExecHotkey`.

## CHART SCRIPT (1-MINUTE)

`other scripts/chart_1m.das` captures the current 1-minute candle's live values
and exposes them as globals for other scripts. It is not installed automatically
by the hotkey build.

Installation: add this script to DAS Trader's chart "Scripting" section and bind
it to a 1-minute chart that follows your active symbol (only one chart should
run it at a time).

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
- `enable_dynamic_stop_mode.das` sets dynamic R for Buy IB entries (and disables standard mode).
- `enable_standard_stop_mode.das` sets fixed R stops and disables dynamic mode.
- `enable_structured_stop_mode.das` sets structured stop mode (IB only).
- `toggle_apply_live_guards_to_sim.das` toggles whether live-only guards also
  apply in SIM (`$applyLiveGuardsToSim`).
- `toggle_single_position_guard.das` toggles the single-position guard
  (`$singlePositionGuard`).
- `toggle_test_mode.das` toggles test mode (`$testMode`) for off-hours guard checks.
- `toggle_test_daily_loss_guard.das` toggles a daily loss guard test using
  `DAY_EQUITY_START` (requires `$testMode = 1`).
- `toggle_test_hijack_guard.das` toggles a hijack-guard test by lowering
  `maxPositionSize` (requires `$testMode = 1` and an open position).
- `toggle_test_single_position_guard.das` toggles a simulated active symbol for
  the single-position guard (requires `$testMode = 1`).
- `toggle_test_pending_entry_guard.das` toggles a simulated pending entry for
  the guard (requires `$testMode = 1` and a flat position).
- `toggle_test_max_position_guard.das` toggles a max-position guard test by
  setting `maxPositionSize` to the current position (requires `$testMode = 1`
  and an open position).
- `enable_rehab_mode.das` toggles rehab mode on/off; disabling requires typing `YES`.

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
- `toggle_position_window.das` toggles AlwaysOnTop for the DAS Position windows.

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
before arming stops/TP. If position size increases on later ticks, the handler
cancels existing sell orders, re-arms the stop, and only re-arms TP when the TP
reset conditions are met. If no fill appears within `$entryMaxTicks`, the handler
cancels the working buy order and clears pending state. When `$useTimerArming = 0`,
buy orders poll for fills and can accept partials based on `$acceptPartial` and
`$minFillShares`. If the fill criteria are not met in time, the order is canceled
and the script exits without arming stops.

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

