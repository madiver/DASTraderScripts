# Changelog

All notable changes to this repository will be documented in this file.

## 0.2.1 - TBD
- Rename ice-breaker entry scripts from buy_10_* to buy_ib_* and update key bindings.
- Add dynamic stop mode for buy_ib entries with spread-based R and TP integration.
- Gate adaptive stop-limit offsets to dynamic-stop trades only (else use $exitOffset).
- Add dynamic stop toggle hotkey and keymap binding (Alt+Ctrl+Win+D).
- Clear dynamic stop state when flat via the timer script.
- Rename $TRLIVE to $LIVEACT and update references.
- Add USERGUIDE.md with setup, behavior, and workflow documentation.
- Document SIM/LIVE token replacement guidance for manual installs.
- Remove post-send stop verification delay and retry logic in Set Auto Stop to reduce stop placement latency (low risk).
- Set Auto Stop no longer forces focus to the Primary_OE montage before reading state.

## 0.2.0 - 2026-01-12
- Apply profit-only scale-in gate across all buy scripts (10/25/50 sizes).
- Use scale-in-specific BE stop when adding to existing positions.
- Align cancel-order sequencing to run after scale-in validation.
- Enforce projected total-size risk cap on all buy scripts.
- Ensure ice-breaker sizing never rounds to zero (minimum 5 shares) on buy_ib scripts.
- Fix buy_ib rehab scale-in gate to use the pre-entry position snapshot.

## 0.1.5 - 2026-01-10
- Increase $qtyMult to 5x (maxPositionSize now 750 shares).
- Remove 100 base share size buy hotkeys due to excessive size (e.g., 100 x qtyMult = 500 shares).
- Add 25 base share size buy hotkeys (e.g., 25 x qtyMult = 100 shares).

## 0.1.4 - 2026-01-08
- Change stop-loss presets: set_0_15_stop is now $0.15, set_0_20_stop is now $0.20.
- Rename stop-loss scripts to match new presets (set_0_20_stop -> set_0_15_stop, set_0_30_stop -> set_0_20_stop).

## 0.1.3 - 2026-01-02
- Add MIT license.
- Expand the README risk disclaimer.
- Link the DAS Hotkey Tools VS Code extension repo in the README.
- Add missing key binding for set_0_05_stop in keymap.yaml.
- Add Discord push notification webhook.

## 0.1.2 - 2026-01-01
- Switch-to-live/sim hotkeys now derive account mode from Primary_OE and update the AcctState button inline (requires AcctState button on Primary_OE).
- Session equity/baseline scripts resolve the active account from Primary_OE instead of $ACCOUNT_STATE.
- Rehab gates in buy hotkeys now detect live mode from Primary_OE and clean up warning text.
- Split STP/TP toggles into dedicated scripts and key bindings; removed the combined toggle.
- Global config now shows derived account mode, and globals no longer set $ACCOUNT_STATE.
- Show config now includes rehab/timing counters and session state (DAY_ACC, DAY_EQUITY_START, TRADING_LOCKED).

## 0.1.1 - 2025-12-29

- Enforced max daily loss using the global $maxDailyLoss value and made the lock sticky for the day.
- Manual starting equity now updates per-account baselines and clears the lock state.
- Partial sell hotkeys now re-arm stops and take-profit alerts after a full fill.
- Ignored local DAS Trader Docs folder in git.
- Bid-offset sell hotkeys now clamp prices to valid tick sizes and non-negative values.
- Full sell hotkeys now guard against zero/short positions to prevent accidental shorts.
- GTFO hotkey now ignores flat/short states to avoid opening shorts.
- Added macOS metadata files to .gitignore.

## 0.1.0 - 2025-12-26

- Initial public release of scripts, keymap, and build output.
