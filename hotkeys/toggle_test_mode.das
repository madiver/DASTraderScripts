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

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
   MsgLog("Primary_OE not found.");
   return;
}

$accName = StrTrim("" + $M.Account);
if (StrLen($accName) == 0) {
   MsgLog("Set account mode first (Switch to Sim).");
   return;
}

if (StrFind($accName, "TR") != 0) {
   MsgLog("Test mode is SIM-only.");
   return;
}

$testMode = 1;
MsgLog("Test mode enabled.");
