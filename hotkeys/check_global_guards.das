// =====================
// CHECK GLOBAL GUARDS
// Group: Global controls & config
// =====================
// Sets $trade_ok based on global guard rails.

$trade_ok = 1;

// ---- Daily loss lock guard ----
$accName = $DAY_ACC;
if ($accName == "") {
    MsgBox("No session account set. Use Switch to SIM/LIVE first.");
    $trade_ok = 0;
    return;
}
$lockKey = "TRADING_LOCKED_" + $accName;
$locked  = GetVar($lockKey) * 1;

if ($locked == 1) {
    MsgBox("Trading locked for " + $accName + " (daily loss limit hit).");
    $trade_ok = 0;
    return;
}

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
if ($singlePositionGuard == 1) {
    if (IsObj($M)) {
        $curSym = $M.Symb;
        $curPos = $M.Pos;

        if ($singlePositionSymbol != "" && $curSym == $singlePositionSymbol && $curPos <= 0) {
            $singlePositionSymbol = "";
        }

        if ($entryPending == 1 && $entrySymbol != "" && $curSym != $entrySymbol) {
            MsgBox("Single-position mode: pending entry in " + $entrySymbol + ". New entries blocked.");
            $trade_ok = 0;
            return;
        }

        if ($singlePositionSymbol != "" && $curSym != $singlePositionSymbol) {
            MsgBox("Single-position mode: active symbol " + $singlePositionSymbol + ". New entries blocked.");
            $trade_ok = 0;
            return;
        }
    }
}
