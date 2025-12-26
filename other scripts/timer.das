// ==============================
// EQUITY-BASED DAILY LOSS GUARD
// Ignore: True
// ==============================

// Load current account and its starting equity
$accName = GetVar("DAY_ACC");
if ($accName == "" ) { return; }

if ($accName == $TRLIVE) {

    $eqStartStr = GetVar("DAY_EQUITY_START");
    if ($eqStartStr == "") { return; }

    $eqStart = $eqStartStr * 1;
    if ($eqStart <= 0) { return; }

    // Read current equity for this account
    $acc   = GetAccountObj($accName);
    $eqNow = $acc.Equity;
    if ($eqNow <= 0) { return; }

    // Compute drawdown
    $dd = $eqStart - $eqNow;

    // Configurable daily loss limit
    $limitStr = GetVar("DAILY_MAX_LOSS");
    $limit    = $limitStr * 1;
    if ($limitStr == "" || $limit <= 0) {
        $limit = 50.00;   // default to $50 if unset/invalid
    }

    // Per-account lock key
    $lockKey = "TRADING_LOCKED_" + $accName;
    $lockedStr = GetVar($lockKey);
    $locked    = $lockedStr * 1;

    // If over limit and not already locked, lock this account
    if ($dd >= $limit && $locked == 0) {

        // Set per-account lock
        SetVar($lockKey, 1);

        // Also set current lock mirror
        SetVar("TRADING_LOCKED", 1);

    }

    // If back under limit and currently locked, unlock this account
    if ($dd < $limit && $locked == 1) {

        // Clear per-account lock
        SetVar($lockKey, 0);

        // Clear current lock mirror
        SetVar("TRADING_LOCKED", 0);

    }

}

// =======================================
// FLAT POSITION → DELETE TP ALERTS
// =======================================

$oneSecondScriptCnt = $oneSecondScriptCnt + 1;

if ($oneSecondScriptCnt % 5 ==0) {

    $oneSecondScriptCnt= 0;

    // Make sure we can access Primary_OE
    $M = GetWindowObj("Primary_OE");
    if (!IsObj($M)) { return; }

    // Snapshot symbol and position
    $mySym  = $M.Symb;
    $posNow = $M.Pos;

    // Only act if FLAT
    if ($mySym != "" && $posNow == 0) {

        // ---- EXACT TP LOOP (UNCHANGED) ----
        $i = 1;
        // i=1..20  → factors: 0.5, 1.0, 1.5, ..., 10.0
        while ($i <= 20) {
            $f = ($i * 0.5);   // 0.5, 1, 1.5, 2, ...

            $name = "TP " + $f + "R Partial " + $mySym;

            $al = GetAlertObj($name);
            if (IsObj($al)) {
                $al.Delete();
            }

            $i = $i + 1;
        }
    }
}