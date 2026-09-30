// =====================
// SET AUTO STOP (1R, LONG ONLY)
// Group: Stops
// =====================
// Reusable stop-loss engine using montage context and the fixed R distance.
// Uses:
// - $stopLossTrigger (fixed 1R in dollars)
// - $entryRefPx as fallback if AvgCost lags
// - Caller should ensure $useAutoStop is enabled
// - Primary_OE montage (no global Symbol/Account)
// ---- Timer context ----
$timerActive = 0;
if ($timerMode == 1) { $timerActive = 1; $timerMode = 0; }

// ---- Step 1: Load Primary_OE montage ----

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Set Auto Stop: montage 'Primary_OE' not found. Aborting.");
    return;
}

// ---- Step 2: Read position state ----
$myAcc  = $M.Account;
$mySym  = $M.Symb;
$posNow = $M.Pos;
$avgNow = $M.AvgCost;

// Log manual reset context
MsgLog("Set Auto Stop: sym=" + $mySym + " pos=" + $posNow + " avg=" + $avgNow);

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

// Fallback: if AvgCost is still missing, anchor to entryRefPx or Last
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

// ---- Step 3: Cancel existing SELL orders ----
$skipCancel = 0;
if ($timerActive == 1) { $skipCancel = 1; }

if ($skipCancel == 0) {
    $accObj = GetAccountObj($myAcc);
    $accObj.CancelOrder("SELL", $mySym, 0);

    // Let cancels register; avoid races
    Wait(350);
}

// ---- Step 4: Compute raw 1R stop ----
$stop = $avgNow - $stopLossTrigger;

// ---- Step 5: Resolve tick-size bands ----
$inc = 0.01;
if ($avgNow < 1 || $stop < 1)        { $inc = 0.001; }
if ($avgNow < 0.25 || $stop < 0.25)  { $inc = 0.0005; }

$stop = Round($stop, 102, $inc);

// Track the last stop used (for backstop triggers)
$lastStop = $stop;
$lastStopSymbol = $mySym;

// ---- Step 6: Compute and snap the stop-limit price ----
$px = $stop - $exitOffset;
$px = Round($px, 102, $inc);

// Safety: ensure SLP limit is strictly below trigger (for sells)
if ($px >= $stop) {
    $px = Round($stop - $inc, 102, $inc);
}

// ---- Step 7: Build and send unified SLP stop ----
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

// --- End Set Auto Stop ---
