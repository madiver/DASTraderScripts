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

$posNow = $M.Pos;
$needExit = 0;

if ($HIJACKED_LOCKED == 1 && $posNow > 0) {
    $needExit = 1;
} else {
    if ($posNow > $maxPositionSize) {
        $HIJACKED_LOCKED = 1;
        $needExit = 1;
        LockAllMontage Lock;
        Speak("Hijack protection triggered.");
    }
}

if ($needExit == 1 && $posNow > 0) {
    // Use an aggressive limit for pre-market compatibility.
    FocusWindow Primary_OE;
    CXL ALLSYMB;

    $myAcc = $M.Account;
    $mySym = $M.Symb;

    $refPx = $M.Bid;
    if ($refPx <= 0) { $refPx = $M.Last; }
    if ($refPx <= 0) { $refPx = $M.Ask; }

    if ($refPx <= 0) { return; }

    $inc = 0.01;
    if ($refPx < 1)    { $inc = 0.001; }
    if ($refPx < 0.25) { $inc = 0.0005; }

    $px = $refPx - $exitOffset;
    if ($px < $inc) { $px = $inc; }
    $px = Round($px, 102, $inc);

    $qty = Round($posNow, 0);
    if ($qty <= 0) { return; }

    $route = $gtfoRoute;
    if ($route == "") { $route = $orderRoute; }

    $o = NewOrderObj();
    $o.Account = $myAcc;
    $o.Symbol  = $mySym;
    $o.Route   = $route;
    $o.Tif     = "DAY+";
    $o.Side    = "S";
    $o.Type    = "L";
    $o.Price   = $px;
    $o.Share   = $qty;
    $o.Send();
}
