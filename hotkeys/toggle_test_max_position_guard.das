// =====================
// TOGGLE TEST MAX POSITION GUARD
// Group: Utilities & toggles
// =====================
// Tests the max-position-size guard by setting max to current position (test mode only).

if ($testMode != 1) {
   MsgBox("Enable test mode first.");
   return;
}

$active = GetVar("TEST_MAX_POSITION_ACTIVE") * 1;
if ($active == 1) {
   $orig = GetVar("TEST_MAX_POSITION_ORIG");
   if ($orig != "") { $maxPositionSize = $orig * 1; }
   SetVar("TEST_MAX_POSITION_ORIG", "");
   SetVar("TEST_MAX_POSITION_ACTIVE", "");
   MsgBox("Test max-position guard disabled.");
   return;
}

if ($DAY_ACC == "") {
   MsgBox("Set account mode first (Switch to Sim).");
   return;
}

if ($DAY_ACC != $TRSIM) {
   MsgBox("Test max-position guard is SIM-only.");
   return;
}

if (GetVar("TEST_HIJACK_ACTIVE") * 1 == 1) {
   MsgBox("Disable the hijack test first.");
   return;
}

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
   MsgBox("Primary_OE not found.");
   return;
}

$posNow = $M.Pos;
if ($posNow <= 0) {
   MsgBox("Open a position to test the max-position guard.");
   return;
}

SetVar("TEST_MAX_POSITION_ORIG", $maxPositionSize);
SetVar("TEST_MAX_POSITION_ACTIVE", 1);
$maxPositionSize = $posNow;

MsgBox("Test max-position guard enabled.\nMax set to " + $maxPositionSize + " shares.");
