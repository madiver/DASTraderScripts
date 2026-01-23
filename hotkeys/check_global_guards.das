// =====================
// CHECK GLOBAL GUARDS
// Group: Global controls & config
// =====================
// Sets $trade_ok based on global guard rails.

$trade_ok = 1;

// ---- Montage context for remaining guards ----
$acct = "";
$M = GetWindowObj("Primary_OE");
if (IsObj($M)) {
    $acct = StrTrim("" + $M.Account);
}

// ---- Hijack protection guard ----
$isLive = 0;
if (StrLen($acct) > 0 && StrFind($acct, "TR") != 0) { $isLive = 1; }
if ($HIJACKED_LOCKED == 1 && ($isLive == 1 || $applyLiveGuardsToSim == 1)) {
    MsgBox("Trading locked for " + $acct + " (hijack protection triggered).");
    $trade_ok = 0;
    return;
}

// ---- Single-position guard (script-tracked) ----
if (IsObj($M)) {
    $curSym = StrTrim("" + $M.Symb);
    $curPos = $M.Pos;

    $trackedSym = StrTrim("" + $singlePositionSymbol);
    if ($trackedSym != "" && $curSym == $trackedSym && $curPos <= 0) {
        $singlePositionSymbol = "";
    }

    // Always block cross-symbol entries while a buy is pending.
    $pendingSym = StrTrim("" + $entrySymbol);
    if ($entryPending == 1 && $pendingSym != "" && $curSym != $pendingSym) {
        MsgBox("Single-position mode: pending entry in " + $entrySymbol + ". New entries blocked.");
        $trade_ok = 0;
        return;
    }

    // Optional: block new entries on a different symbol while a position is tracked.
    if ($singlePositionGuard == 1 && $trackedSym != "" && $curSym != $trackedSym) {
        MsgBox("Single-position mode: active symbol " + $singlePositionSymbol + ". New entries blocked.");
        $trade_ok = 0;
        return;
    }
}
