// =====================
//  SET AUTO STOP (1R, LONG ONLY)
// Group: Stops
// =====================
//
// Reusable stop-loss engine
// - Uses STOPLOSS_TRIGGER global (1R in dollars)
// - Uses ENTRY_REF_PX (optional) as fallback if AvgCost is lagging
// - Honors USE_AUTO_STOP global
// - Uses Primary_OE montage object (no global Symbol/Account dependency)
// - Places a unified SLP stop for current symbol/account
//

FocusWindow Primary_OE;

// 1) Get Primary_OE montage object
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Set Auto Stop: montage 'Primary_OE' not found. Aborting.");
    return;
}

// Pull context from montage object
$myAcc  = $M.Account;
$mySym  = $M.Symb;
$posNow = $M.Pos;
$avgNow = $M.AvgCost;

// LONG-ONLY: if no long position, nothing to protect
if ($posNow <= 0) {
    return;
}

// Try to let AvgCost populate if it's lagging
$j = 0;
while ($posNow > 0 && $avgNow <= 0 && $j < 10) {
    Wait(50);
    $avgNow = $M.AvgCost;
    $j = $j + 1;
}

// Seatbelt: if still no AvgCost but we do have size, anchor to entry ref if available
if ($posNow > 0 && $avgNow <= 0) {
    if ($entryRefPx > 0) {
        $avgNow = $entryRefPx;
    } else {
        $avgNow = $M.Last;   // last fallback from montage
    }
}

if ($posNow <= 0 || $avgNow <= 0) {
    // something is very off; abort rather than arm bad stop
    return;
}

// 2) Tunables specific to STOP behavior
// TODO
$useAdaptiveLimitOff  = 1;     // 1=offset based on spread; 0=use fixed $limitOff
$adapt_k              = 2.0;   // limit offset = max(minTicks*inc, min(maxLimitOff, k*spread))
$adapt_minTicks       = 2;     // min ticks for stop-limit offset
$adapt_maxLimitOff    = 0.25;  // hard cap in dollars on limit offset
$verifyStopPosted     = 1;     // 1=read back stop and verify; retry once; then fallback to SL

// 3) Cancel existing SELL-side working orders
$accObj = GetAccountObj($myAcc);
$accObj.CancelOrder("SELL", $mySym, 0);

// Let cancels register; avoid races
Wait(350);

// 4) Compute raw 1R stop
$stop = $avgNow - $stopLossTrigger;

// 5) Resolve tick-size bands for stop/limit and snapping
$inc = 0.01;
if ($avgNow < 1 || $stop < 1)        { $inc = 0.001; }
if ($avgNow < 0.25 || $stop < 0.25)  { $inc = 0.0005; }

$stop = Round($stop, 102, $inc);

// 6) Adaptive stop-limit offset
$effLimitOff = $exitOffset;
if ($useAdaptiveLimitOff == 1) {
    // Use montage-level quotes, not globals
    $spreadNow   = $M.Ask - $M.Bid;
    $effLimitOff = ($adapt_k * $spreadNow);
    // floor to min ticks
    $minOff = ($adapt_minTicks * $inc);
    if ($effLimitOff < $minOff)            { $effLimitOff = $minOff; }
    // cap
    if ($effLimitOff > $adapt_maxLimitOff) { $effLimitOff = $adapt_maxLimitOff; }
}

// Compute and snap limit
$px = $stop - $effLimitOff;
$px = Round($px, 102, $inc);

// Safety: ensure SLP limit is strictly below trigger (for sells)
if ($px >= $stop) {
    $px = Round($stop - $inc, 102, $inc);
}

// 7) Build & send unified SLP stop
$qtyProtect = Round($posNow, 0);
if ($qtyProtect <= 0) {
    return;
}

$s = NewOrderObj();
$s.Account    = $myAcc;
$s.Symbol     = $mySym;
$s.Route       = "STOP";
$s.Tif            = "DAY+";
$s.Side         = "S";
$s.Type         = "SLP";        // Stop-Limit (P)
$s.StopPrice = $stop;
$s.Price        = $px;
$s.Share       = $qtyProtect;  // protect entire current position
$s.Send();

// small settle to register
Wait(200);

// 8) Verify stop posted (optional)
if ($verifyStopPosted == 1) {
    $s.GetInfo();   // refresh object if supported
    $ok = 1;

    if ($s.StopPrice != $stop)      { $ok = 0; }
    if ($s.Price     != $px)        { $ok = 0; }
    if ($s.Share     != $qtyProtect){ $ok = 0; }

    if ($ok == 0) {
        // retry once after a brief backoff
        Wait(300);
        $s.Send();
        Wait(200);
        $s.GetInfo();

        $ok = 1;
        if ($s.StopPrice != $stop)      { $ok = 0; }
        if ($s.Price     != $px)        { $ok = 0; }
        if ($s.Share     != $qtyProtect){ $ok = 0; }

        // If still not OK, fallback to plain SL
        if ($ok == 0) {
            $s.Type = "SL";
            $s.Send();
            MsgBox("Set Auto Stop: verification failed for " + $mySym + ". Fallback SL sent.");
        }
    }
}

// --- End Set Auto Stop ---