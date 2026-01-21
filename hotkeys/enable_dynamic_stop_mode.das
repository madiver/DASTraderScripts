// =====================
// ENABLE DYNAMIC STOP MODE
// Group: Utilities & toggles
// =====================
// Sets stop mode to DYNAMIC and enables dynamic stops (buy_ib only).

$stopMode = "DYNAMIC";
$dynamicStop = 1;
$dynamicStopActive = 0;
$dynamicStopR = 0;
$structuredOk = 0;
$structuredReason = 0;
$structuredType = "";
$structuredStop = 0;
$structuredR = 0;
$structuredSymbol = "";

MsgBox("Dynamic stop mode enabled (buy_ib only).");
