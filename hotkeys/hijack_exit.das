// =====================
// HIJACK EXIT (TIMER)
// Group: Global controls & config
// =====================
// Enforces hijack protection and attempts to flatten when oversized.

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) { return; }

$acctNow = StrTrim("" + $M.Account);
if ($acctNow == "") { return; }

$isSim = 0;
if (StrFind($acctNow, "TR") == 0) { $isSim = 1; }

$hijackActive = 0;
if ($isSim == 0 || $applyLiveGuardsToSim == 1) { $hijackActive = 1; }

if ($hijackActive != 1) { return; }
if ($hijackProtection != 1) { return; }
if ($maxPositionSize <= 0) { return; }

$displayPos = $M.Pos;
$needExit = 0;

// Montage .Pos is an absolute quantity, so it detects oversized longs and shorts.
// GetCurrPos() is resolved below only when an exit is needed.
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

if ($needExit != 1 || $displayPos <= 0) { return; }

// Use an aggressive limit for pre-market compatibility. Native Reverse closes
// the current position without adding past flat in either direction.
FocusWindow Primary_OE;

$myAcc = StrTrim("" + $M.Account);
$mySym = StrTrim("" + $M.Symb);
if ($myAcc == "" || $mySym == "") {
    MsgLog("Hijack Exit: account or symbol unavailable. Aborting.");
    return;
}

$route = $gtfoRoute;
if ($route == "") { $route = $orderRoute; }
if ($route == "") {
    MsgLog("Hijack Exit: no route configured for " + $mySym + ". Aborting.");
    return;
}

CXL ALLSYMB;
Wait(100);

// Cancelling a working order can briefly make GetCurrPos() return zero. Poll
// while the montage still reports a non-flat position so direction is known.
$posNow = GetCurrPos();
$i = 0;
while ($posNow == 0 && $M.Pos != 0 && $i < 10) {
    Wait(50);
    $posNow = GetCurrPos();
    $i = $i + 1;
}
if ($posNow == 0) {
    if ($M.Pos != 0) {
        MsgLog("Hijack Exit: unable to resolve signed position for " + $mySym + ". Aborting.");
    }
    return;
}

// Abort if the montage changed while pending orders were cancelled.
$acctCheck = StrTrim("" + $M.Account);
$symCheck = StrTrim("" + $M.Symb);
if ($acctCheck != $myAcc || $symCheck != $mySym) {
    MsgLog("Hijack Exit: montage account or symbol changed. Aborting.");
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
    return;
}

$px = $refPx - $exitOffset;
if ($posNow < 0) { $px = $refPx + $exitOffset; }
if ($px <= 0) {
    MsgLog("Hijack Exit: calculated price is invalid for " + $mySym + ". Aborting.");
    return;
}

// Do not send if the position flattened or changed sides during preparation.
$posCheck = GetCurrPos();
if ($posCheck == 0 || ($posNow > 0 && $posCheck < 0) || ($posNow < 0 && $posCheck > 0)) {
    MsgLog("Hijack Exit: position changed while preparing exit for " + $mySym + ". Aborting.");
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
