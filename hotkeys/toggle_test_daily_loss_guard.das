// =====================
// TOGGLE TEST DAILY LOSS GUARD
// Group: Utilities & toggles
// =====================
// Toggles a daily-loss guard test by shifting DAY_EQUITY_START (test mode only).

if ($testMode != 1) {
   MsgLog("Enable test mode first.");
   return;
}

$accName = $DAY_ACC;
if ($accName == "") {
   MsgLog("Set account mode first (Switch to Sim).");
   return;
}

$testKey = "TEST_DAY_EQUITY_START_" + $accName;
$saved = GetVar($testKey);

if ($saved == "") {
   if ($accName != $TRSIM) {
      MsgLog("Test daily loss guard is SIM-only.");
      return;
   }

   if ($applyLiveGuardsToSim != 1) {
      MsgLog("Daily loss guard is disabled in SIM (applyLiveGuardsToSim=0).");
      return;
   }

   $base = GetVar("DAY_EQUITY_START");
   if ($base == "") {
      MsgLog("DAY_EQUITY_START not set. Run Initialize Session Equity.");
      return;
   }

   $limit = $maxDailyLoss;
   if ($limit <= 0) {
      MsgLog("maxDailyLoss must be > 0.");
      return;
   }

   $acc = GetAccountObj($accName);
   $eqNow = $acc.Equity;
   if ($eqNow <= 0) {
      MsgLog("Equity unavailable for " + $accName + ".");
      return;
   }

   SetVar($testKey, $base);
   $newBase = $eqNow + $limit + 1;
   SetVar("DAY_EQUITY_START", $newBase);
   MsgLog("Test daily loss guard enabled for " + $accName + ".\nWait for next timer tick to lock.");
} else {
   SetVar("DAY_EQUITY_START", $saved);
   SetVar($testKey, "");
   MsgLog("Test daily loss guard disabled for " + $accName + ".\nGuard will clear after the next timer tick.");
}
