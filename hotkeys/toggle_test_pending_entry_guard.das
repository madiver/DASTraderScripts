// =====================
// TOGGLE TEST PENDING ENTRY GUARD
// Group: Utilities & toggles
// =====================
// Simulates a pending entry state for the guard check (test mode only).

if ($testMode != 1) {
   MsgBox("Enable test mode first.");
   return;
}

$active = GetVar("TEST_PENDING_ENTRY_ACTIVE") * 1;
if ($active == 1) {
   $entryPending = GetVar("TEST_PENDING_ENTRY_ORIG_PENDING") * 1;
   $entrySymbol  = GetVar("TEST_PENDING_ENTRY_ORIG_SYMBOL");
   $entryStage   = GetVar("TEST_PENDING_ENTRY_ORIG_STAGE") * 1;
   $entryTicks   = GetVar("TEST_PENDING_ENTRY_ORIG_TICKS") * 1;

   SetVar("TEST_PENDING_ENTRY_ORIG_PENDING", "");
   SetVar("TEST_PENDING_ENTRY_ORIG_SYMBOL", "");
   SetVar("TEST_PENDING_ENTRY_ORIG_STAGE", "");
   SetVar("TEST_PENDING_ENTRY_ORIG_TICKS", "");
   SetVar("TEST_PENDING_ENTRY_ACTIVE", "");

   MsgBox("Test pending-entry guard disabled.");
   return;
}

if ($DAY_ACC == "") {
   MsgBox("Set account mode first (Switch to Sim).");
   return;
}

if ($DAY_ACC != $TRSIM) {
   MsgBox("Test pending-entry guard is SIM-only.");
   return;
}

if ($entryPending == 1 || $entryStage > 0) {
   MsgBox("Entry staging already active. Clear it before testing.");
   return;
}

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
   MsgBox("Primary_OE not found.");
   return;
}

if ($M.Pos > 0) {
   MsgBox("Flatten before testing the pending-entry guard.");
   return;
}

$curSym = $M.Symb;
$newSym = "TEST_PENDING";
if ($curSym != "") { $newSym = $curSym + "_PENDING"; }

SetVar("TEST_PENDING_ENTRY_ORIG_PENDING", $entryPending);
SetVar("TEST_PENDING_ENTRY_ORIG_SYMBOL", $entrySymbol);
SetVar("TEST_PENDING_ENTRY_ORIG_STAGE", $entryStage);
SetVar("TEST_PENDING_ENTRY_ORIG_TICKS", $entryTicks);
SetVar("TEST_PENDING_ENTRY_ACTIVE", 1);

$entryPending = 1;
$entrySymbol = $newSym;
$entryStage = 0;
$entryTicks = 0;
$entryScaleIn = 0;
$entryDynR = 0;

MsgBox("Test pending-entry guard enabled.\nPending symbol set to " + $entrySymbol + ".");
