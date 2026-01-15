// =====================
// TIMER ENTRY HANDLER
// Group: Utilities & toggles
// =====================
// Timer-safe stop/TP staging for entry hotkeys (no waits).

if ($useTimerArming != 1) {
    return;
}
if ($entryPending != 1) {
    return;
}

// Make sure we can access Primary_OE
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    return;
}

// Snapshot symbol and position
$mySym  = $M.Symb;
$posNow = $M.Pos;

// Safety: bail if montage symbol doesn't match the entry
if ($entrySymbol != "" && $mySym != $entrySymbol) {
    $entryPending = 0;
    $entryStage = 0;
    $entryTicks = 0;
    $entryDynR = 0;
    $entryScaleIn = 0;
    return;
}

// If we advanced stages but the position is gone, clear and exit
if ($entryScaleIn == 1) {
    if ($posNow <= $entryPosBefore && $entryStage > 0) {
        $entryPending = 0;
        $entryStage = 0;
        $entryTicks = 0;
        $entryDynR = 0;
        $entryScaleIn = 0;
        return;
    }
} else {
    if ($posNow <= 0 && $entryStage > 0) {
        $entryPending = 0;
        $entryStage = 0;
        $entryTicks = 0;
        $entryDynR = 0;
        $entryScaleIn = 0;
        return;
    }
}

// Stage 0: wait for fill
if ($entryStage == 0) {
    $entryTicks = $entryTicks + 1;

    if ($entryScaleIn == 1) {
        if ($posNow > $entryPosBefore) {
            $entryStage = 1; // cancel stage
            $entryTicks = 0;
        } else {
            if ($entryMaxTicks > 0 && $entryTicks >= $entryMaxTicks) {
                $entryPending = 0;
                $entryStage = 0;
                $entryTicks = 0;
                $entryDynR = 0;
                $entryScaleIn = 0;
            }
        }
        return;
    }

    if ($posNow > 0) {
        if ($entryDynR > 0 && $dynamicStop == 1) {
            $dynamicStopR = $entryDynR;
            $dynamicStopActive = 1;
        }
        $entryStage = 2; // stop stage
        $entryTicks = 0;
    } else {
        if ($entryMaxTicks > 0 && $entryTicks >= $entryMaxTicks) {
            $entryPending = 0;
            $entryStage = 0;
            $entryTicks = 0;
            $entryDynR = 0;
            $entryScaleIn = 0;
        }
    }
    return;
}

// Stage 1: cancel existing SELL orders for scale-ins
if ($entryStage == 1) {
    $accObj = GetAccountObj($M.Account);
    $accObj.CancelOrder("SELL", $mySym, 0);
    $entryStage = 2;
    $entryTicks = 0;
    return;
}

// Stage 2: send stop
if ($entryStage == 2) {
    if ($useAutoStop == "Yes") {
        $timerMode = 1;
        if ($entryScaleIn == 1) {
            ExecHotkey("Set Auto Stop BE Scale 1/1");
        } else {
            ExecHotkey("Set Auto Stop");
        }
        if ($timerMode == 1) {
            $timerMode = 0;
        }
    }
    $entryStage = 3;
    $entryTicks = 0;
    return;
}

// Stage 3: set TP alert if needed
if ($entryStage == 3) {
    if ($useTakeProfit == "Yes") {
        $doTp = 0;
        if ($entryPosBefore <= 0) {
            $doTp = 1;
        } else {
            $bidNow = $M.Bid;
            if ($entryAvgBefore <= 0) {
                $doTp = 1;
            } else {
                if ($bidNow <= $entryAvgBefore) {
                    $doTp = 1;
                }
            }
        }

        if ($doTp == 1) {
            $timerMode = 1;
            ExecHotkey("Set Take Profit");
            if ($timerMode == 1) {
                $timerMode = 0;
            }
        }
    }

    $entryPending = 0;
    $entryStage = 0;
    $entryTicks = 0;
    $entryDynR = 0;
    $entryScaleIn = 0;
    return;
}
