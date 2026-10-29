# TODO

Feature candidates (risk & discipline guards), reviewed 2026-10-29. None of
these proposals is implemented by the current scripts. API availability and
event semantics must be verified against the installed DAS version before
designing a guard; intent/arming alone is not evidence that a stop filled.

- Max dollar exposure guard (pre-trade).
  - Cap intended position value using `shares * price` at entry time.
  - Optional: include existing position exposure (`abs(position shares) * Last`).
  - Enforce pre-send only (block order before execution).
  - Verify the available position/account fields. Any computed exposure needs fresh signed size, valid prices, pending-order accounting, and explicit behavior for unavailable data.

- Time-window trading lock.
  - Disable all entry hotkeys outside defined trading windows.
  - Implement via `GetSecond()` (seconds since midnight) with hardcoded session boundaries.
  - Centralize logic via global variable (e.g. `$TRADE_OK`) updated by Timer Event.
  - Current scripts use `GetSecond()` for elapsed time. A trading-session guard must handle midnight, local versus exchange time, daylight saving, and non-trading days; a fixed local-clock range alone is insufficient.

- Loss-streak / cooldown guard.
  - Pause new trade entries after N stop-outs.
  - Associate stop intent with the submitted order identity.
    - Track submission, acceptance, cancellation, and actual execution separately.
    - Increment a loss streak only after verified stop execution; an armed flag or a price touch alone is insufficient.
  - Ignore discretionary exits and scratch trades.
  - Enforce cooldown (time-based or session-based) that blocks entries but always allows exits.
  - Validate the order/trade fields needed to distinguish stop executions, manual exits, partial fills, and canceled orders before implementing this guard.

- Daily profit giveback guard (peak drawdown lock).
  - Validate a reliable account/session P&L source and reconciliation strategy; order intent is not realized P&L.
  - Track session peak P&L.
  - Once daily profit target is reached:
    - Lock new entries if >=50% of peak profits are given back.
  - Guard blocks all entry hotkeys; exits always allowed.
  - No same-day auto reset in live trading.
  - The repository currently maintains no P&L ledger. Verify native account fields and their update timing before choosing internal accounting; do not assume the API lacks them.
