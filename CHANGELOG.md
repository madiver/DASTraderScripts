# Changelog

All notable changes to this repository will be documented in this file.

## 0.1.3 - 2026-01-02
- Add MIT license.
- Expand the README risk disclaimer.
- Link the DAS Hotkey Tools VS Code extension repo in the README.
- Add a key binding for set_0_05_stop in keymap.yaml.
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
