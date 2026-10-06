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

// Use an aggressive limit for pre-market compatibility. Native Reverse closes
// the current position without adding past flat in either direction.
FocusWindow Primary_OE;

$myAcc = StrTrim("" + $M.Account);
$mySym = StrTrim("" + $M.Symb);
if ($myAcc == "" || $mySym == "") {
    MsgLog("Hijack Exit: account or symbol unavailable. Aborting.");
    ExecHotkey("End Trade Action");
    return;
}

$route = $gtfoRoute;
if ($route == "") { $route = $orderRoute; }
if ($route == "") {
    MsgLog("Hijack Exit: no route configured for " + $mySym + ". Aborting.");
    ExecHotkey("End Trade Action");
    return;
}

$scopedAccountObj = GetAccountObj($myAcc);
if (!IsObj($scopedAccountObj)) {
    ExecHotkey("End Trade Action");
    return;
}
$scopedAccountObj.CancelOrder("BUY|SELL", $mySym, 0);
SetVar("TRADE_CONTEXT_ACCOUNT", $myAcc);
SetVar("TRADE_CONTEXT_SYMBOL", $mySym);
ExecHotkey("Load Trade Context");
if ($tradeContextValid == 1) { ExecHotkey("Invalidate Trade Alerts"); }
Wait(100);

// Cancelling a working order can briefly make GetCurrPos() return zero. Poll
// while the montage still reports a non-flat position so direction is known.
// Bind the function to Primary_OE explicitly when invoked by the timer.
$posNow = $M.GetCurrPos();
$i = 0;
while ($posNow == 0 && $M.Pos != 0 && $i < 10) {
    Wait(50);
    $posNow = $M.GetCurrPos();
    $i = $i + 1;
}
if ($posNow == 0) {
    if ($M.Pos != 0) {
        MsgLog("Hijack Exit: unable to resolve signed position for " + $mySym + ". Aborting.");
    }
    ExecHotkey("End Trade Action");
    return;
}

// Abort if the montage changed while pending orders were cancelled.
$acctCheck = StrTrim("" + $M.Account);
$symCheck = StrTrim("" + $M.Symb);
if ($acctCheck != $myAcc || $symCheck != $mySym) {
    MsgLog("Hijack Exit: montage account or symbol changed. Aborting.");
    ExecHotkey("End Trade Action");
    return;
}

$direction = "LONG";
$refPx = $M.Bid;
if ($posNow < 0) {
    $direction = "SHORT";
    $refPx = $M.Ask;
}
if ($refPx <= 0) { $refPx = $M.Last; }
if ($refPx <= 0) {
    MsgLog("Hijack Exit: no valid quote for " + $mySym + ". Aborting.");
    ExecHotkey("End Trade Action");
    return;
}

$px = $refPx - $exitOffset;
if ($posNow < 0) { $px = $refPx + $exitOffset; }
if ($px <= 0) {
    MsgLog("Hijack Exit: calculated price is invalid for " + $mySym + ". Aborting.");
    ExecHotkey("End Trade Action");
    return;
}

// Do not send if the position flattened or changed sides during preparation.
$posCheck = $M.GetCurrPos();
if ($posCheck == 0 || ($posNow > 0 && $posCheck < 0) || ($posNow < 0 && $posCheck > 0)) {
    MsgLog("Hijack Exit: position changed while preparing exit for " + $mySym + ". Aborting.");
    ExecHotkey("End Trade Action");
    return;
}

ROUTE=$route;
TIF=DAY+;
Price=$px;
// Use DAS's montage-native price rounding for the active tick increment.
if ($px >= 1) { Price=Round2; }
if ($px < 1)  { Price=Round3; }
if ($px < 0.25) { Price=Round4; }
Share=Pos;
SEND=Reverse;
MsgLog("Hijack Exit: submitted " + $direction + " full-position Reverse for " + $mySym + " at " + $px + " via " + $route + ".");

ExecHotkey("End Trade Action");
