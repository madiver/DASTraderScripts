// =====================
// BACKSTOP EXIT EXECUTOR (LIMIT-ONLY, BID-BASED)
// Group: Stops
// =====================
// Executes an aggressive limit sell at Bid - $backstopBidOffset using $gtfoRoute.
// Re-arms the backstop alert if still not flat and retries remain.

// ---- Step 1: Focus Primary_OE and load montage ----
FocusWindow Primary_OE;
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgLog("Backstop Exit: montage 'Primary_OE' not found.");
    return;
}

$mySym = StrTrim("" + $M.Symb);
$myAcc = $M.Account;

// Optional symbol override from alert
$bsSym = GetVar("BACKSTOP_SYMBOL");
if ($bsSym == "") { $bsSym = $backstopSymbol; }
if ($bsSym == "") { $bsSym = $mySym; }

if ($bsSym != "" && $bsSym != $mySym) {
    $M.Symb = $bsSym;
    Wait(100);
    $mySym = StrTrim("" + $M.Symb);
    $myAcc = $M.Account;

    if ($mySym != $bsSym) {
        MsgLog("Backstop Exit: failed to switch montage to " + $bsSym +
               " (current=" + $mySym + ").");
        return;
    }
}

$posNow = $M.Pos;
if ($posNow <= 0) {
    // Flat -> clean up backstop state
    $alertName = "Backstop " + $mySym;
    $al = GetAlertObj($alertName);
    if (IsObj($al)) { $al.Delete(); }
    $backstopArmed = 0;
    $backstopRetries = 0;
    $backstopStop = 0;
    $backstopSymbol = "";
    $lastStop = 0;
    $lastStopSymbol = "";
    SetVar("BACKSTOP_SYMBOL", "");
    return;
}

// ---- Step 2: Resolve retries ----
$tries = $backstopRetries;
if ($tries <= 0) { $tries = $backstopMaxRetries; }
$backstopRetries = $tries - 1;
if ($backstopRetries < 0) { $backstopRetries = 0; }

// ---- Step 3: Cancel existing sells for this symbol ----
$accObj = GetAccountObj($myAcc);
$accObj.CancelOrder("SELL", $mySym, 0);
Wait(200);

// ---- Step 4: Compute aggressive limit price ----
$refPx = $M.Bid;
if ($refPx <= 0) { $refPx = $M.Last; }
if ($refPx <= 0) { return; }

$inc = 0.01;
if ($refPx < 1)    { $inc = 0.001; }
if ($refPx < 0.25) { $inc = 0.0005; }

$px = $refPx - $backstopBidOffset;
if ($px < $inc) { $px = $inc; }
$px = Round($px, 102, $inc);

$qty = Round($posNow, 0);
if ($qty <= 0) { return; }

// ---- Step 5: Send limit sell ----
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

// ---- Step 6: Re-arm if still long and retries remain ----
Wait(300);
$posNow = $M.Pos;
if ($posNow <= 0) {
    $alertName = "Backstop " + $mySym;
    $al = GetAlertObj($alertName);
    if (IsObj($al)) { $al.Delete(); }
    $backstopArmed = 0;
    $backstopRetries = 0;
    $backstopStop = 0;
    $backstopSymbol = "";
    $lastStop = 0;
    $lastStopSymbol = "";
    SetVar("BACKSTOP_SYMBOL", "");
    return;
}

if ($backstopRetries > 0) {
    $stop = $backstopStop;
    if ($stop <= 0) {
        $lastSym = StrTrim("" + $lastStopSymbol);
        if ($lastStop > 0 && $lastSym == $mySym) { $stop = $lastStop; }
    }

    if ($stop > 0) {
        $triggerPx = $stop - $backstopBuffer;
        $triggerPx = Round($triggerPx, 102, $inc);
        if ($triggerPx >= $stop) {
            $triggerPx = Round($stop - $inc, 102, $inc);
        }
        if ($triggerPx < $inc) { $triggerPx = $inc; }

        $alertName = "Backstop " + $mySym;
        $toDel = GetAlertObj($alertName);
        if (IsObj($toDel)) { $toDel.Delete(); }

        $al = NewAlertObj();
        $al.Name = $alertName;
        $al.Symb = $mySym;
        $al.AddItem("L1 Bid", "<", $triggerPx);
        $al.Script =
            "SetVar(\"BACKSTOP_SYMBOL\",\"" + $mySym + "\");" +
            "FocusWindow Primary_OE;" +
            "ExecHotkey(\"Backstop Exit Executor\");";
        $al.Speak       = 0;
        $al.PlaySound   = 0;
        $al.AutoDelete  = 1;
        $al.Loop        = 0;
        $al.PopupWindow = 0;
        $al.Save();

        $backstopArmed = 1;
        $backstopSymbol = $mySym;
        $backstopStop = $stop;
    }
} else {
    $backstopArmed = 0;
    MsgLog("Backstop Exit: retries exhausted for " + $mySym + " (pos=" + $posNow + ").");
}

SetVar("BACKSTOP_SYMBOL", "");
