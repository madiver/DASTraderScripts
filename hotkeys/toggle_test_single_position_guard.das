// =====================
// TOGGLE TEST SINGLE-POSITION GUARD
// Group: Utilities & toggles
// =====================
// Simulates an active symbol lock for the single-position guard (test mode only).

if ($testMode != 1) {
   MsgLog("Enable test mode first.");
   return;
}

if ($singlePositionGuard != 1) {
   MsgLog("singlePositionGuard is disabled.");
   return;
}

$active = GetVar("TEST_SINGLE_POSITION_ACTIVE") * 1;
if ($active == 1) {
   $orig = GetVar("TEST_SINGLE_POSITION_ORIG");
   $singlePositionSymbol = $orig;
   SetVar("TEST_SINGLE_POSITION_ORIG", "");
   SetVar("TEST_SINGLE_POSITION_ACTIVE", "");
   MsgLog("Test single-position guard disabled.");
   return;
}

if ($DAY_ACC == "") {
   MsgLog("Set account mode first (Switch to Sim).");
   return;
}

if ($DAY_ACC != $TRSIM) {
   MsgLog("Test single-position guard is SIM-only.");
   return;
}

if ($singlePositionSymbol != "") {
   MsgLog("Single-position guard already tracking " + $singlePositionSymbol + ".");
   return;
}

$newSym = "$TEST";

SetVar("TEST_SINGLE_POSITION_ORIG", $singlePositionSymbol);
SetVar("TEST_SINGLE_POSITION_ACTIVE", 1);
$singlePositionSymbol = $newSym;

MsgLog("Test single-position guard enabled.\nActive symbol set to " + $singlePositionSymbol + ".");
