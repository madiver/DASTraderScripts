// =====================
// SET AUTO STOP BE (SLP ABOVE BE) - 1/2
// Group: Stops
// =====================
// Called from Take Profit Executor.
// Behavior:
// - Protects partial position (1/denominator)
// - If not yet +$0.03 in profit -> place BE limit sell
// - If >= +$0.03 in profit -> place SLP stop-limit above BE
//
// Requirements:
// - Primary_OE montage exists
// - Uses montage object properties (.Symb, .Account, .Pos, .AvgCost)
// - Honors $useAutoStop
//

// ---- Tunables ----
$portionDenominator = 2;    // 1 = full, 2 = half, 4 = quarter
$beOffset           = 0.03; // BE trigger offset
$cancelWaitMs       = 1000; // cancel throttle wait

// ---- Step 1: Feature toggle ----
if ($useAutoStop != "Yes") {
    return;
}

// ---- Step 2: Load Primary_OE montage ----
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Set Auto Stop BE: Primary_OE montage not found.");
    return;
}

// ---- Step 3: Resolve symbol and account ----
$mySym = $M.Symb;
$myAcc = $M.Account;

// Optional override from executor
if ($tpSymbol != "" && $tpSymbol != $mySym) {
    $M.Symb = $tpSymbol;
    Wait(300); // allow DAS to fully update

    $mySym = $M.Symb;
    $myAcc = $M.Account;

    if ($mySym != $tpSymbol) {
        MsgBox("Set Auto Stop BE: failed to switch montage to " + $tpSymbol);
        return;
    }
}

// Optional entry-symbol safety
if ($entrySymbol != "" && $entrySymbol != $mySym) {
    MsgBox("Set Auto Stop BE: symbol mismatch (" + $mySym + " vs " + $entrySymbol + ")");
    return;
}

// ---- Step 4: Read position state ----
$posNow = $M.Pos;
$avgNow = $M.AvgCost;

if ($posNow <= 0) {
    return; // flat or short
}
if ($avgNow <= 0) {
    MsgBox("Set Auto Stop BE: AvgCost unavailable for " + $mySym);
    return;
}

// ---- Step 5: Tick size logic (single source of truth) ----
$inc = 0.01;
if ($avgNow < 1)    { $inc = 0.001; }
if ($avgNow < 0.25) { $inc = 0.0005; }

$avgSnap = Round($avgNow, 102, $inc);

// ---- Step 6: Market state ----
$bid = $M.Bid;
if ($bid <= 0) {
    MsgBox("Set Auto Stop BE: No valid BID for " + $mySym);
    return;
}

$beStopTrigger = Round($avgSnap + $beOffset, 102, $inc);

// ---- Step 7: Quantity to protect (partial) ----
$qtyProtect = $posNow / $portionDenominator;
if ($qtyProtect <= 0) {
    return;
}

// ---- Step 8: Cancel existing SELL orders (account scoped) ----
$accObj = GetAccountObj($myAcc);
$accObj.CancelOrder("SELL", $mySym, 0);
Wait($cancelWaitMs);

// ---- Step 9: If not yet in profit, place BE limit sell ----
if ($bid < $beStopTrigger) {

    // ARCAL uses penny ticks
    $incBE = 0.01;

    $px = Round($avgSnap, 102, $incBE);

    if ($pegToBid == 1 && $bid > $px) {
        $px = Round($bid, 102, $incBE);
    }

    $o = NewOrderObj();
    $o.Account = $myAcc;
    $o.Symbol  = $mySym;
    $o.Route   = "ARCAL";
    $o.Tif     = "DAY+";
    $o.Side    = "S";
    $o.Type    = "L";
    $o.Price   = $px;
    $o.Share   = $qtyProtect;
    $o.Send();

    return;
}

// ---- Step 10: If in profit, place SLP stop above BE ----
$stop = Round($avgSnap + $beOffset, 102, $inc);
$px   = Round($avgSnap, 102, $inc);

// Ensure SLP validity (limit < stop)
if ($px >= $stop) {
    $px = Round($stop - $inc, 102, $inc);
}

$s = NewOrderObj();
$s.Account   = $myAcc;
$s.Symbol    = $mySym;
$s.Route     = "STOP";
$s.Tif       = "DAY+";
$s.Side      = "S";
$s.Type      = "SLP";
$s.StopPrice = $stop;
$s.Price     = $px;
$s.Share     = $qtyProtect;
$s.Send();

return;

// ---- End Set Auto Stop BE ----
