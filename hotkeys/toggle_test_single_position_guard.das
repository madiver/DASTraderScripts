// =====================
// TOGGLE TEST SINGLE-POSITION GUARD
// Group: Utilities & toggles
// =====================
// Simulates an active symbol lock for the single-position guard (test mode only).

if ($testMode != 1) {
   MsgBox("Enable test mode first.");
   return;
}

if ($singlePositionGuard != 1) {
   MsgBox("singlePositionGuard is disabled.");
   return;
}

$active = GetVar("TEST_SINGLE_POSITION_ACTIVE") * 1;
if ($active == 1) {
   $orig = GetVar("TEST_SINGLE_POSITION_ORIG");
   $singlePositionSymbol = $orig;
   SetVar("TEST_SINGLE_POSITION_ORIG", "");
   SetVar("TEST_SINGLE_POSITION_ACTIVE", "");
   MsgBox("Test single-position guard disabled.");
   return;
}

if ($DAY_ACC == "") {
   MsgBox("Set account mode first (Switch to Sim).");
   return;
}

if ($DAY_ACC != $TRSIM) {
   MsgBox("Test single-position guard is SIM-only.");
   return;
}

if ($singlePositionSymbol != "") {
   MsgBox("Single-position guard already tracking " + $singlePositionSymbol + ".");
   return;
}

$newSym = "$TEST";

SetVar("TEST_SINGLE_POSITION_ORIG", $singlePositionSymbol);
SetVar("TEST_SINGLE_POSITION_ACTIVE", 1);
$singlePositionSymbol = $newSym;

MsgBox("Test single-position guard enabled.\nActive symbol set to " + $singlePositionSymbol + ".");
