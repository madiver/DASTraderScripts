// =====================
// TOGGLE TEST MODE
// Group: Utilities & toggles
// =====================
// Toggles $testMode (skip market-dependent checks and order sends).

if ($testMode == 1) {
   $testMode = 0;
   MsgBox("Test mode disabled.");
   return;
}

$accName = $DAY_ACC;
if ($accName == "") {
   MsgBox("Set account mode first (Switch to Sim).");
   return;
}

if ($accName != $TRSIM) {
   MsgBox("Test mode is SIM-only.");
   return;
}

$testMode = 1;
MsgBox("Test mode enabled.");
