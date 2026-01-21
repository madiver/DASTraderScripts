// =====================
// TOGGLE TEST MODE
// Group: Utilities & toggles
// =====================
// Toggles $testMode (skip market-dependent checks and order sends).

if ($testMode == 1) {
   $testMode = 0;
   MsgLog("Test mode disabled.");
   return;
}

$accName = $DAY_ACC;
if ($accName == "") {
   MsgLog("Set account mode first (Switch to Sim).");
   return;
}

if ($accName != $TRSIM) {
   MsgLog("Test mode is SIM-only.");
   return;
}

$testMode = 1;
MsgLog("Test mode enabled.");
