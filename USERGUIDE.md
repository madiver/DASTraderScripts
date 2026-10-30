# USER GUIDE

Reviewed against repository source on 2026-10-29. Runtime behavior below describes
the scripts, not a guarantee that the same revision is installed in DAS.
`keymap.yaml` is the binding authority; `hotkeys/set_global_variables.das` is the
default-setting authority. Historical migrations are identified separately.

## OVERVIEW

These scripts are the hotkeys I use in DAS Trader for active, discretionary day trading. They focus on fast, repeatable order entry with guard rails. I treat the micro ice breaker and ice breaker (Buy MIB/IB) entries as the first tests of a trade thesis. Trade state is isolated by account and symbol, so a protected short in another symbol can coexist with an automated long. The default single-position guard allows one tracked automated long per account; manual shorts do not occupy that guard.

Automatic stop-loss and take-profit protection supports both long and short entries, independently controlled by `$useAutoStop` and `$useTakeProfit`. All sixteen Tier 1–4 short-entry hotkeys arm enabled protection after actual fills. Full, half, and quarter covers wait for working BUY orders to finish before restoring protection on remaining shorts. The existing RESET STOP LOSS (`Set Auto Stop`, `Ctrl+Shift+S`), RESET TAKE PROFIT (`Set Take Profit`, `Ctrl+Shift+T`) and full-position BE buttons support both directions. All cancellations are scoped to the selected account and symbol. Long buy/sell, half-BE and scale-in-BE actions still reject shorts. A long buy on the same account/symbol as a short or pending short action is blocked; use Cover to reduce a short.

Repository structure: the `hotkeys/` folder contains the `.das` hotkey scripts, `keymap.yaml` defines the key bindings and metadata, and `other scripts/` contains support scripts like the timer. A `.das` file is plain text you can paste into the DAS Trader Script Editor. The `keymap.yaml` can be compiled into a `Hotkey.htk` using the DAS Hotkey Tools VS Code extension, or you can skip the compiler and copy the scripts manually.

These scripts assume you have a primary montage window named `Primary_OE` (Primary Order Entry) and a chart window named `Primary_Chart`. If that montage name does not exist, many scripts will fail or behave incorrectly. The chart name is used for symbol synchronization. You can reference my DAS Trader desktop and chart settings here: https://github.com/madiver/DASTraderConfig

Regardless of the method you choose, install `other scripts/timer.das` manually in DAS Trader under "Timer Event Scripts." There is no chart scripting file in the current repository; the named chart is used for symbol synchronization, not a required chart study script. I also recommend adding `ExecHotKey("Set Global Variables");` to your Desktop Load Scripts so globals are initialized every time DAS starts.

## QUICK START

1) Before compiling, configure the DAS Hotkey Tools VS Code extension:
   - `dasHotkeyTools.outputPath` (required).
   - `dasHotkeyTools.liveAccount` and `dasHotkeyTools.simulatedAccount` for `%%LIVE%%` / `%%SIMULATED%%` substitution.
   - Optional: `dasHotkeyTools.placeholders.failOnMissing` to block builds when placeholders are unresolved.
2) Build the complete `keymap.yaml` and load the resulting hotkey file through your normal installation workflow, or copy every mapped `.das` script manually using its exact keymap label. Internal/unbound helpers are required too.
3) Ensure your montage is named `Primary_OE`, the timer script `other scripts/timer.das` is installed under Timer Event Scripts, and the chart used for symbol synchronization is named `Primary_Chart`.
4) Run **Set Global Variables** to initialize defaults, then **Switch to Sim** for initial validation. Use **Switch to Live** only when intentionally changing to your live account.
5) Run **Show Config** to confirm account mode, defaults, guard states, and entry timeouts. Recreate legacy TP alerts with the current builder after an upgrade.
6) Keep the timer enabled in both entry modes. Stream Deck profiles are external to this repository; configure the buttons to match the installed keymap. See [Stream Deck controls](#entry-timeout-controls) and [asset/setup notes](assets/streamdeck/README.md).

### Migration from older installations

FLASH CRASH TRIG has been retired. Replace the complete hotkey map to remove
the old `Set Backstop Trigger`, `Backstop Exit Executor`, and `Build Backstop
Alert` entries, including `Alt+Ctrl+Win+8`. Delete any previously armed
`Backstop ...` alerts in DAS. The retired action is absent from the current
local profile setup; see the Stream Deck notes for the new timeout controls.

For the exit-coordinator rollback, install while flat with no working orders.
Replace both the compiled hotkeys and the complete Timer Event Script, save the
configuration, restart DAS to discard the old queued session state, and run Set
Global Variables. Validate one manual 10-share SIM position and a single full
exit before further testing. The former reference-specific recovery is obsolete.

Important: update `$TRSIM` and `$LIVEACT` in `hotkeys/set_global_variables.das` with your actual account identifiers if they are not already populated (they are shown in the config display for reference). Hijack protection defaults to off (`$hijackProtection = 0`); set it to `1` to enable it. `$applyLiveGuardsToSim` controls whether enabled live-only guards (hijack, rehab) also apply in SIM; it defaults to `0`. Set it to `1` to apply those enabled guards in SIM. Also verify that any `%%SIMULATED%%` and `%%LIVE%%` placeholders have been replaced in the SIM/LIVE switch scripts (the VS Code extension handles this during build; if you copy scripts manually, you must replace them yourself).

By default (`$useTimerArming = 1`), a buy hotkey sends the limit order, records entry context, and returns immediately. A timer-driven handler arms stop loss / take profit on the first 1-second tick that sees a clean fresh fill. If there are working SELLs, or this is a scale-in, it cancels existing SELLs and submits replacement protection on a subsequent tick. A bounded order-history check falls back to ordinary cancellation staging if it cannot prove that no working SELL exists. If position size increases on later ticks, the handler resizes the stop and only re-arms TP when the TP reset conditions are met. If no fill appears within its captured `$longEntryTimeoutSeconds` (unless 0/INDEF), it cancels the working buy order and clears pending state. With `$useTimerArming = 0`, buy hotkeys poll for actual fills up to `$maxPolls * $pollMs` and cancel any remainder before protecting shares received. With no fill and an open order after that bounded poll, they return and leave the captured entry deadline to the timer, including INDEF. They do not add the former 1,000 ms padding wait before protection. A second inline buy in the same account/symbol is blocked during `$entryCooldownSeconds` instead; this uses whole-second clock values, not millisecond precision.

Automatic TP exits and half/quarter long sells use timer-managed fill monitoring, regardless of `$useTimerArming`. Native manual covers are different: they have no scripted fill deadline, and short protection waits for working BUY orders to finish/cancel. Keep the current Timer Event Script installed and enabled in both entry modes.

Short fills and stop resizing also use the timer, independently of `$useTimerArming`.
With stops enabled, the first observed partial fill receives protection; later
fills/scale-ins resize it using the current signed position and average cost.
An unfilled short entry is canceled after its captured `$shortEntryTimeoutSeconds` (0/INDEF disables timeout),
and a racing/late fill remains monitored until cancellation is acknowledged.
Stops off means short entries do not start automatic protection. RESET can
still manually place a short stop with stops off. Short take profit arms
independently when `$useTakeProfit = "Yes"`, even if automatic stops are off.

The scripts submit STOP/SLP orders. Verify acceptance, trigger hosting, session eligibility, and stop-limit behavior with your broker; submission alone does not establish protection. Take-profit is implemented with DAS alerts that fire when price reaches the configured R target and then execute the Take Profit hotkey; those alerts are client-side and require DAS to remain open with live data.

## GLOBAL VARIABLES

All core settings live in `hotkeys/set_global_variables.das`. If you change a
value, rerun "Set Global Variables" so the globals refresh in DAS.

Variables by category:

Runtime counters and modes:
- `$oneSecondScriptCnt`: retained legacy diagnostic counter; the current timer processes each context every tick.
- `$rehab`: enables rehab mode to block scale-ins and larger entries in LIVE (and SIM when `$applyLiveGuardsToSim = 1`).
- `$HIJACKED_LOCKED`: runtime lock set when hijack protection triggers.
- `$tradeStates`: account/symbol registry of runtime trade objects.
- `$tradeSlots`, `$tradeSlotCount`: timer iteration slots; inactive slots are reused.
- `$tradeActionDepth`, `$tradeActionUntil`: nested action lease that pauses timer work during cancellation/fill waits. Alerts arriving during those waits are deferred on their own trade.
- `$trade_ok`: runtime flag set by `Check Global Guards` for buy hotkeys.
- `$testMode`: when set to 1, buy hotkeys exit after non-market guards (no order sent).

Feature toggles and entry guards:
- `$useSlippageMargin`: enables the stop-vs-bid margin check in buy scripts.
- `$slipTicksMin`: minimum tick margin for slippage checks.
- `$slipSpreadFrac`: fraction of spread added to the slippage margin.
- `$acceptPartial` / `$minFillShares`: allow inline buy polling to end early when a sufficient partial fill appears. If the poll window expires with any actual fill, the script still cancels the remainder and protects the filled shares. These settings do not gate timer-mode first-fill detection.
- `$cancelRemainderOnPartial`: retained legacy configuration/display field; current execution scripts do not read it. Inline buys cancel their remainder once a fill is processed. Timer-mode entries leave the remainder working and resize protection on later fills.
- `$usePerTradeRiskCap`: blocks entries if projected net risk to the planned stop exceeds `$riskCapDollars`.
- `$useSpreadCheck`: enables spread-vs-R safety checks before entries.
- `$pegToBid`: when enabled, BE limit sells can peg to bid instead of AvgCost.
- `$hijackProtection`: enables the position-size hijack backstop (LIVE, and SIM when `$applyLiveGuardsToSim = 1`); defaults to `0` (disabled).
- `$applyLiveGuardsToSim`: when set to 1, apply hijack and rehab guards in SIM; defaults to 0 (live-only).
- `$singlePositionGuard`: when set to 1 (default), block new long entries while another tracked long in the same account remains active. Other pending long entries block buys even when this toggle is off; short entries bypass these long-side guards.
- `$useAutoStop`: toggles auto stop placement.
- `$useTakeProfit`: toggles take-profit alerts/executor behavior.
- `$resetStopOnCancel`: restores the stop after `cancel_all.das` for either direction when stops are enabled; shorts wait for BUY cancellations through the timer.
- `$useTimerArming`: uses timer-based entry arming (1) or inline polling (0).

Risk and execution:
- `$entryBidOffset` / `$entryAskOffset`: independent signed offsets shared by offset buys and shorts (defaults: BID `+0.01`, ASK `-0.01`). Both directions add the selected signed offset to the reference quote. Negative values price below Bid/Ask; positive values price above it. Stream Deck labels these entries `BID±` and `ASK±`. The existing buy hotkey labels retain `Bid+`/`Ask+` to describe addition; short hotkey labels are now `Short T1/T2/T3/T4 Bid Offset` and `Ask Offset`.
- `$exitOffset`: desired fixed-dollar cushion for ordinary Bid- long exits and Ask+ short covers (default `$0.10`), also used uncapped for stop-limit and hijack pricing. This is a separate exit setting: BID/ASK entry-offset selectors do not change it. Bid- sells subtract the cushion, and Ask+ covers add it, as their labels indicate.
- `$exitOffsetMaxPct`: percentage ceiling for ordinary Bid- sells and Ask+ covers only. Default `0.05` means 5% of Bid for sells or Ask for covers. The effective cushion is the smaller of `$exitOffset` and `quote * $exitOffsetMaxPct`. Set `0` to disable the percentage ceiling. Stop-limit and hijack pricing do not use this ceiling; GTFO has its own setting below.
- `$gtfoOffsetMaxPct`: independent percentage ceiling for GTFO's desired `$0.50` cushion. Default `0.05` means 5% of Bid for long sells or Ask for short covers. The effective cushion is `min(0.50, quote * gtfoOffsetMaxPct)`. Set `0` to disable this ceiling. GTFO rounds toward the quote when needed to stay within the ceiling and enforces a positive minimum price. It uses Last only if the required quote is unavailable. Re-run Set Global Variables after loading the updated keymap to initialize this setting.

With the defaults, a $10 reference quote keeps the full $0.10 cushion, while a
$0.43 quote limits the cushion to $0.0215 before price rounding. Ordinary exits
round toward the quote if nearest-tick rounding would cross the percentage
ceiling. Ask+ covers retain native DAS rounding, using four decimal places
below $0.25 without first rounding to three. For the reported examples, Ask
$0.4298 produces a $0.451 cover limit; Ask $0.1796 produces $0.1885. The ceiling
uses the current quote, not a guaranteed match for a broker's reference price,
and does not guarantee route acceptance or a fill. It applies with manual
routes and AUTOL and adds no fallback or automatic rerouting. SHOW CFG displays
the configured ceiling; re-run Set Global Variables after loading the new
keymap to initialize it.

- `$orderRoute`: limit order route/mode for entries/exits (buys/sells/TP/BE). Default is `AUTOL`, which selects ARCA1L for expected adding liquidity and uses the configured price bands for expected taking liquidity. Urgent exits use BESTL. `FREE1L` remains available as a manual preset and is never selected by AUTOL.
- Route presets are available for `AUTOL`, `ARCA1L`, `FREE1L`, `BESTL`, `FLASH1L`, and `SMRTL`.
- `$gtfoRoute`: emergency exit route for GTFO/hijack exits when a manual route is selected. Stored default is `FLSH1L` (Open Ocean broadcast route); default AUTOL mode overrides it with `BESTL`.
- `$stopLossTrigger`: fixed 1R risk per share for long and short stop losses, including RESET STOP LOSS.
- `$takeProfitFactor`: R multiple for take-profit alerts.
- `$takeProfitSize`: fraction of the long to sell or short to cover on a TP trigger.
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
- `$maxPolls`: maximum inline buy fill polls before returning to timer monitoring if the order is still open with no fill. It is not the long-entry cancellation deadline.
- `$longEntryTimeoutSeconds` / `$shortEntryTimeoutSeconds`: independent no-fill entry deadlines captured at submission; presets are 10, 15, 30 seconds and 0 (INDEF). Both default to 10.
- Half/quarter long sells use `($maxPolls * $pollMs) / 1000` as their timer-managed exit deadline (default 2 seconds); automatic TP exits use 3 seconds. Native manual covers do not use those deadlines.
- `$entryCooldownSeconds`: minimum difference between whole-second send timestamps
  for inline entries in the same account/symbol (default `1`; `0` disables it).
  This guard returns immediately and does not delay stop arming.

Trade runtime (each `$trade` belongs to exactly one account and symbol):
- `$trade.account`, `$trade.symbol`, `$trade.key`: immutable order identity.
- `$trade.entryPending`, `$trade.entryStage`, `$trade.entryTicks`: fill/protection staging; deadlines are snapshotted separately from `$longEntryTimeoutSeconds` / `$shortEntryTimeoutSeconds`.
- `$trade.entryStarted`, `$trade.entryTimeoutSeconds`: submission second and captured long no-fill deadline.
- `$trade.shortEntryStarted`, `$trade.shortEntryTimeoutSeconds`: corresponding short snapshot.
- `$trade.entryPosBefore`, `$trade.entryAvgBefore`, `$trade.entryScaleIn`: captured entry context.
- `$trade.entryRefPx`: submitted entry reference, retained for diagnostics rather than substituting for an unknown average cost.
- `$trade.entryWatch`, `$trade.entryLastPos`: detect later size increases.
- `$trade.lastStop`, `$trade.stopArmed`: last submitted stop reference/status for this trade.
- `$trade.shortWatch`, `$trade.shortEntryPending`, `$trade.shortEntryOrder`, `$trade.shortEntryTicks`: short fill monitoring and no-fill timeout.
- `$trade.shortCoverPending`: wait for a cover to finish/cancel before restoring protection or permitting a new long entry.
- `$trade.shortStopQty`, `$trade.shortStopAvg`: size and average used by the last short stop; `Get("shortStopOrder")` retains its order identity for cancellation acknowledgment.
- `$trade.tpDirection`, `$trade.tpRevision`: bind a TP alert to its side and latest reset; revisions are consumed after submission so captured payloads cannot repeat an order.
- `$trade.tpCancelPending`, `$trade.deferredTpDirection`, `$trade.deferredTpRevision`: wait for short-stop cancellation without losing the TP payload's identity.
- `$trade.shortTpQty`, `$trade.shortTpAvg`, `$trade.shortTpDone`: short TP refresh state; a completed TP stays consumed until RESET or a later fill changes the position.
- `$trade.tpName`: exact account-scoped TP alert name.
- `$trade.generation`: identifies the current trade/alert lifecycle; canceled or old-trade alert payloads cannot act on a new position.
- `$trade.deferredTp`: queued take-profit action while another script is waiting.
- `$trade.exitPending`, `$trade.exitStage`, `$trade.exitOrder`: timer-owned partial
  exit, canceled by GTFO or a manual full exit/cancellation.
- `$trade.exitStartPos`, `$trade.exitQty`, `$trade.exitGeneration`: actual starting
  position, requested reduction, and lifecycle identity for that exit.
- `$trade.exitStarted`, `$trade.exitTimeout`: second-clock fill deadline, including
  midnight rollover. Timeout is acted on at the next available timer tick.
- `$trade.lastEntrySecond`: encoded inline-entry send timestamp, retained through
  flat cleanup and configuration reload so rapid retries still honor cooldown.

The timer reads signed `GetAccountObj(account).GetPosition(symbol).Share`, including shares reserved by working orders. Routine checks fetch position/average data without quotes; order pricing fetches fresh quotes when needed. Montage `.Pos` and native `Pos` are absolute quantities; `GetCurrPos()` can temporarily be zero while shares are reserved. Missing position data fails closed, and a missing off-montage position record is not assumed flat. Primary/Secondary montages are examined only when required data is missing, and must match both account and symbol. Stops wait for a valid average cost, and alerts require valid quotes for market-priced exits.

`Set Global Variables` resets configuration and the action lease but preserves initialized trade objects. Restarting DAS clears this client-side registry. Recreate TP alerts after a restart or upgrading legacy scripts. Existing broker orders are not reconstructed into runtime state automatically; use the stop/alert hotkeys to manage an already-open position.

### Defaults table

Defaults are pulled from `hotkeys/set_global_variables.das` and reflect the
configuration values when you run "Set Global Variables." Rows for `$trade.*`
describe initialization of new contexts, not values overwritten on LOAD CFG;
existing trade objects and their captured deadlines are preserved.

| Category | Variable | Default |
| --- | --- | --- |
| Runtime | `$oneSecondScriptCnt` | `0` |
| Runtime | `$rehab` | `0` |
| Runtime | `$useTimerArming` | `1` |
| Runtime | `$timerMode` | `0` |
| Runtime | `$trade.entryPending` | `0` |
| Runtime | `$trade.entryStage` | `0` |
| Runtime | `$trade.entryTicks` | `0` |
| Runtime | `$longEntryTimeoutSeconds` | `10` (0 = INDEF) |
| Runtime | `$shortEntryTimeoutSeconds` | `10` (0 = INDEF) |
| Runtime | `$trade.entryPosBefore` | `0` |
| Runtime | `$trade.entryAvgBefore` | `0` |
| Runtime | `$trade.entryScaleIn` | `0` |
| Runtime | `$trade.entryRefPx` | `0` |
| Runtime | `$trade.lastStop` | `0` |
| Runtime | `$HIJACKED_LOCKED` | `0` |
| Runtime | `$trade_ok` | `1` |
| Runtime | `$testMode` | `0` |
| Runtime | `$trade.entryWatch` | `0` |
| Runtime | `$trade.entryLastPos` | `0` |
| Toggles | `$useSlippageMargin` | `1` |
| Toggles | `$slipTicksMin` | `2` |
| Toggles | `$slipSpreadFrac` | `0.25` |
| Toggles | `$acceptPartial` | `1` |
| Toggles | `$minFillShares` | `1` |
| Toggles | `$cancelRemainderOnPartial` | `1` (legacy; not read by execution scripts) |
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
| Risk | `$exitOffsetMaxPct` | `0.05` (5%; `0` disables the cap) |
| Risk | `$gtfoOffsetMaxPct` | `0.05` (5%; `0` disables the GTFO cap) |
| Risk | `$orderRoute` | `"AUTOL"` |
| Risk | `$gtfoRoute` | `"FLSH1L"` |
| Risk | `$stopLossTrigger` | `0.50` |
| Risk | `$takeProfitFactor` | `1.0` |
| Risk | `$takeProfitSize` | `0.50` |
| Risk | `$takeProfitSizeRehab` | `0.50` |
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
| Polling | `$entryCooldownSeconds` | `1` (inline entries, whole-second clock) |

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
| `Ctrl+Shift+Q` | `hotkeys/cancel_all.das` | Cancel orders and clear TP alerts; restore enabled stop protection for either direction. |
| `Alt+Ctrl+Q` | `hotkeys/gtfo.das` | Full-position emergency limit exit: up to $0.50 below Bid for longs or above Ask for shorts, capped at 5% by default. |
| `Ctrl+,` | `hotkeys/set_global_variables.das` | Load default globals. |
| `Alt+Ctrl+Shift+5` | `hotkeys/set_qty_mult_0_5.das` | Set the shared tier-size multiplier to 0.5x. |
| `Alt+Ctrl+Shift+6` | `hotkeys/set_qty_mult_1_0.das` | Set the shared tier-size multiplier to 1.0x. |
| `Alt+Ctrl+Shift+7` | `hotkeys/set_qty_mult_2_0.das` | Set the shared tier-size multiplier to 2.0x. |
| `Alt+Ctrl+Shift+8` | `hotkeys/set_qty_mult_3_0.das` | Set the shared tier-size multiplier to 3.0x. |
| `Alt+Ctrl+Shift+9` | `hotkeys/set_qty_mult_1_5.das` | Set the shared tier-size multiplier to 1.5x. |
| `Alt+Ctrl+Shift+Win+6` | `hotkeys/set_bid_entry_offset_minus_3.das` | Set the signed Bid entry offset to -3 cents. |
| `Alt+Ctrl+Shift+Win+5` | `hotkeys/set_bid_entry_offset_minus_2.das` | Set the signed Bid entry offset to -2 cents. |
| `Alt+Ctrl+Shift+Win+7` | `hotkeys/set_bid_entry_offset_minus_1.das` | Set the signed Bid entry offset to -1 cent. |
| `Alt+Ctrl+Shift+Win+8` | `hotkeys/set_bid_entry_offset_plus_1.das` | Restore the default signed Bid entry offset of +1 cent. |
| `Alt+Ctrl+Shift+Win+9` | `hotkeys/set_bid_entry_offset_plus_3.das` | Set the signed Bid entry offset to +3 cents. |
| `Alt+Ctrl+Shift+Win+F6` | `hotkeys/set_ask_entry_offset_minus_3.das` | Set the signed Ask entry offset to -3 cents. |
| `Alt+Ctrl+Shift+Win+F5` | `hotkeys/set_ask_entry_offset_minus_2.das` | Set the signed Ask entry offset to -2 cents. |
| `Alt+Ctrl+Shift+Win+F7` | `hotkeys/set_ask_entry_offset_minus_1.das` | Restore the default signed Ask entry offset of -1 cent. |
| `Alt+Ctrl+Shift+Win+F8` | `hotkeys/set_ask_entry_offset_plus_1.das` | Set the signed Ask entry offset to +1 cent. |
| `Alt+Ctrl+Shift+Win+F9` | `hotkeys/set_ask_entry_offset_plus_3.das` | Set the signed Ask entry offset to +3 cents. |
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
| `Alt+Ctrl+Shift+S` | `hotkeys/short_tier1_ask.das` | Sell short Tier 1 at ask with automatic stops when enabled. |
| `Alt+Ctrl+Shift+D` | `hotkeys/short_tier2_ask.das` | Sell short Tier 2 at ask with automatic stops when enabled. |
| `Alt+Ctrl+Shift+F` | `hotkeys/short_tier3_ask.das` | Sell short Tier 3 at ask with automatic stops when enabled. |
| `Alt+Ctrl+Shift+G` | `hotkeys/short_tier4_ask.das` | Sell short Tier 4 at ask with automatic stops when enabled. |
| `Alt+Ctrl+Shift+H` | `hotkeys/short_tier1_bid.das` | Sell short Tier 1 at bid with no offset; automatic stops when enabled. |
| `Alt+Ctrl+Shift+J` | `hotkeys/short_tier2_bid.das` | Sell short Tier 2 at bid with no offset; automatic stops when enabled. |
| `Alt+Ctrl+Shift+K` | `hotkeys/short_tier3_bid.das` | Sell short Tier 3 at bid with no offset; automatic stops when enabled. |
| `Alt+Ctrl+Shift+L` | `hotkeys/short_tier4_bid.das` | Sell short Tier 4 at bid with no offset; automatic stops when enabled. |
| `Alt+Ctrl+Shift+F1` | `hotkeys/short_tier1_ask_minus.das` | Sell short Tier 1 at Ask plus the signed ASK entry offset, with automatic stops when enabled. |
| `Alt+Ctrl+Shift+F2` | `hotkeys/short_tier2_ask_minus.das` | Sell short Tier 2 at Ask plus the signed ASK entry offset, with automatic stops when enabled. |
| `Alt+Ctrl+Shift+F3` | `hotkeys/short_tier3_ask_minus.das` | Sell short Tier 3 at Ask plus the signed ASK entry offset, with automatic stops when enabled. |
| `Alt+Ctrl+Shift+F4` | `hotkeys/short_tier4_ask_minus.das` | Sell short Tier 4 at Ask plus the signed ASK entry offset, with automatic stops when enabled. |
| `Alt+Ctrl+Shift+F5` | `hotkeys/short_tier1_bid_minus.das` | Sell short Tier 1 at Bid plus the signed BID entry offset, with automatic stops when enabled. |
| `Alt+Ctrl+Shift+F6` | `hotkeys/short_tier2_bid_minus.das` | Sell short Tier 2 at Bid plus the signed BID entry offset, with automatic stops when enabled. |
| `Alt+Ctrl+Shift+F7` | `hotkeys/short_tier3_bid_minus.das` | Sell short Tier 3 at Bid plus the signed BID entry offset, with automatic stops when enabled. |
| `Alt+Ctrl+Shift+F8` | `hotkeys/short_tier4_bid_minus.das` | Sell short Tier 4 at Bid plus the signed BID entry offset, with automatic stops when enabled. |
| `Alt+Ctrl+Shift+C` | `hotkeys/cover_1_1_ask.das` | Cover the full short position at Ask plus the capped exit cushion using DAS Reverse. |
| `Alt+Ctrl+Shift+X` | `hotkeys/cover_1_2_ask.das` | Cover half the current position at Ask plus the capped exit cushion using DAS Reverse. |
| `Alt+Ctrl+Shift+Z` | `hotkeys/cover_1_4_ask.das` | Cover a quarter of the current position at Ask plus the capped exit cushion using DAS Reverse. |
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
| `Ctrl+Shift+B` | `hotkeys/set_auto_stop_be_1_1.das` | Breakeven stop/limit for full long or short position. |
| Unbound | `hotkeys/set_auto_stop_be_scale_1_1.das` | Scale-in BE stop/limit for full position. |
| `Alt+Ctrl+Win+-` | `hotkeys/set_0_10_stop.das` | Set 1R stop-loss trigger to $0.10. |
| `Alt+Ctrl+Win+[` | `hotkeys/set_0_20_stop.das` | Set 1R stop-loss trigger to $0.20. |
| `Alt+Ctrl+Win+=` | `hotkeys/set_0_30_stop.das` | Set 1R stop-loss trigger to $0.30. |
| `Alt+Ctrl+Win+5` | `hotkeys/set_0_50_stop.das` | Set 1R stop-loss trigger to $0.50. |
| `Alt+Ctrl+B` | `hotkeys/set_auto_stop_be_1_2.das` | Breakeven stop/limit for half position. |
| `Ctrl+Shift+T` | `hotkeys/set_take_profit.das` | RESET TAKE PROFIT: create an R-based alert for the current long or short. |
| Unbound | `hotkeys/take_profit_executor.das` | Execute TP partial when alert fires. |
| `Alt+Ctrl+Win+1` | `hotkeys/select_primary_order_entry.das` | Focus the Primary_OE montage. |
| `Alt+Ctrl+Win+P` | `hotkeys/toggle_position_window.das` | Toggle Positions windows AlwaysOnTop. |
| `Alt+Ctrl+Win+]` | `hotkeys/toggle_stp_feature.das` | Toggle auto stop-loss feature. |
| `Alt+Ctrl+Win+/` | `hotkeys/toggle_tp_feature.das` | Toggle take-profit alerts. |
| `Alt+Ctrl+Win+'` | `hotkeys/toggle_spread_check_feature.das` | Toggle spread safety guard. |
| `Alt+Ctrl+Win+G` | `hotkeys/toggle_apply_live_guards_to_sim.das` | Toggle live-only guards in SIM. |
| `Alt+Ctrl+Win+7` | `hotkeys/set_order_route_autol.das` | Enable AUTOL: ARCA1L for expected adding, fee bands for taking, BESTL for urgent exits. |
| `Alt+Ctrl+Win+2` | `hotkeys/set_order_route_arcal.das` | Set limit order route to ARCA1L. |
| `Alt+Ctrl+Win+3` | `hotkeys/set_order_route_freel.das` | Set limit order route to FREE1L (free route for ST Global Market/Open Ocean). |
| `Alt+Ctrl+Win+4` | `hotkeys/set_order_route_bestl.das` | Set limit order route to BESTL. |
| `Alt+Ctrl+Win+F4` | `hotkeys/set_order_route_flash1l.das` | Set limit order route to FLASH1L. |
| `Alt+Ctrl+Win+6` | `hotkeys/set_order_route_smrtl.das` | Set limit order route to SMRTL. |
| `Alt+Ctrl+Win+M` | `hotkeys/toggle_single_position_guard.das` | Toggle single-symbol entry guard. |
| `Alt+Ctrl+Win+H` | `hotkeys/enable_rehab_mode.das` | Toggle rehab mode (YES to disable). |
| Unbound | `hotkeys/hijack_exit.das` | Hijack guard exit/lock enforcement (timer-only). |
| Unbound | `hotkeys/timer_entry_handler.das` | Timer-driven stop/TP arming for entries. |
| Unbound | `hotkeys/timer_exit_handler.das` | Monitor partial exits and restore protection after confirmed residual cancellation. |
| Unbound | `hotkeys/resolve_order_route.das` | Resolve a concrete route for each AUTOL submission. |
| Unbound | `hotkeys/timer_short_stop_handler.das` | Protect actual short fills and resize short stops through the timer. |
| Unbound | `hotkeys/check_working_buys.das` | Check for other working BUY orders before placing a short stop. |
| Unbound | `hotkeys/load_position_context.das`, `hotkeys/read_position_only.das` | Fresh context/position reads without quotes. |
| Unbound | `hotkeys/check_working_sells.das` | Bounded working-order check for clean fresh-entry stop arming. |
| Unbound | `hotkeys/load_trade_context.das`, `hotkeys/read_trade_position.das` | Select an account/symbol trade and read signed position/quote data. |
| Unbound | `hotkeys/clear_trade_state.das`, `hotkeys/invalidate_trade_alerts.das` | Clean up one closed trade or suspend its automation for a manual cancel/exit. |
| Unbound | `hotkeys/end_trade_action.das` | Release the trade action lease and process queued GTFO requests. |
| `Ctrl+Shift+F12` | `hotkeys/swap_internal.das` | Internal Momo symbol swap; invoke through Momo after its checks, not as a direct trading shortcut. |
| `Alt+Ctrl+Shift+F9` | `hotkeys/set_long_entry_timeout_10.das` | Set future long-entry no-fill timeout to 10s. |
| `Alt+Ctrl+Shift+F10` | `hotkeys/set_long_entry_timeout_15.das` | Set future long-entry no-fill timeout to 15s. |
| `Alt+Ctrl+Shift+F11` | `hotkeys/set_long_entry_timeout_30.das` | Set future long-entry no-fill timeout to 30s. |
| `Alt+Ctrl+Shift+F12` | `hotkeys/set_long_entry_timeout_indef.das` | Set future long-entry no-fill timeout to INDEF. |
| `Alt+Ctrl+F9` | `hotkeys/set_short_entry_timeout_10.das` | Set future short-entry no-fill timeout to 10s. |
| `Alt+Ctrl+F10` | `hotkeys/set_short_entry_timeout_15.das` | Set future short-entry no-fill timeout to 15s. |
| `Alt+Ctrl+F11` | `hotkeys/set_short_entry_timeout_30.das` | Set future short-entry no-fill timeout to 30s. |
| `Alt+Ctrl+F12` | `hotkeys/set_short_entry_timeout_indef.das` | Set future short-entry no-fill timeout to INDEF. |

## BUY ORDERS

Sizing philosophy: start small to probe the trade, add only when it is working, and cap exposure with hard limits. The four entry tiers have configurable base sizes of 100 shares for MIB, 200 for IB, 300 for the legacy `buy_25_*` family, and 500 for the legacy `buy_50_*` family. Every entry uses `round(base tier size * $qtyMult)`, where `$qtyMult` defaults to `1.0`. `$maxPositionSize` uses the same calculation with `$tier4ShareSize`, so the position cap always equals one scaled Tier 4 order. In rehab mode (`$rehab = 1`), trading is restricted to MIB/IB entries and scale-ins are blocked in LIVE and SIM when `$applyLiveGuardsToSim = 1`.

Rehab mode is a safety throttle for live trading. When enabled (`$rehab = 1`), the scripts block scale-ins and prevent larger tier entries in live accounts, forcing you to trade only MIB/IB size while you reset discipline or reduce risk after a drawdown. The same restrictions apply in SIM only when `$applyLiveGuardsToSim = 1`; that setting defaults to `0`. You can set the default by changing `$rehab` in `hotkeys/set_global_variables.das` and re-running "Set Global Variables" (or restarting DAS), or toggle it for the current session using the `Toggle Rehab Mode` hotkey. Disabling rehab requires typing `YES` to confirm.

### Configurable entry tiers

The keymap contains 16 buy variants (four tiers across Bid, Ask, Bid+ and Ask+)
and 16 short variants (four tiers across plain and offset Ask/Bid). The local
physical and Virtual profiles use the following quantity labels; the profiles
themselves are not distributed by this repository:

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
- All buy scripts clip the requested add to remaining `$maxPositionSize` capacity
  (when the cap is positive) and reject excessive projected risk when
  `$usePerTradeRiskCap` is enabled. Short entries do not use these long-side caps.
- Bid+ versions add `$entryBidOffset` to bid; Ask+ versions add
  `$entryAskOffset` to ask. Positive offsets price above the reference quote;
  negative offsets price below it, before tick rounding.
- Each side has presets for `-0.03`, `-0.02`, `-0.01`, `+0.01`, and `+0.03`. Selecting
  a preset changes that side's offset for subsequent buys and shorts.
- In the local **DAS Trader** Stream Deck profile, page 5, column 6, the
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
- Buy sizing is clipped to the remaining `$maxPositionSize` capacity; no order
  is sent when capacity is exhausted. The risk-cap check rejects an add when
  projected net risk to its planned stop exceeds `$riskCapDollars`.
- Spread safety checks and slippage margins guard entries before an order is
  sent.

### Single-position guard

When `$singlePositionGuard = 1` (default), buy hotkeys allow one tracked automated long per account. A manual short in another symbol does not block it. Turning the guard off allows multiple tracked longs; each has independent stop/TP and timer state. Another pending long entry in the same account blocks a new entry until staging finishes or times out; a duplicate pending buy in the same symbol is also blocked.

Changing or swapping the montage does not cancel a pending entry or clear another trade's state. The timer continues processing the original account and symbol without changing montage focus or selection. Account P&L and buying power remain DAS/broker calculations; these scripts do not maintain a separate accounting ledger.

## MANUAL SHORT ORDERS

Short entries use `$orderRoute` and `DAY+` and bypass the long entry guards.
The timer arms enabled stop-loss and take-profit protection after actual short
fills. Verify locate availability, route behavior, and applicable short-sale
restrictions with the broker.

- `Short T1/T2/T3/T4 Ask/Bid` cancels working orders for the montage symbol, then
  sends an explicit sell-short limit order at the selected quote with no offset for
  `round($tierNShareSize * $qtyMult)` shares. Each hotkey can open a short while
  flat or add its tier to an existing short, but aborts if the current position
  is long or its direction cannot be resolved safely.
- Page 3 of both Stream Deck profiles keeps plain Ask/Bid shorts. Page 4 uses
  `Short T1/T2/T3/T4 Ask Offset` at `Ask + $entryAskOffset` and
  `Short T1/T2/T3/T4 Bid Offset` at `Bid + $entryBidOffset`, labeled `ASK±`
  and `BID±` on Stream Deck. Negative offsets price below the reference quote;
  positive offsets price above it. With defaults, ASK `-0.01` gives Ask minus
  one cent, while BID `+0.01` gives Bid plus one cent. Offset shorts now use
  `Alt+Ctrl+Shift+F1` through `F4` for Ask tiers 1–4 and `F5` through `F8`
  for Bid tiers 1–4, avoiding the Windows-key combinations associated with the
  reported Explorer window. Legacy `*_minus.das` filenames/IDs are retained. All five quantity states
  and existing covers remain. Orders with nonpositive adjusted or rounded
  limits are rejected. Submission logs record the quote, signed offset and limit.
- Signed ASK OFFSET and BID OFFSET selectors remain on settings page 5 only.
  Both physical and Virtual profiles use `-0.03`, `-0.02`, `-0.01`, `+0.01`,
  and `+0.03` in the same order, with matching sync groups and reset targets.
  LOAD CFG resets them to ASK `-0.01` and BID `+0.01` as before.
  Other offset values must be selected through the Stream Deck controls to
  keep the displays aligned with DAS; editing a DAS variable directly does
  not update Stream Deck. Rebuild and install the full keymap before using the
  relabeled offset short buttons. Plain entries and exit cushions are independent
  of this change. The routing resolver is unchanged and still classifies the
  final limit against the quotes.
- `Cover 1/1 Ask+` cancels working orders for the montage symbol, then uses the
  native `Share=Pos; SEND=Reverse` command at Ask plus the smaller of `$exitOffset`
  and `Ask * $exitOffsetMaxPct` (or the fixed offset when the ceiling is disabled). DAS resolves the position
  quantity and direction internally; for a short it sends a buy for the full
  short based on the position visible at submission. An older order can still
  fill after cancellation is requested. If invoked while long, `SEND=Reverse` closes
  the long with a sell, so treat this as a full-position close hotkey.
- `Cover 1/2 Ask+` and `Cover 1/4 Ask+` use the same native Reverse command
  and the same capped Ask+ pricing for half or a quarter of the current position.
  Quantities are calculated after cancelling older orders, rounded down to
  whole shares, and clamped to at least one share and at most the current position.
  They do nothing while flat and abort if the montage account or symbol changes.
  Like Cover 1/1, they reduce a long if invoked while long. That long-side use
  does not enter the half/quarter sell protection workflow and does not restore
  long protection automatically; use the Sell hotkeys for managed long partials.
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
- `Cancel All` cancels orders for its account/symbol and restores enabled stop
  protection in either direction. Short protection waits for BUY cancellation
  acknowledgment through the timer before submitting a replacement stop.
- `GTFO` cancels only its account/symbol orders and sends a full-size limit exit
  through BESTL in AUTOL mode or the configured `$gtfoRoute` in manual mode.
  It subtracts the smaller of `$0.50` and `Bid * $gtfoOffsetMaxPct` for longs,
  or adds the smaller of `$0.50` and `Ask * $gtfoOffsetMaxPct` for shorts.
  At the default 5% ceiling, a `$0.20` Bid produces a `$0.19` long sell limit
  and a `$0.20` Ask produces a `$0.21` short cover limit. A positive minimum
  sell price also permits low-price exits when the cap is disabled.
  These remain limit orders: the current quote may differ from the broker's
  reference price, and neither acceptance nor execution is guaranteed.

## SELL ORDERS

The pre-coordinator sell/cover paths have been restored. Old rejected entry
templates do not veto a manual-position exit. The cancellation waits are settling
delays, not broker acknowledgments: rapid repeated presses can still overlap
orders and reverse a position. A replacement duplicate-order guard has not been
validated in DAS SIM.

Sell hotkeys are designed for manual partials and exits on long positions. They
cancel existing orders for the symbol to avoid conflicting routes, then send a
limit order. Half/quarter sell hotkeys retain their 100 ms cancellation-settle
wait, submit the order, and return. The timer watches actual fills, cancels any
residual shares at timeout, and waits for that order's open quantity to reach zero
before re-arming stops/TP for the actual remaining long. An order with zero open
shares alone is not proof of a fill. Missing position/average data postpones
protection rather than inventing a quantity or price.

### Standard sell orders

- Ask sells place a limit order at the current Ask (price first).
- Bid- sells place a limit order at Bid minus the smaller of `$exitOffset` and
  `Bid * $exitOffsetMaxPct` (or the fixed offset when the ceiling is disabled).
- Bid- prices are snapped to valid tick sizes and kept positive.
- After a full fill, partial fill, rejection, or timeout on half/quarter sells,
  the timer restores `Set Auto Stop` and `Set Take Profit` when enabled and a
  remaining long is confirmed. These stages never use `Wait`.
- Another partial, buy, or manual stop/TP adjustment in the same context is
  blocked until the exit finishes. GTFO, full exits, and Cancel All interrupt it.

### Break-even stop losses / sell orders

Break-even (BE) scripts move protection toward breakeven once a position is
working. Manual BE remains available with automatic stops off; timer-driven
TP adjustments are gated by `$useAutoStop` in the exit handler.

- For the standard BE scripts (1/1 and 1/2), if price has not reached the BE
  trigger (currently `$0.03` above avg cost), they place a BE limit sell.
- For longs, once Bid reaches the rounded average plus $0.03, those scripts
  place a stop-limit with that trigger and a limit at rounded average. Full-BE
  for shorts mirrors this: trigger at average minus $0.03 and limit at average;
  if Ask is above the trigger, it uses a buy limit near average instead.
- The scale-in BE script uses a stop-limit even before the trigger (stop at
  avg cost), then moves to a stop above BE once the trigger is cleared.
- Full-position BE supports longs and shorts. Half-position BE and scale-in BE
  support longs only. The helpers themselves do not gate on `$useAutoStop`;
  automatic entry/exit callers invoke them only when automatic stops are enabled.
  Thus a manual BE action can still submit protection with automatic stops off.

## STOP LOSSES

The scripts use fixed stop distances. The physical and Virtual Stream Deck
profiles retain the fixed-stop amount buttons; the former stop-mode buttons
on the two buy pages are now empty.

### Fixed stop losses

The existing RESET STOP LOSS button invokes `Set Auto Stop` (`Ctrl+Shift+S`).
It uses the signed account position and average cost, with a matching montage
as a fallback source:

| Position | Stop trigger | Stop-limit price | Shares protected |
| --- | --- | --- | --- |
| Long | Average cost minus `$stopLossTrigger` | Trigger minus `$exitOffset` | Current long shares |
| Short | Average cost plus `$stopLossTrigger` | Trigger plus `$exitOffset` | Absolute current short shares |
| Flat | No order | No order | None |

R is the same `$stopLossTrigger` selected by the existing amount buttons.
RESET cancels existing SELL orders for a long or BUY orders for a short,
then refreshes size and average. A flat or reversed position after the wait
aborts the submission. A retained short stop must acknowledge cancellation
before RESET replaces it; a pending cancellation logs a message without sending
an overlapping stop. When automatic stops are enabled the timer can complete
the replacement after confirmation; with stops off, press RESET again.
Missing position data or average cost prevents submission.
Long timer staging retains its existing behavior, including skipping cancels
in timer mode (`$timerMode`).

With `$useAutoStop = "Yes"`, actual short fills automatically arm this same
buy-stop logic on a timer tick. It protects the filled size and resizes after
later fills or changes to the signed position/average. Replacement waits for
the old stop's cancellation acknowledgment and uses fresh size; an already
executing stop whose open shares match the remaining short is left working.
Cover and new short-entry actions cancel previous protection, then resume
monitoring. A working cover must finish/cancel before a replacement stop is
placed for the remaining short. Cancel All restores protection when both
`$useAutoStop` and `$resetStopOnCancel` are enabled; Cancel All No Stops and
GTFO suppress rearming. With stops off, RESET remains available manually and
the timer does not automatically resize/re-arm it. The timer cancels a tracked
BUY stop if the position becomes flat or long. Full-position BE supports shorts;
half-BE and scale-in-BE helpers remain long-only. Resetting a short
stop preserves its current short TP alert and unfilled entry identity.

Short protection requires the Timer Event Script to be enabled. Recompile/load
the complete keymap, including the new unbound `Timer Short Stop Handler` and
`Check Working Buys` helpers. Existing Stream Deck RESET and stop-toggle
bindings need no changes. These regression checks model script decisions;
broker acceptance, stop triggering, and extended-hours behavior require
separate verification in DAS.

The stop-limit offset uses `$exitOffset`, without the ordinary-exit percentage
cap. The order is snapped to valid tick sizes and sent as a STOP/SLP order;
short limits are kept above the trigger. AUTOL and manual routing choices are
unchanged: these stops continue using STOP, independently of `$orderRoute`.
Use the fixed-stop preset hotkeys to set `$stopLossTrigger` to `$0.10`, `$0.20`,
`$0.30`, or `$0.50`; each preset writes the selected value to the DAS message
log.

## TAKE PROFIT

Take-profit is implemented as a DAS price alert that triggers an execution
hotkey. It is not a resting broker-side order.

`Set Take Profit` builds the alert using an R-based distance:
- Distance is `R * $takeProfitFactor`.
- R is `$stopLossTrigger`.
- Long target: average cost plus the distance; Last Sale must be above it.
- Short target: average cost minus the distance; Last Sale must be below it.
- A nonpositive target or a rounded target that is not on the profitable side
  does not create an alert. For low-priced shorts, choose a stop distance/factor
  that leaves a positive target. Automatic invalid-target messages are logged
  once per lifecycle; stop-loss protection remains independent.

The existing RESET TAKE PROFIT button and `Ctrl+Shift+T` support both
directions. Manual RESET can arm an alert even with the automatic TP toggle
off. When TP is on, short fills automatically arm/rebuild the alert through the
timer, including TP-only operation with stops off. No new Stream Deck button
or public binding is required.

When the alert fires, `Take Profit Executor`:
- Cancels existing SELL orders for a long, or BUY orders for a short, within
  the alert's account/symbol. A short TP waits for its BUY stop/covers to
  acknowledge cancellation before sending another BUY.
- Sells a partial long at Bid, or buys to cover a partial short at Ask, sized
  by `$takeProfitSize` (default 50%), or
  `$takeProfitSizeRehab` (also default 50%) when rehab is active in LIVE and in
  SIM when `$applyLiveGuardsToSim = 1`.
- Returns after submission, retaining only its initial 300 ms cancellation wait.
  The timer monitors fills for three seconds and confirms residual cancellation
  before resizing protection. A full requested reduction moves protection to BE;
  a partial fill, rejection, or timeout restores the fixed stop and TP alert for
  the remaining position. Short BE mirrors long BE: the normal buy-stop trigger
  is three cents below average with its limit at average. If Ask is already
  above that trigger, the existing full-BE function submits a buy limit at
  average instead, using the unchanged route resolver. With `$pegToBid = 1`,
  the short branch mirrors quote pegging by using a lower Ask for that limit.
  GTFO or manual cancellation can interrupt these stages.
- Consumes the alert revision after submission. A completed short TP is not
  automatically repeated; RESET or later additional shares/average changes
  can arm another target. Partial TP failure restores the fixed stop and TP
  alert for the actual remaining size, matching the long workflow.

TP alert names include account and symbol. Their scripts carry both identifiers,
trade generation, position direction and TP revision. Reset/replacement makes
old payloads stale; a short alert cannot act on a long or vice versa. Deferred
alerts retain their direction/revision while another action is waiting.
Cleanup is scoped to the original trade; unknown position data does not clear
another trade's protection.

For this upgrade, recompile/load the complete keymap and replace the installed
Timer Event Script with `other scripts/timer.das`. The updated timer forwards
short TP direction/revision when a cancellation handoff is deferred. Recreate
existing TP alerts with RESET TAKE PROFIT after installing the upgrade. DAS
must remain open with its timer and market data running for these alerts.

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
  shorts cover at `Ask + $exitOffset` through BESTL in AUTOL mode or `$gtfoRoute` in manual mode using native
  `SEND=Reverse`. Re-running `Set Global Variables` clears the script lock;
  montage unlock is manual (see reset instructions below).
- Single-position guard: when `$singlePositionGuard = 1`, buy hotkeys block another tracked long in the same account. Manual shorts are independent. The timer checks original account/symbol position records across montage changes. A confirmed flat/short releases the guard; unavailable position data retains it.
- Per-trade risk cap: blocks entries when projected risk exceeds
  `$riskCapDollars` (`$usePerTradeRiskCap`).

SIM vs LIVE: enabled hijack protection and rehab gating apply only in LIVE
unless `$applyLiveGuardsToSim = 1`; that setting defaults to `0`.
Hijack protection itself defaults to off and requires `$hijackProtection = 1`.
All other long-entry guard rails apply to buys in both SIM and LIVE; manual shorts bypass them.

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
- Submits a full-position native `Reverse` through BESTL in AUTOL mode or `$gtfoRoute` in manual mode: sells a long at
  `Bid - $exitOffset` or covers a short at `Ask + $exitOffset`.
- Locks all montage order buttons via `LockAllMontage Lock`.
- Sets `$HIJACKED_LOCKED` to block new buys.
- Plays a brief voice alert.

Reset behavior:
- `$HIJACKED_LOCKED` clears after restarting DAS, re-running `Set Global Variables`, or explicitly setting it to `0`.
- Montage lock must be manually cleared (UI lock icon or `LockAllMontage Unlock`).

## TIMER SCRIPT

`other scripts/timer.das` runs every second. It enforces hijack protection on Primary_OE only when enabled, visits every active account/symbol context for entry or partial-exit staging and cleanup, and executes deferred alerts once cancel/fill actions finish. Pending exits suspend entry-watch rearming until they finish or are interrupted. It does not switch a montage or clear trade state merely because Primary_OE shows another symbol.

Installation: replace the Timer Event Script with the complete current `other scripts/timer.das`; the hotkey compiler does not install it automatically. Recompile/reload the entire canonical keymap so all internal helpers exist, then run Set Global Variables. The short action lease pauses timer work during waits and expires after 30 seconds to recover an interrupted script. Pressing a second manual trading action during an active action logs a retry message instead of overwriting its context. GTFO is preserved as a queued emergency request and executes for its saved account/symbol as soon as the running action finishes.

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
- `set_order_route_bestl.das` sets `$orderRoute` to `BESTL`.
- `set_order_route_flash1l.das` sets `$orderRoute` to `FLASH1L`.
- `set_order_route_smrtl.das` sets `$orderRoute` to `SMRTL`.
- `set_order_route_autol.das` selects `AUTOL`, bound to `Alt+Ctrl+Win+7`.
- On page 5 of both the physical and Virtual Stream Deck profiles, the route button cycles through `AUTOL`, `FREE1L`, `BESTL`, `SMRTL`, `ARCA1L`, and `FLSH1L`. AUTOL is green, the next three are white, and the last two are red. This requires the local six-state Advanced Toggles update. The SMRTL preset sends `SMRTL`. `FLSH1L` remains a display label for the existing `FLASH1L` manual preset.
- AUTOL is a script mode, never a broker route. `Resolve Order Route` selects a concrete route immediately before each submission, without changing `$orderRoute`. After the urgent-exit override, it compares the final limit price (including offsets and rounding) with the opposite quote: buys/covers below Ask and sells/shorts above Bid select ARCA1L for expected adding liquidity, at any price. Buys/covers at or above Ask and sells/shorts at or below Bid are expected to take liquidity and retain the existing fee bands: BESTL for expected prices at/above $1; SMRTL below $1 when `price * 0.0036 > 0.0015`; BESTL otherwise, including equality. Taking buys/covers use Ask as the expected price; taking sells/shorts use Bid. FREE1L remains a manual option only. SMRT's $0.0015/share flat fee at all prices is based on broker confirmation. The sub-dollar bands compare routing fees; the $1+ band explicitly prefers BESTL. Adding/taking is a prediction from current quotes, not a post-only instruction or a guarantee of the eventual liquidity classification, rebate, execution price, or route acceptance.
- In AUTOL mode, urgent GTFO and hijack submissions use BESTL regardless of price. Manual route selections retain the existing independent `$gtfoRoute`. Native STOP orders remain STOP; breakeven exits that become ordinary limit orders use AUTOL. Missing required quotes prevent ordinary AUTOL submissions.
- AUTOL adds no route fallback, rejection retry, or automatic rerouting. Existing timer fill monitoring and cancellation behavior remains in place. Route availability is 04:00-20:00 ET; the operator monitors this window and executions. AUTOL performs no clock/timezone conversion or session gating. The same adding-liquidity selection and taking-liquidity fee bands apply in regular and extended hours.
- Rebuild and load the complete keymap, including the unbound `Resolve Order Route` helper. `Set Global Variables` selects AUTOL at startup and whenever LOAD CFG reloads the configuration. Manual route presets override it until the configuration is reloaded or AUTOL is selected again. Running the initializer directly does not synchronize the Stream Deck route display.
- `toggle_single_position_guard.das` toggles the single-position guard
  (`$singlePositionGuard`).
- `enable_rehab_mode.das` toggles rehab mode on/off; disabling requires typing `YES`.

Account and session:
- `set_global_variables.das` refreshes all global settings.
- `switch_to_sim.das` and `switch_to_live.das` set the Primary_OE account.

Order control:
- `cancel_all.das` cancels working orders and restores enabled stops for either
  direction; shorts wait for working BUY orders through the timer.
  `cancel_all_no_stops.das` cancels without re-arming.
- `gtfo.das` attempts a direction-aware limit exit for the full position, using
  a desired `$0.50` cushion below Bid for longs or above Ask for shorts. Its
  independent `$gtfoOffsetMaxPct` caps that cushion at 5% by default.

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
immediately. A clean fresh fill can arm stops/TP on the first timer tick that
observes it; replacing existing SELLs or scaling in takes a separate cancel tick.
There remains an unprotected window during staging, plus DAS processing and any
running action. Missing average-cost data postpones arming further. Set
`$useTimerArming = 0` and tune `$pollMs` and `$maxPolls` if you prefer inline
polling and more immediate protection.

Half/quarter long sells and automatic TP exits monitor fills on timer ticks instead of holding the
global action lease for two or three seconds. The timer interval still affects
when residual orders are canceled and remaining shares receive protection.
Delayed cancellation acknowledgment extends that window; after 30 seconds the
handler logs it once and continues waiting. GTFO remains available between ticks.
These performance changes were verified with the in-memory regression model;
check order status, stop acceptance, and route behavior in DAS SIM separately.

### Waiting for fills on buy orders

When `$useTimerArming = 1`, the timer handler waits for a position to appear
before arming stops/TP. If position size increases on later ticks, the handler
cancels existing sell orders, re-arms the stop, and only re-arms TP when the TP
reset conditions are met. If no fill appears within its captured `$longEntryTimeoutSeconds` (unless 0/INDEF), the handler
cancels the working buy order and clears pending state. When `$useTimerArming = 0`,
buy orders poll for fills and can accept partials based on `$acceptPartial` and
`$minFillShares`. If polling ends with any actual fill, the remainder is canceled
and protection is sized from fresh position data. If polling ends with no fill
and the order is still open, the script returns and the timer enforces the
original captured long deadline, including INDEF. A closed/rejected order with
no actual fill does not create protection. The poll duration is not added to
the captured timeout, although the action lease can delay timer processing.

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

## ENTRY TIMEOUT CONTROLS

### Which orders have a fill deadline?

| Order path | Scripted deadline / behavior |
| --- | --- |
| Long entry with no observed fill | Captured long timeout: 10s / 15s / 30s / INDEF |
| Short entry with no observed fill | Captured short timeout: 10s / 15s / 30s / INDEF, even with stop/TP features off |
| Timer-managed entry after first fill | No-fill deadline no longer applies; remainder can fill later and protection is resized |
| Inline buy after any fill | Cancels remainder after processing that fill or exhausting its bounded polling window |
| Half/quarter long sell | Default 2s, from `$maxPolls * $pollMs / 1000`; cancel residual and confirm before protection |
| Automatic TP sell/cover | 3s; cancel residual and confirm before protection |
| Full long sell, native manual cover, GTFO, or an ordinary BE limit | No scripted fill timeout; monitor/cancel the working limit order |
| STOP/SLP protection | No entry-timeout cancellation; triggering and order lifetime depend on DAS/broker handling and TIF |


On settings page 5, LONG TIMEOUT and SHORT TIMEOUT each cycle through
10s, 15s, 30s, INDEF. Both DAS defaults are 10s. INDEF stores 0 and disables
only the no-fill entry deadline; manual cancellation and GTFO still work.
Long presets are Ctrl+Alt+Shift+F9/F10/F11/F12, and short presets are
Ctrl+Alt+F9/F10/F11/F12, in that order. All plain/offset buy and short tiers
capture the selected side's timeout and submission second per account/symbol.
Selector changes and LOAD CFG affect future entries, not pending ones.
Cancellation is requested on the first eligible timer visit at/after the elapsed
second deadline; a paused timer, unavailable position data or broker cancellation
acknowledgment can delay it. First fills preserve the existing partial-fill logic.
Short no-fill deadlines work even with automatic stop and TP features off.

Buttons in the physical and Virtual profiles retain their own display state.
They send explicit preset hotkeys, so each press sets the displayed value in DAS.
After LOAD CFG/restarting DAS, cycle both controls back to the desired values;
DAS resets its defaults to 10s but cannot report those values to Stream Deck.
Compile/install the complete updated keymap before using the new buttons.

## ORDER DISPLAY / RESERVE SIZE

Entry orders created with `NewOrderObj()` set total shares but do not explicitly
set displayed shares. The repository does not implement a hidden/reserve mode.
Do not infer that an unset field guarantees full display or inherits montage
settings; that behavior has not been verified for this object API.

DAS documents `SShare` for montage-based commands, which is a separate path from
our order-object submissions. Reserve support on the exact broker route,
including short sales and extended hours, also needs confirmation. Do not add
an assumed `$order.Display` / `$order.SShare` property or treat a successful
in-memory test as proof that DAS accepts it. See the [review/setup status](README.md#documentation-and-deployment-status).

## REJECTED SHORT ENTRY / STUCK PENDING GUARD

A flat position does not prove an entry was canceled: an unfilled short order
could still execute. Long entry therefore remains blocked while short-entry or
short-cover cleanup is pending for the same account/symbol.

A rejected short can leave the `NewOrderObj()` submission object reporting a
nonzero `Open` value. The short timer now queries the recorded order with
`GetOrderObj` using account, symbol and exact RefNum instead of relying on that
submission object's `Open`/`GetInfo`. A recorded order with zero open shares
releases its entry-pending flag; actual signed position changes determine fills.

When no matching recorded order exists, the timer allows two elapsed seconds
for publication, requests cancellation of the original submission, and scans
that account/symbol's history for working SELL/short orders. It requires two
complete empty scans on distinct seconds and a fresh valid position read before
clearing the unresolved entry state. Histories beyond 200 records resume on
later ticks; a non-advancing lookup or missing position data does not release
the guard. A working SELL keeps it blocked. A racing short fill continues into
normal protection staging. These checks also run with the fill timeout set to
INDEF; INDEF does not preserve an unrecorded failed submission indefinitely.

This is reconciliation against the order/position data available in DAS, not
proof of broker acknowledgment or protection against arbitrarily delayed order
publication. Verify the fix in SIM, including rejected, accepted, and delayed
submissions, before using it live. Install the complete updated hotkey map;
the Timer Event Script itself is unchanged for this fix and must remain enabled.

An existing unresolved context is reconsidered on later timer ticks after the
updated handler is installed. For manual recovery, first verify both position
and working orders for the selected account/symbol, then use the existing
Cancel All workflow. LOAD CFG preserves trade objects and is not a pending-state
reset. Do not bypass the guard by zeroing flags while an order may still execute.
