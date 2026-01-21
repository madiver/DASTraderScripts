// ============================================================
// LIVE CANDLE SNAPSHOT (FORMING BAR)
//
// Purpose:
//   Capture real-time auction state for the CURRENT 1-minute
//   candle and expose it via standard globals for use by other
//   DAS scripts (hotkeys, timers, validation checks).
//
// What these values ARE:
//   - Live, tick-by-tick updates from the chart engine
//   - Context for intrabar behavior (tests, rejections, extensions)
//
// What these values are NOT:
//   - Completed candle data
//   - Safe for pattern or bar-close confirmation
//
// Usage rules (important):
//   - Use $CURR_* values for CONTEXT and ANTICIPATION only
//   - Use GetBar(-1) and older bars for CONFIRMED decisions
//   - Globals are ephemeral and reset on symbol change/reload
//   - If multiple charts run this script, last update wins
//
// Typical use cases:
//   - Rejection micro-pullback detection
//   - Live stop anchoring or trailing
//   - Entry clearance and extension guards
//   - Real-time dashboards / indicators
// ============================================================


// ===== LIVE CANDLE VALUES (FORMING BAR) =====
$CURR_LAST = GetChartLv1("Last");    // current traded price
$CURR_OPEN = GetChartLv1("Open");    // open of the current 1-min candle (stable)
$CURR_HIGH = GetChartLv1("High");    // high so far (updates live)
$CURR_LOW  = GetChartLv1("Low");     // low so far (updates live)

// Optional: accumulating volume for the forming candle
$CURR_VOL  = GetChartLv1("Volume");