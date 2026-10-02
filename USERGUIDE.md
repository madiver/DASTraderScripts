# USER GUIDE

## OVERVIEW

These scripts are the hotkeys I use in DAS Trader for active, discretionary day trading. They focus on fast, repeatable order entry with guard rails and are designed around a single active symbol at a time. I treat the micro ice breaker and ice breaker (Buy MIB/IB) entries as the first tests of a trade thesis; while DAS allows multiple positions, these hotkeys assume one symbol and may behave unpredictably otherwise.

The automated entry-protection workflow is designed for LONG positions only. Fourteen isolated manual hotkeys support Tier 1–4 shorts at Ask or Bid and full, half, or quarter covers at Bid or Ask plus the exit offset; they do not arm stop loss, take profit, or timer handling.

Repository structure: the `hotkeys/` folder contains the `.das` hotkey scripts, `keymap.yaml` defines the key bindings and metadata, and `other scripts/` contains support scripts like the timer. A `.das` file is plain text you can paste into the DAS Trader Script Editor. The `keymap.yaml` can be compiled into a `Hotkey.htk` using the DAS Hotkey Tools VS Code extension, or you can skip the compiler and copy the scripts manually.

These scripts assume you have a primary montage window named `Primary_OE` (Primary Order Entry) and a chart window named `Primary_Chart`. If that montage name does not exist, many scripts will fail or behave incorrectly. The chart name is used for symbol synchronization. You can reference my DAS Trader desktop and chart settings here: https://github.com/madiver/DASTraderConfig

Regardless of the method you choose, the timer script must be installed manually in DAS Trader under "Timer Event Scripts," and the chart script must be installed manually under the chart "Scripting" section (see details below). I also recommend adding `ExecHotKey("Set Global Variables");` to your Desktop Load Scripts so globals are initialized every time DAS starts.

## QUICK START

1) Build or import hotkeys:
   - Use the DAS Hotkey Tools VS Code extension to compile `keymap.yaml` into `Hotkey.htk`, then load it in DAS, or
   - Copy/paste the `.das` scripts into DAS manually.
2) If you use the VS Code extension, set these settings first:
   - `dasHotkeyTools.outputPath` (required).
   - `dasHotkeyTools.liveAccount` and `dasHotkeyTools.simulatedAccount` for `%%LIVE%%` / `%%SIMULATED%%` substitution.
   - Optional: `dasHotkeyTools.placeholders.failOnMissing` to block builds when placeholders are unresolved.
3) Ensure your montage is named `Primary_OE`, the timer script `other scripts/timer.das` is installed under Timer Event Scripts, and the chart used for symbol synchronization is named `Primary_Chart`.
4) Run `switch_to_sim.das` or `switch_to_live.das` to set the montage account and filters.
5) Run `set_global_variables.das` to initialize globals.
6) Use `show_config.das` to confirm account mode, defaults, and guard states.

Important: update `$TRSIM` and `$LIVEACT` in `hotkeys/set_global_variables.das` with your actual account identifiers if they are not already populated (they are shown in the config display for reference). Hijack protection defaults to off (`$hijackProtection = 0`); set it to `1` to enable it. `$applyLiveGuardsToSim` controls whether enabled live-only guards (hijack, rehab) also apply in SIM; it defaults to `0`. Set it to `1` to apply those enabled guards in SIM. Also verify that any `%%SIMULATED%%` and `%%LIVE%%` placeholders have been replaced in the SIM/LIVE switch scripts (the VS Code extension handles this during build; if you copy scripts manually, you must replace them yourself).

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
- `$hijackProtection`: enables the position-size hijack backstop (LIVE, and SIM when `$applyLiveGuardsToSim = 1`); defaults to `0` (disabled).
- `$applyLiveGuardsToSim`: when set to 1, apply hijack and rehab guards in SIM; defaults to 0 (live-only).
- `$singlePositionGuard`: when set to 1 (default), block new entries on a different symbol (script-tracked).
- `$useAutoStop`: toggles auto stop placement.
- `$useTakeProfit`: toggles take-profit alerts/executor behavior.
- `$resetStopOnCancel`: re-arms the stop after `cancel_all.das` if long.
- `$useTimerArming`: uses timer-based entry arming (1) or inline polling (0).

Risk and execution:
- `$entryBidOffset` / `$entryAskOffset`: independent signed offsets for Bid+ / Ask+ buy scripts (defaults: BID `+0.01`, ASK `-0.01`). Negative values price below the corresponding reference quote.
- `$exitOffset`: aggression offset for Bid- long exits and Ask+ short covers, and the limit offset for fixed stops.
- `$orderRoute`: limit order route for entries/exits (buys/sells/TP/BE). Default is `ARCA1L`. `FREE1L` is the free route for ST Global Market/Open Ocean.
- `$gtfoRoute`: emergency exit route for GTFO/backstop/hijack exits. Default is `FLSH1L` (Open Ocean broadcast route).
- `$stopLossTrigger`: fixed 1R risk per share for all buy tiers.
- `$backstopBuffer`: trigger buffer below the stop for the manual backstop alert.
- `$backstopBidOffset`: limit offset from Bid for backstop exits.
- `$backstopMaxRetries`: max retry attempts for backstop exits when still not flat.
- `$takeProfitFactor`: R multiple for take-profit alerts.
- `$takeProfitSize`: fraction of the position to sell on a TP trigger.
- `$takeProfitSizeRehab`: TP fraction when rehab is active (LIVE; SIM when `$applyLiveGuardsToSim = 1`).

Account tokens:
- `$TRSIM`: SIM account identifier.
- `$LIVEACT`: LIVE account identifier.

Sizing and risk limits:
- `$qtyMult`: shared multiplier applied to all four tier base sizes.
- `$tier1ShareSize`: micro ice breaker entry size.
- `$tier2ShareSize`: ice breaker entry size.
- `$tier3ShareSize`: entry size for the legacy `buy_25_*` script family.
- `$tier4ShareSize`: entry size for the legacy `buy_50_*` script family.
- `$maxPositionSize`: maximum total position size, calculated as `round($tier4ShareSize * $qtyMult)`.
- `$riskCapDollars`: maximum projected net risk per trade in dollars.

Order fill polling:
- `$pollMs`: polling interval in milliseconds.
- `$maxPolls`: maximum number of polls before canceling an unfilled order.
  These are used when `$useTimerArming = 0`.

Timer-based entry arming (runtime):
- `$entryPending`, `$entryStage`, `$entryTicks`, `$entryMaxTicks`: timer state and timeout for arming stops/TP after fills. When the timeout is reached, the handler cancels the working buy order.
- `$entrySymbol`, `$entryPosBefore`, `$entryAvgBefore`, `$entryScaleIn`: captured entry context used by the timer handler.
- `$entryRefPx`: entry reference price used as a fallback for stop placement when AvgCost lags.
- `$entryWatch`, `$entryLastPos`: track position size changes so the handler can re-arm stops/TP when size increases.
- `$lastStop`, `$lastStopSymbol`: last stop price/symbol set by auto-stop scripts (used by backstop triggers).
- `$backstopArmed`, `$backstopRetries`, `$backstopStop`, `$backstopSymbol`: runtime backstop state.

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
| Runtime | `$entrySymbol` | `""` |
| Runtime | `$tpSymbol` | `""` |
| Runtime | `$entryRefPx` | `0` |
| Runtime | `$lastStop` | `0` |
| Runtime | `$lastStopSymbol` | `""` |
| Runtime | `$HIJACKED_LOCKED` | `0` |
| Runtime | `$singlePositionSymbol` | `""` |
| Runtime | `$trade_ok` | `1` |
| Runtime | `$testMode` | `0` |
| Runtime | `$entryWatch` | `0` |
| Runtime | `$entryLastPos` | `0` |
| Runtime | `$backstopArmed` | `0` |
| Runtime | `$backstopRetries` | `0` |
| Runtime | `$backstopStop` | `0` |
| Runtime | `$backstopSymbol` | `""` |
| Toggles | `$useSlippageMargin` | `1` |
| Toggles | `$slipTicksMin` | `2` |
| Toggles | `$slipSpreadFrac` | `0.25` |
| Toggles | `$acceptPartial` | `1` |
| Toggles | `$minFillShares` | `1` |
| Toggles | `$cancelRemainderOnPartial` | `1` |
| Toggles | `$usePerTradeRiskCap` | `1` |
| Toggles | `$useSpreadCheck` | `1` |
| Toggles | `$pegToBid` | `0` |
| Toggles | `$hijackProtection` | `0` |
| Toggles | `$applyLiveGuardsToSim` | `0` |
| Toggles | `$singlePositionGuard` | `1` |
| Toggles | `$useAutoStop` | `"Yes"` |
| Toggles | `$useTakeProfit` | `"Yes"` |
| Toggles | `$resetStopOnCancel` | `"Yes"` |
| Risk | `$entryBidOffset` | `0.01` |
| Risk | `$entryAskOffset` | `-0.01` |
| Risk | `$exitOffset` | `0.10` |
| Risk | `$orderRoute` | `"ARCA1L"` |
| Risk | `$gtfoRoute` | `"FLSH1L"` |
| Risk | `$stopLossTrigger` | `0.20` |
| Risk | `$takeProfitFactor` | `1.0` |
| Risk | `$takeProfitSize` | `0.50` |
| Risk | `$takeProfitSizeRehab` | `0.50` |
| Backstop | `$backstopBuffer` | `0.03` |
| Backstop | `$backstopBidOffset` | `0.10` |
| Backstop | `$backstopMaxRetries` | `3` |
| Accounts | `$TRSIM` | `"%%SIMULATED%%"` |
| Accounts | `$LIVEACT` | `"%%LIVE%%"` |
| Sizing | `$qtyMult` | `1.0` |
| Sizing | `$tier1ShareSize` | `100` |
| Sizing | `$tier2ShareSize` | `200` |
| Sizing | `$tier3ShareSize` | `300` |
| Sizing | `$tier4ShareSize` | `500` |
| Sizing | `$maxPositionSize` | `500` (`$tier4ShareSize * $qtyMult`) |
| Limits | `$riskCapDollars` | `2000.00` |
| Polling | `$pollMs` | `100` |
| Polling | `$maxPolls` | `20` |

For manual SIM diagnostics, set `$testMode = 1` to run buy hotkeys through
non-market guard checks only (no order is sent). Set it back to `0` or run
`Set Global Variables` when finished. The dedicated test-toggle hotkeys and
Stream Deck test buttons have been removed.

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
| `Ctrl+Shift+Q` | `hotkeys/cancel_all.das` | Cancel orders and clear TP alerts; re-arm stops only for longs. |
| `Alt+Ctrl+Q` | `hotkeys/gtfo.das` | Emergency exit: long at bid-$0.50 or short at ask+$0.50. |
| `Ctrl+,` | `hotkeys/set_global_variables.das` | Load default globals. |
| `Alt+Ctrl+Shift+5` | `hotkeys/set_qty_mult_0_5.das` | Set the shared tier-size multiplier to 0.5x. |
| `Alt+Ctrl+Shift+6` | `hotkeys/set_qty_mult_1_0.das` | Set the shared tier-size multiplier to 1.0x. |
| `Alt+Ctrl+Shift+7` | `hotkeys/set_qty_mult_2_0.das` | Set the shared tier-size multiplier to 2.0x. |
| `Alt+Ctrl+Shift+8` | `hotkeys/set_qty_mult_3_0.das` | Set the shared tier-size multiplier to 3.0x. |
| `Alt+Ctrl+Shift+9` | `hotkeys/set_qty_mult_1_5.das` | Set the shared tier-size multiplier to 1.5x. |
| `Alt+Ctrl+Shift+Win+6` | `hotkeys/set_bid_entry_offset_minus_3.das` | Set the Bid+ entry offset to -3 cents. |
| `Alt+Ctrl+Shift+Win+5` | `hotkeys/set_bid_entry_offset_minus_2.das` | Set the Bid+ entry offset to -2 cents. |
| `Alt+Ctrl+Shift+Win+7` | `hotkeys/set_bid_entry_offset_minus_1.das` | Set the Bid+ entry offset to -1 cent. |
| `Alt+Ctrl+Shift+Win+8` | `hotkeys/set_bid_entry_offset_plus_1.das` | Restore the default Bid+ entry offset of +1 cent. |
| `Alt+Ctrl+Shift+Win+9` | `hotkeys/set_bid_entry_offset_plus_3.das` | Set the Bid+ entry offset to +3 cents. |
| `Alt+Ctrl+Shift+Win+F6` | `hotkeys/set_ask_entry_offset_minus_3.das` | Set the Ask+ entry offset to -3 cents. |
| `Alt+Ctrl+Shift+Win+F5` | `hotkeys/set_ask_entry_offset_minus_2.das` | Set the Ask+ entry offset to -2 cents. |
| `Alt+Ctrl+Shift+Win+F7` | `hotkeys/set_ask_entry_offset_minus_1.das` | Restore the default Ask+ entry offset of -1 cent. |
| `Alt+Ctrl+Shift+Win+F8` | `hotkeys/set_ask_entry_offset_plus_1.das` | Set the Ask+ entry offset to +1 cent. |
| `Alt+Ctrl+Shift+Win+F9` | `hotkeys/set_ask_entry_offset_plus_3.das` | Set the Ask+ entry offset to +3 cents. |
| `Alt+Ctrl+S` | `hotkeys/switch_to_sim.das` | Switch montage and filters to SIM. |
| `Alt+Ctrl+L` | `hotkeys/switch_to_live.das` | Switch montage and filters to LIVE. |
| `Alt+Ctrl+.` | `hotkeys/show_config.das` | Show current globals, account mode, guard states, and position diagnostics. |
| Unbound | `hotkeys/check_global_guards.das` | Run guard checks and set `$trade_ok`. |
| Unbound | `hotkeys/cancel_all_no_stops.das` | Cancel orders and TP alerts without re-arming stops. |
| `Alt+Ctrl+Shift+Win+0` | `hotkeys/buy_mib_bid_plus_sl.das` | Micro ice breaker buy at bid + offset with auto stop/TP. |
| `Ctrl+Shift+1` | `hotkeys/buy_ib_bid_plus_sl.das` | Ice breaker buy at bid + offset with auto stop/TP. |
| `Ctrl+Shift+2` | `hotkeys/buy_25_bid_plus_sl.das` | Tier 3 buy at bid + offset with auto stop/TP (300 base shares). |
| `Ctrl+Shift+3` | `hotkeys/buy_50_bid_plus_sl.das` | Tier 4 buy at bid + offset with auto stop/TP (500 base shares). |
| `Alt+Ctrl+0` | `hotkeys/buy_mib_bid_sl.das` | Micro ice breaker buy at bid with auto stop/TP. |
| `Alt+Ctrl+1` | `hotkeys/buy_ib_bid_sl.das` | Ice breaker buy at bid with auto stop/TP. |
| `Alt+Ctrl+2` | `hotkeys/buy_25_bid_sl.das` | Tier 3 buy at bid with auto stop/TP (300 base shares). |
| `Alt+Ctrl+3` | `hotkeys/buy_50_bid_sl.das` | Tier 4 buy at bid with auto stop/TP (500 base shares). |
| `Alt+Shift+0` | `hotkeys/buy_mib_ask_sl.das` | Micro ice breaker buy at ask with auto stop/TP. |
| `Alt+Shift+1` | `hotkeys/buy_ib_ask_sl.das` | Ice breaker buy at ask with auto stop/TP. |
| `Alt+Shift+2` | `hotkeys/buy_25_ask_sl.das` | Tier 3 buy at ask with auto stop/TP (300 base shares). |
| `Alt+Shift+3` | `hotkeys/buy_50_ask_sl.das` | Tier 4 buy at ask with auto stop/TP (500 base shares). |
| `Alt+Ctrl+Shift+0` | `hotkeys/buy_mib_ask_plus_sl.das` | Micro ice breaker buy at ask + offset with auto stop/TP. |
| `Alt+Ctrl+Shift+1` | `hotkeys/buy_ib_ask_plus_sl.das` | Ice breaker buy at ask + offset with auto stop/TP. |
| `Alt+Ctrl+Shift+2` | `hotkeys/buy_25_ask_plus_sl.das` | Tier 3 buy at ask + offset with auto stop/TP (300 base shares). |
| `Alt+Ctrl+Shift+3` | `hotkeys/buy_50_ask_plus_sl.das` | Tier 4 buy at ask + offset with auto stop/TP (500 base shares). |
| `Alt+Ctrl+Shift+S` | `hotkeys/short_tier1_ask.das` | Sell short Tier 1 at ask without automatic protection. |
| `Alt+Ctrl+Shift+D` | `hotkeys/short_tier2_ask.das` | Sell short Tier 2 at ask without automatic protection. |
| `Alt+Ctrl+Shift+F` | `hotkeys/short_tier3_ask.das` | Sell short Tier 3 at ask without automatic protection. |
| `Alt+Ctrl+Shift+G` | `hotkeys/short_tier4_ask.das` | Sell short Tier 4 at ask without automatic protection. |
| `Alt+Ctrl+Shift+H` | `hotkeys/short_tier1_bid.das` | Sell short Tier 1 at bid with no offset or automatic protection. |
| `Alt+Ctrl+Shift+J` | `hotkeys/short_tier2_bid.das` | Sell short Tier 2 at bid with no offset or automatic protection. |
| `Alt+Ctrl+Shift+K` | `hotkeys/short_tier3_bid.das` | Sell short Tier 3 at bid with no offset or automatic protection. |
| `Alt+Ctrl+Shift+L` | `hotkeys/short_tier4_bid.das` | Sell short Tier 4 at bid with no offset or automatic protection. |
| `Alt+Ctrl+Shift+C` | `hotkeys/cover_1_1_ask.das` | Cover the full short position at ask plus `$exitOffset` using DAS Reverse. |
| `Alt+Ctrl+Shift+X` | `hotkeys/cover_1_2_ask.das` | Cover half the current position at ask plus `$exitOffset` using DAS Reverse. |
| `Alt+Ctrl+Shift+Z` | `hotkeys/cover_1_4_ask.das` | Cover a quarter of the current position at ask plus `$exitOffset` using DAS Reverse. |
| `Alt+Ctrl+Shift+N` | `hotkeys/cover_1_1_bid.das` | Cover the full position at bid with no offset using DAS Reverse. |
| `Alt+Ctrl+Shift+B` | `hotkeys/cover_1_2_bid.das` | Cover half the position at bid with no offset using DAS Reverse. |
| `Alt+Ctrl+Shift+V` | `hotkeys/cover_1_4_bid.das` | Cover a quarter of the position at bid with no offset using DAS Reverse. |
| `Ctrl+A` | `hotkeys/sell_1_1_ask.das` | Sell full position at ask. |
| `Ctrl+S` | `hotkeys/sell_1_2_ask.das` | Sell half position at ask. |
| `Ctrl+D` | `hotkeys/sell_1_4_ask.das` | Sell quarter position at ask. |
| `Ctrl+Z` | `hotkeys/sell_1_1_bid.das` | Sell full position at bid minus offset. |
| `Ctrl+X` | `hotkeys/sell_1_2_bid.das` | Sell half position at bid minus offset. |
| `Ctrl+C` | `hotkeys/sell_1_4_bid.das` | Sell quarter position at bid minus offset. |
| `Ctrl+Shift+S` | `hotkeys/set_auto_stop.das` | Place 1R stop-limit for full position. |
| `Alt+Ctrl+Win+8` | `hotkeys/set_backstop_trigger.das` | Arm an L1 Bid-based backstop alert for catastrophic exits. |
| Unbound | `hotkeys/backstop_exit_executor.das` | Backstop exit executor (alert-driven). |
| `Ctrl+Shift+B` | `hotkeys/set_auto_stop_be_1_1.das` | Breakeven stop/limit for full position. |
| Unbound | `hotkeys/set_auto_stop_be_scale_1_1.das` | Scale-in BE stop/limit for full position. |
| `Alt+Ctrl+Win+-` | `hotkeys/set_0_10_stop.das` | Set 1R stop-loss trigger to $0.10. |
| `Alt+Ctrl+Win+[` | `hotkeys/set_0_20_stop.das` | Set 1R stop-loss trigger to $0.20. |
| `Alt+Ctrl+Win+=` | `hotkeys/set_0_30_stop.das` | Set 1R stop-loss trigger to $0.30. |
| `Alt+Ctrl+Win+5` | `hotkeys/set_0_50_stop.das` | Set 1R stop-loss trigger to $0.50. |
| `Alt+Ctrl+B` | `hotkeys/set_auto_stop_be_1_2.das` | Breakeven stop/limit for half position. |
| `Ctrl+Shift+T` | `hotkeys/set_take_profit.das` | Create R-based take-profit alert. |
| Unbound | `hotkeys/take_profit_executor.das` | Execute TP partial when alert fires. |
| `Alt+Ctrl+Win+1` | `hotkeys/select_primary_order_entry.das` | Focus the Primary_OE montage. |
| `Alt+Ctrl+Win+P` | `hotkeys/toggle_position_window.das` | Toggle Positions windows AlwaysOnTop. |
| `Alt+Ctrl+Win+]` | `hotkeys/toggle_stp_feature.das` | Toggle auto stop-loss feature. |
| `Alt+Ctrl+Win+/` | `hotkeys/toggle_tp_feature.das` | Toggle take-profit alerts. |
| `Alt+Ctrl+Win+'` | `hotkeys/toggle_spread_check_feature.das` | Toggle spread safety guard. |
| `Alt+Ctrl+Win+G` | `hotkeys/toggle_apply_live_guards_to_sim.das` | Toggle live-only guards in SIM. |
| `Alt+Ctrl+Win+2` | `hotkeys/set_order_route_arcal.das` | Set limit order route to ARCA1L. |
| `Alt+Ctrl+Win+3` | `hotkeys/set_order_route_freel.das` | Set limit order route to FREE1L (free route for ST Global Market/Open Ocean). |
| `Alt+Ctrl+Win+M` | `hotkeys/toggle_single_position_guard.das` | Toggle single-symbol entry guard. |
| `Alt+Ctrl+Win+H` | `hotkeys/enable_rehab_mode.das` | Toggle rehab mode (YES to disable). |
| Unbound | `hotkeys/hijack_exit.das` | Hijack guard exit/lock enforcement (timer-only). |
| Unbound | `hotkeys/timer_entry_handler.das` | Timer-driven stop/TP arming for entries. |

## BUY ORDERS

Sizing philosophy: start small to probe the trade, add only when it is working, and cap exposure with hard limits. The four entry tiers have configurable base sizes of 100 shares for MIB, 200 for IB, 300 for the legacy `buy_25_*` family, and 500 for the legacy `buy_50_*` family. Every entry uses `round(base tier size * $qtyMult)`, where `$qtyMult` defaults to `1.0`. `$maxPositionSize` uses the same calculation with `$tier4ShareSize`, so the position cap always equals one scaled Tier 4 order. In rehab mode (`$rehab = 1`), trading is restricted to MIB/IB entries and scale-ins are blocked in LIVE and SIM when `$applyLiveGuardsToSim = 1`.

Rehab mode is a safety throttle for live trading. When enabled (`$rehab = 1`), the scripts block scale-ins and prevent larger tier entries in live accounts, forcing you to trade only MIB/IB size while you reset discipline or reduce risk after a drawdown. The same restrictions apply in SIM only when `$applyLiveGuardsToSim = 1`; that setting defaults to `0`. You can set the default by changing `$rehab` in `hotkeys/set_global_variables.das` and re-running "Set Global Variables" (or restarting DAS), or toggle it for the current session using the `Toggle Rehab Mode` hotkey. Disabling rehab requires typing `YES` to confirm.

### Configurable entry tiers

The physical and Virtual Stream Deck DAS Trader profiles each have 20 buy,
buy-offset, and short buttons displaying these share counts for each multiplier:

| Multiplier | Tier 1 (MIB) | Tier 2 (IB) | Tier 3 | Tier 4 |
| --- | ---: | ---: | ---: | ---: |
| 0.5x | 50 | 100 | 150 | 250 |
| 1x | 100 | 200 | 300 | 500 |
| 1.5x | 150 | 300 | 450 | 750 |
| 2x | 200 | 400 | 600 | 1,000 |
| 3x | 300 | 600 | 900 | 1,500 |

Button labels show the full share count on its own line when it exceeds three
digits, for example `BUY`, `1500`, and `BID+` on three lines. This changes only
the display; order quantities remain the same.

- `$qtyMult` scales all four base sizes together. Results are rounded to the
  nearest whole share before position-size and risk-cap checks run. Each
  multiplier hotkey also recalculates `$maxPositionSize` from the scaled Tier 4
  size. Use the multiplier preset hotkeys to switch the current session between
  `0.5x`, `1.0x`, `1.5x`, `2.0x`, and `3.0x` without reloading all globals.
- Buy MIB scripts use `$tier1ShareSize` (default 100 shares).
- Buy IB scripts use `$tier2ShareSize` (default 200 shares).
- The `buy_25_*` scripts use `$tier3ShareSize` (default 300 shares), and the
  `buy_50_*` scripts use `$tier4ShareSize` (default 500 shares). Their legacy
  filenames and IDs are retained to avoid breaking existing integrations.
- All buy scripts enforce `$maxPositionSize` and `$riskCapDollars` before
  sending an order.
- Bid+ versions add `$entryBidOffset` to bid; Ask+ versions add
  `$entryAskOffset` to ask. Positive offsets price above the reference quote;
  negative offsets price below it, before tick rounding.
- Each side has presets for `-0.03`, `-0.02`, `-0.01`, `+0.01`, and `+0.03`. Selecting
  a preset changes only that side's offset for subsequent buy entries.
- In the local **DAS Trader** Stream Deck profile, page 4, column 6, the
  Advanced Toggles **BID OFFSET** (row 1) and **ASK OFFSET** (row 2) buttons
  use green and red microchip outlines, respectively, on black backgrounds.
  Both buttons
  independently cycle **-3, -2, -1, +1, +3 cents**. BID defaults to **+1 cent**
  (next press: **+3 cents**); ASK defaults to **-1 cent** (next press: **+1 cent**).
  They use Toggle Groups 3 and 4,
  respectively, independently of the fixed-stop and share-size toggles.
  **LOAD CFG** reloads the default globals and resets BID to **+1 cent** and
  ASK to **-1 cent**.
  Running `Set Global Variables` directly in DAS resets the variables but does
  not update the Stream Deck displays; use **LOAD CFG** to reset both together.
- The first Bid+ button displays **BUY 50 BID+** at `0.5x`; it uses the MIB
  script (100 base shares), not the legacy `buy_25_*` Tier 3 script. All five
  size states of this button must send `Alt+Ctrl+Shift+Win+0`. The plain-Bid
  shortcut `Alt+Ctrl+0` skips the offset regardless of the button's title.

### Scaling-in logic

Scaling in means adding shares after an initial entry once the trade is working
and risk is reduced. These scripts only allow scale-ins when the existing
position has moved at least 1R in your favor.

- The profit gate is measured as `BID - AvgCost >= $stopLossTrigger` for longs.
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

## MANUAL SHORT ORDERS

The initial short workflow is intentionally separate from the automated long
workflow. It uses `$orderRoute` and `DAY+`, but it does not run the long entry
guards or create stop-loss, take-profit, or timer-arming
state. Treat the position as manually managed and verify locate availability,
route behavior, and applicable short-sale restrictions with the broker.

- `Short T1/T2/T3/T4 Ask/Bid` cancels working orders for the montage symbol, then
  sends an explicit sell-short limit order at the selected quote with no offset for
  `round($tierNShareSize * $qtyMult)` shares. Each hotkey can open a short while
  flat or add its tier to an existing short, but aborts if the current position
  is long or its direction cannot be resolved safely.
- `Cover 1/1 Ask+` cancels working orders for the montage symbol, then uses the
  native `Share=Pos; SEND=Reverse` command at `Ask + $exitOffset`. DAS resolves the position
  quantity and direction internally; for a short it sends a buy for the full
  short without adding past flat. If invoked while long, `SEND=Reverse` closes
  the long with a sell, so treat this as a full-position close hotkey.
- `Cover 1/2 Ask+` and `Cover 1/4 Ask+` use the same native Reverse command
  and Ask + `$exitOffset` pricing for half or a quarter of the current position.
  Quantities are calculated after cancelling older orders, rounded down to
  whole shares, and clamped to at least one share and at most the current position.
  They do nothing while flat and abort if the montage account or symbol changes.
  Like Cover 1/1, they reduce a long if invoked while long.
  On page 3 of both Stream Deck profiles, the buttons are arranged
  Cover 1/4, Cover 1/2, Cover 1/1 from left to right.
- `Cover 1/1 Bid`, `Cover 1/2 Bid`, and `Cover 1/4 Bid` use plain Bid
  with no offset. They use native Reverse and the same whole-share quantity
  calculation as the partial Ask+ covers, including flat, quote, and montage checks.
  They reduce a short with a buy, or a long with a sell if invoked while long.
  Page 3 places Tier 1–4 Bid short buttons across the top right, and quarter,
  half, and full Bid cover buttons across the left of the second row on both decks.
  The Bid short buttons follow the same five quantity-multiplier states as Ask shorts.
- Bid shorts and covers are limit orders. Bid covers may wait for a seller
  and remain unfilled; monitor the working order and resulting position.
- Ask orders are limit orders. A short entry can remain unfilled if Ask moves
  away, and an Ask+ cover can remain unfilled if Ask rises beyond its limit before execution. Monitor
  working orders and the resulting position directly in DAS.
- `Cancel All` uses signed `$M.GetCurrPos()` on `Primary_OE` after cancelling orders. It re-arms
  the automatic stop only for a confirmed long and deliberately skips the
  long stop engine for shorts.
- `GTFO` cancels orders and uses `$gtfoRoute` with native `SEND=Reverse`. It
  prices long exits at Bid minus `$0.50` and short covers at Ask plus `$0.50`.
  These are aggressive limit orders, not guaranteed executions.

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

The scripts use fixed stop distances. The physical and Virtual Stream Deck
profiles retain the fixed-stop amount buttons; the former stop-mode buttons
on the two buy pages are now empty.

### Fixed stop losses

`Set Auto Stop` places a stop-limit order at 1R below avg cost for long
positions. R is `$stopLossTrigger` for all buy tiers. The script
uses the montage average cost when available and falls back to the entry
reference price (`$entryRefPx`) or last price if AvgCost is lagging. It cancels
existing sell orders for the symbol before placing the new stop, except when
invoked in timer mode (`$timerMode`) where cancels are skipped.

The stop-limit offset uses `$exitOffset`. The
order is snapped to valid tick sizes and sent as a STOP/SLP order.
Use the fixed-stop preset hotkeys to set `$stopLossTrigger` to `$0.10`, `$0.20`,
`$0.30`, or `$0.50`; each preset writes the selected value to the DAS message
log.

### Backstop trigger (manual, limit-only)

The backstop is a manual alert-driven exit you can arm on specific positions
when you are worried about a fast flush. It uses L1 Bid alerts (client-side)
and sends aggressive LIMIT exits for pre-market compatibility.

- `Set Backstop Trigger` builds an L1 Bid alert at `stop - $backstopBuffer`.
- When the alert fires, `Backstop Exit Executor` cancels existing sell orders
  and sends a limit sell at `Bid - $backstopBidOffset` using `$gtfoRoute`.
- If you are still not flat, it retries up to `$backstopMaxRetries` times.
- The backstop alert is automatically deleted when you go flat (timer cleanup).

The backstop uses `$lastStop` as its stop reference, so run `Set Auto Stop`
before arming the backstop.
`FLSH1L` (the default `$gtfoRoute`) is the Open Ocean broadcast route; it costs
more but prioritizes exit speed.

## TAKE PROFIT

Take-profit is implemented as a DAS price alert that triggers an execution
hotkey. It is not a resting broker-side order.

`Set Take Profit` builds the alert using an R-based distance:
- Distance is `R * $takeProfitFactor`.
- R is `$stopLossTrigger`.
- The alert watches last sale and fires above the target for longs.

When the alert fires, `Take Profit Executor`:
- Cancels existing sell orders for the symbol.
- Sells a partial position sized by `$takeProfitSize` (default 50%), or
  `$takeProfitSizeRehab` (also default 50%) when rehab is active in LIVE and in
  SIM when `$applyLiveGuardsToSim = 1`.
- Re-arms stops and (if needed) re-establishes the TP alert after the fill.

Stale take-profit alerts are cleaned up by the timer script a few seconds after
the position is flat.

## OTHER GUARD RAILS

These controls help prevent low-quality fills and oversized risk.

- Spread checks: reject entries when spread is too large relative to R
  (`$useSpreadCheck`).
- Slippage margin: requires the planned stop to sit below bid by a minimum
  tick/spread buffer (`$useSlippageMargin`, `$slipTicksMin`, `$slipSpreadFrac`).
- Hijack protection (disabled by default): when enabled, if the position size exceeds `$maxPositionSize` (LIVE, and
  SIM when `$applyLiveGuardsToSim = 1`), the timer submits a direction-aware
  full-position emergency exit, locks all montage order buttons, and sets
  `$HIJACKED_LOCKED` to block new buys. Longs exit at `Bid - $exitOffset` and
  shorts cover at `Ask + $exitOffset` through `$gtfoRoute` using native
  `SEND=Reverse`. Re-running `Set Global Variables` clears the script lock;
  montage unlock is manual (see reset instructions below).
- Single-position guard: when `$singlePositionGuard = 1`, buy hotkeys block
  entries on a different symbol once a position is tracked. This is
  script-tracked using the Primary_OE montage; if you close a position while
  on another symbol, the lock clears when you return to the original symbol or
  re-run `Set Global Variables`. Positions opened or closed outside the hotkeys
  may not be detected until the montage returns to the active symbol.
- Per-trade risk cap: blocks entries when projected risk exceeds
  `$riskCapDollars` (`$usePerTradeRiskCap`).

SIM vs LIVE: enabled hijack protection and rehab gating apply only in LIVE
unless `$applyLiveGuardsToSim = 1`; that setting defaults to `0`.
Hijack protection itself defaults to off and requires `$hijackProtection = 1`.
All other guard rails apply in both SIM and LIVE.

### Hijack protection (position-size backstop)

This position-size backstop is disabled by default (`$hijackProtection = 0`).
Set `$hijackProtection = 1` to enable it. While enabled, it continuously compares
your position size to `$maxPositionSize` using the `Primary_OE` montage. It
applies to LIVE and to SIM only when `$applyLiveGuardsToSim = 1`; that setting
defaults to `0`.

To disable it for the current session, run `$hijackProtection = 0;` in DAS.
For a persistent change, edit that value in `hotkeys/set_global_variables.das`,
rebuild/reload the hotkeys, then run `Set Global Variables`.
Disabling it does not clear a lock that has already triggered. To clear that
lock explicitly, run `$HIJACKED_LOCKED = 0; LockAllMontage Unlock;`.

If the timer detects a position larger than `$maxPositionSize`, it:
- Submits a full-position native `Reverse` through `$gtfoRoute`: sells a long at
  `Bid - $exitOffset` or covers a short at `Ask + $exitOffset`.
- Locks all montage order buttons via `LockAllMontage Lock`.
- Sets `$HIJACKED_LOCKED` to block new buys.
- Plays a brief voice alert.

Reset behavior:
- `$HIJACKED_LOCKED` clears after restarting DAS, re-running `Set Global Variables`, or explicitly setting it to `0`.
- Montage lock must be manually cleared (UI lock icon or `LockAllMontage Unlock`).

## TIMER SCRIPT

`other scripts/timer.das` does three things:

1) Enforces hijack protection when `$hijackProtection = 1` (LIVE, and SIM when `$applyLiveGuardsToSim = 1`).
2) Runs `Timer Entry Handler` each tick to arm stops/TP after fills when
   `$useTimerArming = 1`.
3) Clears take-profit and backstop alerts and their tracking state when flat.

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
- `toggle_apply_live_guards_to_sim.das` toggles whether live-only guards also
  apply in SIM (`$applyLiveGuardsToSim`).
- `set_order_route_arcal.das` sets `$orderRoute` to `ARCA1L`.
- `set_order_route_freel.das` sets `$orderRoute` to `FREE1L` (free route for ST Global Market/Open Ocean).
- `toggle_single_position_guard.das` toggles the single-position guard
  (`$singlePositionGuard`).
- `enable_rehab_mode.das` toggles rehab mode on/off; disabling requires typing `YES`.

Account and session:
- `set_global_variables.das` refreshes all global settings.
- `switch_to_sim.das` and `switch_to_live.das` set the Primary_OE account.

Order control:
- `cancel_all.das` cancels working orders and re-arms stops only for confirmed
  long positions; it skips long-stop re-arming for shorts.
  `cancel_all_no_stops.das` cancels without re-arming.
- `gtfo.das` attempts a direction-aware aggressive limit exit for the full
  position: Bid minus `$0.50` for longs or Ask plus `$0.50` for shorts.

UI and convenience:
- `show_config.das` displays current globals and account mode. It also logs
  `Primary_OE` values for montage `.Pos`, built-in `Pos`, and `$M.GetCurrPos()`;
  these read-only diagnostics help verify how DAS represents flat, long, and
  short positions before direction-aware emergency logic is enabled.
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


## Momo coordinated swap

The optional `hotkeys/swap_internal.das` swaps the symbols in `Primary_OE` and
`Secondary_OE`, then updates `Primary_Chart`, `Secondary_Chart` and `Secondary_TS`.
Both original symbols are saved before any window is changed. Keep each chart
and Time & Sales window linked to its corresponding montage. Both charts use
one-minute candles; the existing primary tape remains linked to `Primary_OE`.
Only the primary montage is used for Momo trading.

1. **Momo Swap Internal** is assigned to `Ctrl+Shift+F12` in `keymap.yaml`.
   Keep the keymap label and script together in the normal build.
2. Run **DAS: Build Hotkey File** and load the generated file through your normal
   DAS installation workflow.
3. Momo uses the fixed `Ctrl+Shift+F12` shortcut automatically; there is no app
   setting. Keep this binding when building the hotkey file.
4. Request swaps through Momo's **Swap** button. An optional user-facing DAS
   shortcut can launch Momo's `tools/das_feed_viewer/das_helpers/request_swap.cmd`
   through `ShellExec`; the request helper stays with the Momo application.

The internal script only changes window symbols. Momo performs the flat-account,
pending-order and setup checks before invoking it, so do not use the internal
binding directly as your user-facing shortcut. Loading the script does not
qualify two-stock execution: keep Momo Inactive and the account flat for the
required layout and user-triggered swap verification. The new windows/scripts
have not yet passed that live qualification.
