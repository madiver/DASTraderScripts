// =====================
// TIMER ENTRY HANDLER
// Group: Utilities & toggles
// =====================
// Timer-safe stop/TP staging for entry hotkeys (no waits).

if ($useTimerArming != 1) {
    return;
}

// Skip timer handling while the pending-entry test is active in test mode.
if ($testMode == 1 && GetVar("TEST_PENDING_ENTRY_ACTIVE") * 1 == 1) {
    return;
}

// Make sure we can access Primary_OE
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    return;
}

// Snapshot symbol and position
$mySym  = StrTrim("" + $M.Symb);
$posNow = $M.Pos;
$mode = $stopMode;
if ($mode == "") {
    if ($dynamicStop == 1) { $mode = "DYNAMIC"; } else { $mode = "STANDARD"; }
}

// If no pending entry, optionally re-arm when size increases
if ($entryPending != 1) {
    if ($entryWatch == 1) {
        $entrySym = StrTrim("" + $entrySymbol);
        if ($entrySym != "" && $mySym != $entrySym) {
            $entryWatch = 0;
            $entryLastPos = 0;
            $entryScaleIn = 0;
            $entrySymbol = "";
            return;
        }
        if ($posNow <= 0) {
            $entryWatch = 0;
            $entryLastPos = 0;
            $entryScaleIn = 0;
            $entrySymbol = "";
            if ($mode == "STRUCTURED") {
                $structuredOk = 0;
                $structuredReason = 0;
                $structuredType = "";
                $structuredStop = 0;
                $structuredR = 0;
                $structuredSymbol = "";
            }
            return;
        }

        if ($entryLastPos <= 0) {
            $entryLastPos = $posNow;
            return;
        }

        if ($posNow > $entryLastPos) {
            if ($useAutoStop == "Yes") {
                $accObj = GetAccountObj($M.Account);
                $accObj.CancelOrder("SELL", $mySym, 0);
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
        }

        $entryLastPos = $posNow;
    }
    return;
}

// Reset watch when handling a new pending entry
if ($entryWatch == 1) {
    $entryWatch = 0;
    $entryLastPos = 0;
}

// Safety: bail if montage symbol doesn't match the entry
$entrySym = StrTrim("" + $entrySymbol);
if ($entrySym != "" && $mySym != $entrySym) {
    $wasScaleIn = $entryScaleIn;
    $accObj = GetAccountObj($M.Account);
    $accObj.CancelOrder("BUY", $entrySymbol, 0);
    $entryPending = 0;
    $entryStage = 0;
    $entryTicks = 0;
    $entryDynR = 0;
    $entryScaleIn = 0;
    $entryWatch = 0;
    $entryLastPos = 0;
    $entryRefPx = 0;
    if ($wasScaleIn != 1 && $mode == "STRUCTURED") {
        $structuredOk = 0;
        $structuredReason = 0;
        $structuredType = "";
        $structuredStop = 0;
        $structuredR = 0;
        $structuredSymbol = "";
    }
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
        $entryWatch = 0;
        $entryLastPos = 0;
        return;
    }
} else {
    if ($posNow <= 0 && $entryStage > 0) {
        $entryPending = 0;
        $entryStage = 0;
        $entryTicks = 0;
        $entryDynR = 0;
        $entryScaleIn = 0;
        $entryWatch = 0;
        $entryLastPos = 0;
        if ($mode == "STRUCTURED") {
            $structuredOk = 0;
            $structuredReason = 0;
            $structuredType = "";
            $structuredStop = 0;
            $structuredR = 0;
            $structuredSymbol = "";
        }
        return;
    }
}

// Stage 0: wait for fill
if ($entryStage == 0) {
    $entryTicks = $entryTicks + 1;

    if ($entryScaleIn == 1) {
        if ($posNow > $entryPosBefore) {
            if (StrTrim("" + $singlePositionSymbol) == "") { $singlePositionSymbol = $mySym; }
            $entryStage = 1; // cancel stage
            $entryTicks = 0;
        } else {
            if ($entryMaxTicks > 0 && $entryTicks >= $entryMaxTicks) {
                $accObj = GetAccountObj($M.Account);
                $accObj.CancelOrder("BUY", $mySym, 0);
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
            if (StrTrim("" + $singlePositionSymbol) == "") { $singlePositionSymbol = $mySym; }
            $mode = $stopMode;
            if ($mode == "") {
                if ($dynamicStop == 1) { $mode = "DYNAMIC"; } else { $mode = "STANDARD"; }
            }
            if ($entryDynR > 0 && $mode == "DYNAMIC") {
                $dynamicStopR = $entryDynR;
                $dynamicStopActive = 1;
            }
            if ($mode == "STRUCTURED" && $structuredStop > 0) {
                $avgNow = $M.AvgCost;
                if ($avgNow > 0) {
                    $structuredR = $avgNow - $structuredStop;
                }
            }
            $entryStage = 2; // stop stage
            $entryTicks = 0;
        } else {
            if ($entryMaxTicks > 0 && $entryTicks >= $entryMaxTicks) {
                $accObj = GetAccountObj($M.Account);
                $accObj.CancelOrder("BUY", $mySym, 0);
                $entryPending = 0;
                $entryStage = 0;
                $entryTicks = 0;
                $entryDynR = 0;
                $entryScaleIn = 0;
                if ($mode == "STRUCTURED") {
                    $structuredOk = 0;
                    $structuredReason = 0;
                    $structuredType = "";
                    $structuredStop = 0;
                    $structuredR = 0;
                    $structuredSymbol = "";
                }
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
    $entryWatch = 1;
    $entryLastPos = $posNow;
    return;
}
