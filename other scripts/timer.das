// =====================
// TIMER: DAILY LOSS GUARD + TP CLEANUP
// Ignore: True
// =====================
// Timer handler: enforces daily loss lock and clears TP alerts when flat.

// ---- Step 1: Load account and equity baseline ----
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

    // ---- Step 2: Enforce daily loss lock ----
    // Use the global max daily loss value
    $limit = $maxDailyLoss;
    if ($limit <= 0) { return; }

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

}

// ---- Step 3: Clear TP alerts when flat ----

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

        // ---- TP alert cleanup loop ----
        $i = 1;
        // i=1..20  -> factors: 0.5, 1.0, 1.5, ..., 10.0
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
