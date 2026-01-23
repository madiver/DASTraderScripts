// =====================
// TOGGLE TEST MAX POSITION GUARD
// Group: Utilities & toggles
// =====================
// Tests the max-position-size guard by setting max to current position (test mode only).

if ($testMode != 1) {
   MsgLog("Enable test mode first.");
   return;
}

$active = GetVar("TEST_MAX_POSITION_ACTIVE") * 1;
if ($active == 1) {
   $orig = GetVar("TEST_MAX_POSITION_ORIG");
   if ($orig != "") { $maxPositionSize = $orig * 1; }
   SetVar("TEST_MAX_POSITION_ORIG", "");
   SetVar("TEST_MAX_POSITION_ACTIVE", "");
   MsgLog("Test max-position guard disabled.");
   return;
}

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
   MsgLog("Primary_OE not found.");
   return;
}

$acct = StrTrim("" + $M.Account);
if (StrLen($acct) == 0) {
   MsgLog("Set account mode first (Switch to Sim).");
   return;
}

if (StrFind($acct, "TR") != 0) {
   MsgLog("Test max-position guard is SIM-only.");
   return;
}

if (GetVar("TEST_HIJACK_ACTIVE") * 1 == 1) {
   MsgLog("Disable the hijack test first.");
   return;
}

$posNow = $M.Pos;
if ($posNow <= 0) {
   MsgLog("Open a position to test the max-position guard.");
   return;
}

SetVar("TEST_MAX_POSITION_ORIG", $maxPositionSize);
SetVar("TEST_MAX_POSITION_ACTIVE", 1);
$maxPositionSize = $posNow;

MsgLog("Test max-position guard enabled.\nMax set to " + $maxPositionSize + " shares.");
