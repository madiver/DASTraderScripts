# TODO

Feature candidates (risk & discipline guards):

- Max dollar exposure guard (pre-trade).
  - Cap intended position value using `shares * price` at entry time.
  - Optional: include existing position exposure (`abs(position shares) * Last`).
  - Enforce pre-send only (block order before execution).
  - Note: DAS does not expose a native "position value" field, but exposure can be computed reliably via shares * price in hotkeys.

- Time-window trading lock.
  - Disable all entry hotkeys outside defined trading windows.
  - Implement via `GetSecond()` (seconds since midnight) with hardcoded session boundaries.
  - Centralize logic via global variable (e.g. `$TRADE_OK`) updated by Timer Event.
  - Note: DAS does not expose date or clock objects; time comparisons must be done using `GetSecond()` only.

- Loss-streak / cooldown guard.
  - Pause new trade entries after N stop-outs.
  - Stop-outs detected via **stop-intent tagging**, not fill inference.
    - Mark stop as "armed" at entry.
    - Increment loss streak only when armed stop is hit.
  - Ignore discretionary exits and scratch trades.
  - Enforce cooldown (time-based or session-based) that blocks entries but always allows exits.
  - Note: DAS cannot natively distinguish stop exits vs manual exits; intent-based tracking is required.

- Daily profit giveback guard (peak drawdown lock).
  - Track session P&L internally via globals/intent tagging.
  - Track session peak P&L.
  - Once daily profit target is reached:
    - Lock new entries if >=50% of peak profits are given back.
  - Guard blocks all entry hotkeys; exits always allowed.
  - No same-day auto reset in live trading.
  - Note: DAS does not provide script-safe realized P&L; P&L must be tracked via globals.
