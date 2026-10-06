// Group: Global controls & config
// Long-entry guards are account scoped. Manual shorts do not occupy the long guard.
$trade_ok = 0;
ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1 || $tradePositionValid != 1) { return; }
if ($posNow < 0) {
    MsgBox("Long entry blocked: " + $myAcc + " " + $mySym + " is short. Use Cover instead.");
    return;
}
$acct = $myAcc;
$isLive = 0;
if (StrLen($acct) > 0 && StrFind($acct, "TR") != 0) { $isLive = 1; }
if ($HIJACKED_LOCKED == 1 && ($isLive == 1 || $applyLiveGuardsToSim == 1)) {
    MsgBox("Trading locked for " + $acct + " (hijack protection triggered).");
    return;
}
if ($trade.entryPending == 1) {
    MsgBox("Entry already pending for " + $myAcc + " " + $mySym + ".");
    return;
}
$guardIndex = 0;
while ($guardIndex < $tradeSlotCount) {
    $guardOther = $tradeSlots.Get($guardIndex);
    if (IsObj($guardOther)) {
        if ($guardOther.account == $myAcc && $guardOther.symbol != $mySym) {
            if ($guardOther.entryPending == 1) {
                MsgBox("Pending long entry in " + $guardOther.symbol + ". New entries blocked for " + $myAcc + ".");
                return;
            }
            if ($singlePositionGuard == 1 && $guardOther.active == 1) {
                $guardPos = GetAccountObj($myAcc).GetPosition($guardOther.symbol);
                // Unknown position data cannot safely release the guard.
                $guardBlock = 1;
                if (IsObj($guardPos)) {
                    if ($guardPos.Share <= 0) { $guardBlock = 0; }
                }
                if ($guardBlock == 1) {
                    MsgBox("Single-long mode: active symbol " + $guardOther.symbol + " in " + $myAcc + ".");
                    return;
                }
            }
        }
    }
    $guardIndex = $guardIndex + 1;
}
$trade_ok = 1;
