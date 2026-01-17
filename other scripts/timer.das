// =====================
// TIMER: DAILY LOSS GUARD + TP CLEANUP
// Ignore: True
// =====================
// Timer handler: enforces daily loss lock and clears TP alerts when flat.

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

    // ---- Step 2b: Hijack protection (position-size backstop) ----
    if ($hijackProtection == 1 && $maxPositionSize > 0 && $HIJACKED_LOCKED != 1) {
        $M = GetWindowObj("Primary_OE");
        if (IsObj($M)) {
            $posNow = $M.Pos;
            if ($posNow > $maxPositionSize) {
                $HIJACKED_LOCKED = 1;
                ExecHotkey("GTFO");
                LockAllMontage Lock;
                Speak("Hijack protection triggered.");
            }
        }
    }

} 

// ---- Single-position guard tracking (script-tracked) ----
$M = GetWindowObj("Primary_OE");
if (IsObj($M)) {
    $symNow = $M.Symb;
    $posNow = $M.Pos;
    if ($singlePositionSymbol == "" && $posNow > 0) {
        $singlePositionSymbol = $symNow;
    } else {
        if ($singlePositionSymbol != "" && $symNow == $singlePositionSymbol && $posNow <= 0) {
            $singlePositionSymbol = "";
        }
    }
}

// ---- Step 3: Timer-based stop/TP arming ----
ExecHotkey("Timer Entry Handler");

// ---- Step 4: Clear TP alerts when flat ----

$oneSecondScriptCnt = $oneSecondScriptCnt + 1;

if ($oneSecondScriptCnt % 5 ==0) {

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
    }
}
