# Changelog

All notable changes to this repository will be documented in this file.

## 0.3.3 - Unreleased

### Features
- Add configurable tier base sizes—`$tier1ShareSize` 50 (MIB), `$tier2ShareSize` 100 (IB), `$tier3ShareSize` 200 (`buy_25_*`), and `$tier4ShareSize` 300 (`buy_50_*`)—scaled together by `$qtyMult` (default `1.0`).
- Add hotkey presets for setting `$qtyMult` to `0.5x`, `1.0x`, `2.0x`, or `3.0x`.
- Add isolated manual hotkeys to sell short Tier 1 at Ask and cover 100% at Ask without arming long-side stops, take profit, or entry state.
- Add a `$0.30` fixed stop-loss preset bound to `Alt+Ctrl+Win+=`.
- Add a `$0.50` fixed stop-loss preset bound to `Alt+Ctrl+Win+5`.

### Bug Fixes
- Use DAS native `Share=Pos; SEND=Reverse` for full-position covers so short quantities are resolved correctly instead of relying on the advanced montage `Pos` sign.
- Price the full-position cover at `Ask + $exitOffset` to improve execution probability during fast upward moves.
- Make GTFO direction-aware: long positions exit at Bid minus $0.50 and short positions cover at Ask plus $0.50 using `$gtfoRoute` and native `SEND=Reverse`.
- Use signed `GetCurrPos()` in Cancel All so automatic long stops are never re-armed for short positions.
- Snap Cover and direction-aware GTFO prices to valid route tick increments so aggressive exits are not rejected for sub-penny prices.

## 0.3.2 - 2026-02-11

### Features
- Add manual backstop alert to trigger aggressive limit exits on fast flushes.
- Add `$gtfoRoute` defaulting to `FLASHL` for emergency exits (GTFO/backstop).

### Bug Fixes
- Prevent structured stop state from clearing during pending entry staging.

## 0.3.1 - 2026-01-26

### Features
- Add `$stopMode` ("FIXED", "DYNAMIC", or "STRUCTURED") to modularize stop logic.
- Replace the dynamic-stop toggle with explicit FIXED/dynamic stop mode scripts and key bindings.
- Rename STANDARD stop mode to FIXED.
- Add a structured stop mode toggle script and binding (Alt+Ctrl+Win+S).
- Implement structured stop validation and gating (IB-only for new entries), tied to Chart_1m live data.
- Use structured stop distance for take-profit calculations and stop placement when structured mode is active.
- Normalize symbols in single-position guard tracking to avoid stale locks.
- Re-add $0.10/$0.20 stop-loss preset scripts and key bindings.
- Add micro ice breaker buy hotkeys (buy_mib_*) sized at 1/30 of the base clip.
- Update micro ice breaker sizing to 1/20 of the base clip.
- Add `$orderRoute` global to configure limit order routing (default ARCAL).
- Add hotkeys to switch `$orderRoute` between ARCAL and FREEL.
- Show structured stop failure reason text in entry rejection popups.
- Lower default structured stop buffer to $0.01.
- Swap non-blocking status messages from MsgBox to MsgLog for toggles and stop presets.

### Bug Fixes
- BE stop scripts no longer gate on `$useAutoStop`; BE adjustments still run when auto stops are disabled.

### Cleanup
- Remove daily loss guard, equity baseline hotkeys, and related UI/docs.

## 0.3.0 - 2026-01-20

### Features
- Track daily loss guard health via `DAY_GUARD_OK` and surface it in the config display.
- Auto-unlock the daily loss guard when drawdown drops back below `maxDailyLoss`.
- Add rehab mode toggle hotkey bound to Alt+Ctrl+Win+H.
- Require typed `YES` confirmation to disable rehab mode.
- Add rehab-specific take-profit sizing via `$takeProfitSizeRehab` (applied at trigger time in LIVE and SIM when `$applyLiveGuardsToSim = 1`).
- Add live-only hijack protection that triggers GTFO, locks montages, and blocks new buys when position size exceeds max.
- Add `$applyLiveGuardsToSim` to apply daily loss, hijack, and rehab guards in SIM.
- Default `$applyLiveGuardsToSim` to `1` (guards apply in SIM).
- Add toggle hotkey for `$applyLiveGuardsToSim` (Alt+Ctrl+Win+G).
- Add timer re-arm tracking state (`entryWatch`, `entryLastPos`) to globals and config display.
- Default `$timerMode` to `1` so timer-triggered hotkeys run in timer context by default.
- Add single-position guard (default on) to block buys on a different symbol (script-tracked).
- Add toggle hotkey for the single-position guard (Alt+Ctrl+Win+M).
- Add `$testMode` to skip market-dependent checks and order sends for guard testing.
- Add toggle hotkey for test mode (Alt+Ctrl+Win+T).
- Add test daily loss guard toggle (Alt+Ctrl+Shift+Win+1).
- Add test guard toggles for hijack, single-position, pending entry, and max position size (Alt+Ctrl+Shift+Win+2/3/4/5).
- Restrict test mode and test toggles to SIM when enabling.
- Set default `maxPositionSize` to 500 shares.

### Bug Fixes
- Bind session account from SIM/LIVE switch hotkeys to keep daily loss guard aligned with explicit mode switches.
- Require a set session account for equity baseline scripts (no implicit SIM fallback).
- Check PnL now resolves the session account and baseline internally instead of assuming pre-set variables.
- Fix GTFO to read position from Primary_OE before sending the exit.
- Fix TP executor symbol handoff and pass TP symbol to BE stop scripts.
- Round BE 1/2 protect sizes to whole shares.
- Guard position/primary entry utility scripts when windows are missing.
- Define $tpSymbol and $pegToBid defaults for TP/BE handling.
- Risk cap now uses net risk to the planned stop (including BE scale on adds) when sizing entries.
- Block buy_25/buy_50 initial entries when dynamic stop mode is enabled (warns via MsgBox).
- Cancel timed-out timer-based buy entries instead of leaving them working.
- Re-arm stop/TP on timer ticks when position size increases after a fill.
- Gate buy_25/buy_50 scale-ins on dynamic R when `dynamicStop = 1` and `dynamicStopActive = 1`.
- Cancel existing sell orders before timer-based re-arms on size increases.
- Cancel pending buy orders when montage symbol changes during timer staging to avoid unprotected fills.
- Clamp GTFO exit price to a valid tick and non-negative value when quotes are missing or low.
- Block buys when no session account is set (enforces daily-loss guard setup).
- Set and clear `entryRefPx` so stop fallbacks don't anchor to stale values.
- Keep pending-entry blocking active while allowing the single-position guard to be disabled.
- Move hijack exit enforcement into a dedicated hotkey (`Hijack Exit`) called by the timer to avoid timer script size limits and ensure timer-safe order sends.

### Cleanup
- Update README/USERGUIDE to highlight the user guide, hijack protection, and default globals.
- Expand README/USERGUIDE quick start with constraints and VS Code extension settings.
- Rename `$highJackProtection` to `$hijackProtection`.
- Centralize global buy guards in `Check Global Guards` and expose `$trade_ok`.
- Move the position window toggle hotkey to Alt+Ctrl+Win+P.
- Add a key bindings section to USERGUIDE with Stream Deck guidance and unbound script notes.
- Expand key binding descriptions for clarity and remove confusing wording in SIM/LIVE switch rows.

## 0.2.1 - 2026-01-15

### Features
- Rename ice-breaker entry scripts from buy_10_* to buy_ib_* and update key bindings.
- Add dynamic stop mode for buy_ib entries with spread-based R and TP integration.
- Add dynamic stop toggle hotkey and keymap binding (Alt+Ctrl+Win+D).
- Route entry hotkeys to timer-based stop/TP staging so you can exit immediately; fresh entries skip SELL cancels.

### Bug Fixes
- Gate adaptive stop-limit offsets to dynamic-stop trades only (else use $exitOffset).
- Clear dynamic stop state when flat via the timer script.
- Set Auto Stop no longer forces focus to the Primary_OE montage before reading state.
- Set Take Profit now reads symbol/position from Primary_OE to support timer-based arming.
- Fix Take Profit Executor symbol comparison to avoid unnecessary montage switching.

### Cleanup
- Rename $TRLIVE to $LIVEACT and update references.
- Add USERGUIDE.md with setup, behavior, and workflow documentation.
- Document SIM/LIVE token replacement guidance for manual installs.
- Remove post-send stop verification delay and retry logic in Set Auto Stop to reduce stop placement latency (low risk).

## 0.2.0 - 2026-01-12

### Features
- Apply profit-only scale-in gate across all buy scripts (10/25/50 sizes).
- Use scale-in-specific BE stop when adding to existing positions.
- Enforce projected total-size risk cap on all buy scripts.

### Bug Fixes
- Align cancel-order sequencing to run after scale-in validation.
- Ensure ice-breaker sizing never rounds to zero (minimum 5 shares) on buy_ib scripts.
- Fix buy_ib rehab scale-in gate to use the pre-entry position snapshot.

### Cleanup
- None.

## 0.1.5 - 2026-01-10

### Features
- Increase $qtyMult to 5x (maxPositionSize now 750 shares).
- Remove 100 base share size buy hotkeys due to excessive size (e.g., 100 x qtyMult = 500 shares).
- Add 25 base share size buy hotkeys (e.g., 25 x qtyMult = 100 shares).

### Bug Fixes
- None.

### Cleanup
- None.

## 0.1.4 - 2026-01-08

### Features
- None.

### Bug Fixes
- None.

### Cleanup
- None.

## 0.1.3 - 2026-01-02

### Features
- Add Discord push notification webhook.

### Bug Fixes
- None.

### Cleanup
- Add MIT license.
- Expand the README risk disclaimer.
- Link the DAS Hotkey Tools VS Code extension repo in the README.

## 0.1.2 - 2026-01-01

### Features
- Switch-to-live/sim hotkeys now derive account mode from Primary_OE and update the AcctState button inline (requires AcctState button on Primary_OE).
- Split STP/TP toggles into dedicated scripts and key bindings; removed the combined toggle.
- Global config now shows derived account mode, and globals no longer set $ACCOUNT_STATE.
- Show config now includes rehab/timing counters and session state (DAY_ACC, DAY_EQUITY_START, TRADING_LOCKED).

### Bug Fixes
- Session equity/baseline scripts resolve the active account from Primary_OE instead of $ACCOUNT_STATE.
- Rehab gates in buy hotkeys now detect live mode from Primary_OE and clean up warning text.

### Cleanup
- None.

## 0.1.1 - 2025-12-29

### Features
- Enforced max daily loss using the global $maxDailyLoss value and made the lock sticky for the day.
- Manual starting equity now updates per-account baselines and clears the lock state.

### Bug Fixes
- Partial sell hotkeys now re-arm stops and take-profit alerts after a full fill.
- Bid-offset sell hotkeys now clamp prices to valid tick sizes and non-negative values.
- Full sell hotkeys now guard against zero/short positions to prevent accidental shorts.
- GTFO hotkey now ignores flat/short states to avoid opening shorts.

### Cleanup
- Ignored local DAS Trader Docs folder in git.
- Added macOS metadata files to .gitignore.

## 0.1.0 - 2025-12-26

### Features
- Initial public release of scripts, keymap, and build output.

### Bug Fixes
- None.

### Cleanup
- None.
