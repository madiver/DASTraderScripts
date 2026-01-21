# Stop Mode Modularization (0.3.1 Draft)

Goal: make stop placement modular and extensible by introducing a single stop-mode selector while preserving current behavior for STANDARD and DYNAMIC stops.

## Scope
- Add a `$stopMode` global that selects stop logic: `"STANDARD"` or `"DYNAMIC"`.
- Keep `$useAutoStop` as the master on/off switch (no `"NONE"` mode stored).
- Centralize stop placement in a single "stop engine" path used by timer and manual hotkeys.
- Do not implement structured stops yet; only leave a clean insertion point for later.

## Non-goals
- Change risk sizing or entry logic.
- Change order routes or TIF defaults.
- Modify take-profit or break-even behavior beyond honoring the stop mode.

## Proposed Config & Defaults
- New global: `$stopMode = "STANDARD"` in `set_global_variables.das`.
- Keep `$dynamicStop`, `$dynamicStopActive`, `$dynamicStopR` for backward compatibility.
- Effective mode:
  - If `$useAutoStop != "Yes"`, stop engine exits early.
  - Else use `$stopMode` to select logic.

## Stop Engine Behavior
- STANDARD: use `$stopLossTrigger` as 1R (current behavior).
- DYNAMIC: use `$dynamicStopR` when `$dynamicStopActive == 1`; otherwise fall back to `$stopLossTrigger`.
- Order send uses existing Stop/SLP behavior from `set_auto_stop.das` (no route or offset changes).

## Toggle / UX Flow
- `enable_dynamic_stop_mode.das` sets `$stopMode = "DYNAMIC"` and enables `$dynamicStop`.
- `enable_standard_stop_mode.das` sets `$stopMode = "STANDARD"` and disables `$dynamicStop`.

## Integration Points
- Manual: `set_auto_stop.das` becomes the stop engine (or calls a new `stop_engine.das`).
- Timer: `timer_entry_handler.das` calls the same engine.
- BE scripts remain unchanged but can read `$stopMode` if needed later.

## Migration Steps (0.3.1)
1) Add `$stopMode` default and show it in `show_config.das`.
2) Update `toggle_dynamic_stop.das` to set `$stopMode` and keep `$dynamicStop` in sync.
3) Refactor `set_auto_stop.das` into a mode-aware stop engine.
4) Update all call sites to use the stop engine.
5) Update docs (USERGUIDE + CHANGELOG).

## Testing Checklist
- STANDARD mode, auto-stop on: unchanged behavior.
- DYNAMIC mode, `dynamicStopActive = 1`: uses dynamic R for stops.
- DYNAMIC mode, `dynamicStopActive = 0`: falls back to `$stopLossTrigger`.
- `$useAutoStop = "No"`: no stop placement.
- Timer and manual hotkeys both route through the same engine.

## Open Questions
- Do we keep `$dynamicStop` long-term, or deprecate once `$stopMode` ships?
- Should BE scripts reference `$stopMode` to adjust offsets in dynamic mode?
