// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// =====================
// HIJACK EXIT (TIMER)
// Group: Global controls & config
// =====================
// Enforces hijack protection and attempts to flatten when oversized.

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    ExecHotkey("End Trade Action");
    return;
}

$acctNow = StrTrim("" + $M.Account);
if ($acctNow == "") {
    ExecHotkey("End Trade Action");
    return;
}

$isSim = 0;
if (StrFind($acctNow, "TR") == 0) { $isSim = 1; }

$hijackActive = 0;
if ($isSim == 0 || $applyLiveGuardsToSim == 1) { $hijackActive = 1; }

if ($hijackActive != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($hijackProtection != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($maxPositionSize <= 0) {
    ExecHotkey("End Trade Action");
    return;
}

$displayPos = $M.Pos;
$needExit = 0;

// Montage .Pos is an absolute quantity, so it detects oversized longs and shorts.
// $M.GetCurrPos() is resolved below only when an exit is needed.
if ($HIJACKED_LOCKED == 1 && $displayPos > 0) {
    $needExit = 1;
} else {
    if ($displayPos > $maxPositionSize) {
        $HIJACKED_LOCKED = 1;
        $needExit = 1;
        LockAllMontage Lock;
        Speak("Hijack protection triggered.");
    }
}

if ($needExit != 1 || $displayPos <= 0) {
    ExecHotkey("End Trade Action");
    return;
}

$hijackState = $tradeStates.Get($acctNow + "|" + $M.Symb);
if (IsObj($hijackState)) {
    if ($hijackState.Get("exitCoordinatorVersion") == 1) {
        if ($hijackState.closeManaged == 1 && $hijackState.closePriority >= 40) {
            ExecHotkey("End Trade Action"); return;
        }
    }
}
SetVar("EXIT_REQUEST_ACCOUNT", $acctNow);
SetVar("EXIT_REQUEST_SYMBOL", $M.Symb);
SetVar("EXIT_REQUEST_KIND", "HIJACK");
SetVar("EXIT_REQUEST_DIRECTION", 0);
SetVar("EXIT_REQUEST_FRACTION", 1);
SetVar("EXIT_REQUEST_PRIORITY", 40);
ExecHotkey("Request Exit");
ExecHotkey("End Trade Action");
