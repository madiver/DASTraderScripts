// =====================
// TIMER: DAILY LOSS GUARD + TP CLEANUP
// Ignore: True
// =====================
// Timer handler: enforces daily loss lock and clears TP alerts when flat.

// ---- Step 0: Hijack protection (position-size backstop) ----
// Keep the timer script small; run hijack logic in a hotkey.
ExecHotkey("Hijack Exit");

// ---- Step 1: Load account and equity baseline ----
$accName = $DAY_ACC;
$DAY_GUARD_OK = 0;
if ($accName == "" ) {
    return;
}

$liveGuardActive = 0;
if ($accName == $LIVEACT || ($accName == $TRSIM && $applyLiveGuardsToSim == 1)) {
    $liveGuardActive = 1;
}

if ($liveGuardActive == 1) {

    $eqStartStr = GetVar("DAY_EQUITY_START");
    if ($eqStartStr == "") {
        return;
    }

    $eqStart = $eqStartStr * 1;
    if ($eqStart <= 0) {
        return;
    }

    // Only evaluate daily loss when flat (Primary_OE) with a 2-tick settle delay.
    $flatReady = 0;
    $M = GetWindowObj("Primary_OE");
    if (IsObj($M)) {
        $posNow = $M.Pos;
        if ($posNow <= 0) {
            if ($dayLossFlatTicks < 2) { $dayLossFlatTicks = $dayLossFlatTicks + 1; }
        } else {
            $dayLossFlatTicks = 0;
        }

        if ($dayLossFlatTicks >= 2) { $flatReady = 1; }
    } else {
        $dayLossFlatTicks = 0;
    }

    if ($flatReady == 1) {

        // Read current equity for this account
        $acc   = GetAccountObj($accName);
        $eqNow = $acc.Equity;
        if ($eqNow <= 0) {
            return;
        }

        // Compute drawdown
        $dd = $eqStart - $eqNow;

        // ---- Step 2: Enforce daily loss lock ----
        // Use the global max daily loss value
        $limit = $maxDailyLoss;
        if ($limit <= 0) {
            return;
        }

        $DAY_GUARD_OK = 1;

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
        // If back under limit and locked, auto-unlock
        if ($dd < $limit && $locked == 1) {

            // Clear per-account lock
            SetVar($lockKey, 0);

            // Also clear current lock mirror
            SetVar("TRADING_LOCKED", 0);

        }
    }

} 

// ---- Single-position guard tracking (script-tracked) ----
$M = GetWindowObj("Primary_OE");
if (IsObj($M)) {
    $symNow = StrTrim("" + $M.Symb);
    $posNow = $M.Pos;
    $trackedSym = StrTrim("" + $singlePositionSymbol);
    if ($trackedSym == "" && $posNow > 0) {
        $singlePositionSymbol = $symNow;
    } else {
        if ($trackedSym != "" && $symNow == $trackedSym && $posNow <= 0) {
            $singlePositionSymbol = "";
        }
    }
}

// ---- Step 3: Timer-based stop/TP arming ----
ExecHotkey("Timer Entry Handler");

// ---- Step 4: Clear TP alerts when flat ----

$oneSecondScriptCnt = $oneSecondScriptCnt + 1;
if ($oneSecondScriptCnt >= 5) {

    $oneSecondScriptCnt= 0;

    // Make sure we can access Primary_OE
    $M = GetWindowObj("Primary_OE");
    if (!IsObj($M)) {
        return;
    }

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

        // ---- Clear dynamic stop state when flat ----
        if ($dynamicStopActive == 1) {
            $dynamicStopActive = 0;
            $dynamicStopR = 0;
        }

        // ---- Clear structured stop state when flat ----
        if ($structuredStop != 0 || $structuredR != 0 || $structuredType != "" || $structuredSymbol != "") {
            $structuredOk = 0;
            $structuredReason = 0;
            $structuredType = "";
            $structuredStop = 0;
            $structuredR = 0;
            $structuredSymbol = "";
        }

        // ---- Clear entry reference when flat ----
        $entryRefPx = 0;
    }
}
