// =====================
// TOGGLE TEST HIJACK GUARD
// Group: Utilities & toggles
// =====================
// Tests hijack protection by lowering max position size (test mode only).

if ($testMode != 1) {
   MsgBox("Enable test mode first.");
   return;
}

$accName = $DAY_ACC;
if ($accName == "") {
   MsgBox("Set account mode first (Switch to Sim).");
   return;
}

$active = GetVar("TEST_HIJACK_ACTIVE") * 1;
if ($active == 1) {
   $orig = GetVar("TEST_HIJACK_ORIG_MAXPOS");
   if ($orig != "") { $maxPositionSize = $orig * 1; }
   SetVar("TEST_HIJACK_ORIG_MAXPOS", "");
   SetVar("TEST_HIJACK_ACTIVE", "");
   MsgBox("Test hijack guard disabled for " + $accName + ".\nIf hijack triggered, run Set Global Variables to clear the lock.");
   return;
}

if ($accName != $TRSIM) {
   MsgBox("Test hijack guard is SIM-only.");
   return;
}

if ($applyLiveGuardsToSim != 1) {
   MsgBox("Hijack guard is disabled in SIM (applyLiveGuardsToSim=0).");
   return;
}

if ($hijackProtection != 1) {
   MsgBox("hijackProtection is disabled.");
   return;
}

if ($HIJACKED_LOCKED == 1) {
   MsgBox("Hijack lock already active. Run Set Global Variables to clear.");
   return;
}

if (GetVar("TEST_MAX_POSITION_ACTIVE") * 1 == 1) {
   MsgBox("Disable the max position size test first.");
   return;
}

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
   MsgBox("Primary_OE not found.");
   return;
}

$posNow = $M.Pos;
if ($posNow < 2) {
   MsgBox("Open at least 2 shares to test hijack protection.");
   return;
}

SetVar("TEST_HIJACK_ORIG_MAXPOS", $maxPositionSize);
SetVar("TEST_HIJACK_ACTIVE", 1);
$maxPositionSize = $posNow - 1;

MsgBox("Test hijack guard enabled for " + $accName + ".\nWait for the next timer tick to trigger.");
