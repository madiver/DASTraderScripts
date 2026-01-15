// =====================
// PARTIAL TAKE-PROFIT EXECUTION (SIZE-AWARE, LONG ONLY)
// Group: Take profit
// =====================
// Uses $takeProfitSize to send a partial TP and re-arm stops/TP based on fill.

// ---- Step 1: Focus Primary_OE ----
FocusWindow Primary_OE;

// ---- Step 2: Load Primary_OE montage ----
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Take_Profit_Executor: montage 'Primary_OE' not found.");
    return;
}

// Optional: symbol override via TP_SYMBOL from alert
$mySym = $M.Symb;
$myAcc = $M.Account;

// If TP_SYMBOL is set and differs from current montage symbol, try to switch
if ($takeProfitSymbol != "" && $takeProfitSymbol != $mySym) {
    $M.Symb = $takeProfitSymbol;        // attempt to switch montage symbol
    Wait(100);                                      // allow DAS to update
    $mySym = $M.Symb;
    $myAcc = $M.Account;

    // Safety: if we still aren't on TP_SYMBOL, abort to avoid touching wrong symbol
    if ($mySym != $takeProfitSymbol) {
        MsgBox("TP Executor: failed to switch Primary_OE to " + $takeProfitSymbol +
               ". Currently on " + $mySym + ". Aborting.");
        return;
    }
}

// Load position from the (possibly updated) montage
$posNow = $M.Pos;

// Safety: make sure account is valid
if ($myAcc == "") {
    MsgBox("Take_Profit_Executor: Account is blank on Primary_OE. Aborting.");
    return;
}

// LONG-ONLY: No long position? Exit.
if ($posNow <= 0) {
    return;
}

// ---- Step 3: Cancel existing SELL orders ----
$accObj = GetAccountObj($myAcc);
$accObj.CancelOrder("SELL", $mySym, 0);

// Let cancels register
Wait(300);

// Re-read live position after cancels (in case something changed)
$posNow = $M.Pos;
if ($posNow <= 0) {
    // Flat now (maybe stop filled while we were messing around) -> nothing to do
    return;
}

// ---- Step 4: Compute shares to take ----
$tpRaw   = ($posNow * $takeProfitSize);
$takeQty = Round($tpRaw, 102, 1);      // nearest whole share

// Clamp: never more than current position
if ($takeQty > $posNow) { $takeQty = $posNow; }

// Must take at least 1 share if position exists
if ($takeQty < 1) { $takeQty = $posNow; }

// ---- Step 5: Compute exit price ----
$px = $M.Bid;

// Tick-size handling
$inc = 0.01;
if ($px < 1)    { $inc = 0.001; }
if ($px < 0.25) { $inc = 0.0005; }
$px = Round($px, 102, $inc);

// ---- Step 6: Send TP order ----
$order = NewOrderObj();
$order.Account = $myAcc;  
$order.Symbol  = $mySym;
$order.Side    = "S";     
$order.Type  = "L";
$order.Price = $px;
$order.Share = $takeQty;
$order.Route = "ARCAL";     
$order.Tif   = "DAY+";
$order.Send();

// ---- Step 7: Poll for fill ----
$pollMs          = 100;
$maxPolls      = 30;      // up to ~3s total
$filledState     = 0;       // 0 = none, 1 = full, 2 = partial

$i = 0;
while ($i < $maxPolls) {
    Wait($pollMs);
    $order.GetInfo();    // refresh order object

    // FULL fill: no remaining open shares on this TP order
    if ($order.Open == 0) {
        $filledState = 1;
        break;
    }

    $i = $i + 1;
}

// After polling, classify final state based on what we see
$filledQty = $order.Share - $order.Open;  // how many filled so far

if ($filledState != 1) {
    if ($filledQty > 0 && $order.Open > 0) {
        $filledState = 2;   // partial fill
    } else {
        $filledState = 0;   // no fill
    }
}

// Optional debug
// MsgBox("FilledState=" + $filledState + "  FilledQty=" + $filledQty +
//        "  Share=" + $order.Share + "  Open=" + $order.Open);

// Optional: small throttle between orders
$elapsed = $i * $pollMs;
if ($elapsed < 200) {
    Wait(200 - $elapsed);
}

// ---- Step 8: Re-arm stop and TP trigger ----

// Behavior:
// - Full fill (filledState == 1): re-arm BE stop only.
// - No fill or partial fill: re-arm 1R stop and TP trigger (if enabled).
if ($useAutoStop == "Yes") {

    if ($filledState == 1) {
        // FULL TP fill -> lock remaining at BE
        ExecHotkey("Set Auto Stop BE 1/1");
    } else {
        // No fill OR partial fill -> re-arm original 1R stop
        ExecHotkey("Set Auto Stop");
    }
}

// ---- Step 9: Re-establish take profit alert (if needed) ----
// Only when we did NOT get a FULL TP fill
Wait(2000);
if ($useTakeProfit == "Yes") {
    if ($filledState != 1) {
        ExecHotkey("Set Take Profit");
    }
}

// ---- End Take Profit Executor ----
