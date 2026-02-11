// =====================
// TIMER: HIJACK + ENTRY + TP CLEANUP
// Ignore: True
// =====================
// Timer handler: runs hijack backstop, entry staging, and TP cleanup.

// ---- Step 0: Hijack protection (position-size backstop) ----
// Keep the timer script small; run hijack logic in a hotkey.
ExecHotkey("Hijack Exit");

// ---- Step 1: Single-position guard tracking (script-tracked) ----
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

// ---- Step 2: Timer-based stop/TP arming ----
ExecHotkey("Timer Entry Handler");

// ---- Step 3: Clear TP alerts when flat ----

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
        // Avoid clearing during pending entry staging to prevent races with structured fills.
        if ($entryPending != 1 && $entryStage == 0 && StrTrim("" + $entrySymbol) == "") {
            if ($structuredStop != 0 || $structuredR != 0 || $structuredType != "" || $structuredSymbol != "") {
                $structuredOk = 0;
                $structuredReason = 0;
                $structuredType = "";
                $structuredStop = 0;
                $structuredR = 0;
                $structuredSymbol = "";
            }
        }

        // ---- Clear entry reference when flat ----
        $entryRefPx = 0;
    }
}
