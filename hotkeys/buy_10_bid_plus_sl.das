// =====================
//  SCALING-AWARE ENTRY
// Group: Buy orders: Bid+ SL
// =====================

FocusWindow Primary_OE;

// ---- Global daily-loss guard per account ----
$accName = GetVar("DAY_ACC");
$lockKey = "TRADING_LOCKED_" + $accName;
$locked  = GetVar($lockKey) * 1;

if ($locked == 1) {
    MsgBox("Trading locked for " + $accName + " (daily loss limit hit).");
    return;
}

// Set ENTRY_SYM and clear TP_SYMBOL
$M = GetWindowObj("Primary_OE");
if (IsObj($M)) {
    $entrySymbol = $M.Symb;
} else {
    $entrySymbol = Symbol;
}
$tpSymbol = "";

// --- Capture pre-entry position & average cost (for TP logic) ---
$posBefore = 0;
$avgBefore = 0;

if (IsObj($M)) {
    $posBefore = $M.Pos;
    $avgBefore = $M.AvgCost;
} else {
    $posBefore = Pos;
    $avgBefore = AvgCost;
}

if ($rehab ==1 && $M.Pos > 0 && $ACCOUNT_STATE == "live") {
    MsgBox("ABORTED: Rehab size violation, scaling in not allowed!");
    return;
}

// Ice Breaker = 1/4 of normal share size
$quarter = 50 * $qtyMult * 0.25;
$scaled = $quarter + 2.5;
$addShares = $scaled - ($scaled % 5);

// ---- Tunables ----
$refPx             = BID;             // BID or ASK
$minDelayMs  = 1000;           // throttle between order sends (ms)

// ---- Max position size guard rail ----
if ($maxPositionSize > 0) {    
    // Determine current position in Primary_OE (fallback: Pos)
    $curPos = 0;
    if (IsObj($M)) {
        $curPos = $M.Pos;
    } else {
        $curPos = Pos;        // DAS built-in position for current symbol
    }

    // Remaining capacity before hitting the guard rail
    $remaining = $maxPositionSize - $curPos;

    // If we're already at / above max, do not allow more size
    if ($remaining <= 0) {
        MsgBox("Max position size reached for " + Symbol + 
               " (" + $maxPositionSize + " shares). No additional size allowed.");
        return;
    }

    // If this clip would exceed max size, clamp it down
    if ($addShares > $remaining) {
        $addShares = $remaining;
    }

}

// ---- Tick-size Bands (no functions; simple if-else ladder) ----
// We’ll resolve the increment later using current prices.
//   < $0.25  -> 0.0005
//   < $1.00  -> 0.001
//   ≥ $1.00  -> 0.01

// === 0) Quote sanity & derived prices for safety check ===
$bid    = BID;
$ask    = ASK;
$spread = $ask - $bid;

if ($bid <= 0 || $ask <= 0 || $spread < 0) {
    MsgBox("Quote sanity failed for " + Symbol + ": BID=" + $bid + " ASK=" + $ask + ". Aborting.");
    return;
}

// Projected entry/stop based on reference side
$pxEntry    = $refPx + $entryOffset;
$hypoStop = $pxEntry - $stopLossTrigger;

// ---- Resolve tick increment for safety checks (based on current context) ----
$inc = 0.01;
if ($pxEntry < 1 || $hypoStop < 1 || $bid < 1 || $ask < 1)        { $inc = 0.001; }
if ($pxEntry < 0.25 || $hypoStop < 0.25 || $bid < 0.25 || $ask < 0.25) { $inc = 0.0005; }

// === 1) Slippage-aware spread/stop safety (longs) ===
$stopVsBidFail = 0;

// margin for safety = max(slipTicksMin * inc, slipSpreadFrac * spread)
$slipMargin         = ($slipTicksMin * $inc);
$slipSpreadPart  = ($slipSpreadFrac * $spread);
if ($slipSpreadPart > $slipMargin) { $slipMargin = $slipSpreadPart; }

if ($useSlippageMargin == 1) {
    // Require stop to be below (Bid + margin)
    if ($hypoStop >= ($bid + $slipMargin)) { $stopVsBidFail = 1; }
} else {
    if ($hypoStop >= $bid) { $stopVsBidFail = 1; }
}

// spread relative to stop distance guard (tune threshold as desired)
$spreadTooWide = ($spread > ($stopLossTrigger * 0.75)) && $useSpreadCheck == 1;

// If either fails, alert and abort unless we are adding to an existing position
if (($stopVsBidFail == 1 || $spreadTooWide == 1) && $posBefore <=0) {
    $msg = "Spread/Stop safety failed for " + Symbol + "\n" +
           "Bid: " + $bid + "  Ask: " + $ask + "  Spread: " + $spread + "\n" +
           "Planned Entry: " + $pxEntry + "  Planned Stop: " + $hypoStop + "\n\n";
    if ($stopVsBidFail == 1)  { $msg = $msg + "- STOP_ABOVE_BID_WITH_MARGIN\n"; }
    if ($spreadTooWide == 1)  { $msg = $msg + "- SPREAD_TOO_WIDE vs stopOff\n"; }
    MsgBox($msg + "\nAction aborted.");
    return;
}

// Per-trade risk cap (projected risk = stopLossTrigger * addShares)
if ($usePerTradeRiskCap == 1) {
    $projRisk = $stopLossTrigger * $addShares;
    if ($projRisk > $riskCapDollars) {
        MsgBox("Risk cap exceeded for " + Symbol + ": projected $" + $projRisk + " > cap $" + $riskCapDollars + ". Aborting.");
        return;
    }
}

// === 2) Cancel only BUY working orders (keep existing protection until we actually fill) ===
$acc = GetAccountObj(Account);
$acc.CancelOrder("BUY", Symbol, 0);

// === 3) Build entry; snap entry to increment to reduce rejects ===
// Re-evaluate inc using pxEntry (some symbols jump bands)
$inc = 0.01;
if ($pxEntry < 1 || $bid < 1 || $ask < 1) { $inc = 0.001; }
if ($pxEntry < 0.25 || $bid < 0.25 || $ask < 0.25) { $inc = 0.0005; }
$pxEntry = Round($pxEntry, 102, $inc);

$order = NewOrderObj();
$order.Account = Account;
$order.Symbol  = Symbol;
$order.Route   = "ARCA";
$order.Tif     = "DAY+";
$order.Side    = "B";      // Buy
$order.Type    = "L";      // Limit
$order.Price   = $pxEntry;
$order.Share   = $addShares;
$order.Send();


// === 4) Poll for fill (break when criteria met) ===
$i            = 0;
$filled      = 0;
$filledQty = 0;
while ($i < $maxPolls && $filled == 0) {
    Wait($pollMs);
    $order.GetInfo();                        // refresh order object
    $filledQty = $order.Share - $order.Open; // how many filled so far
    if ($order.Open == 0) {
        $filled = 1; // full fill
        break;
    }
    if ($acceptPartial == 1 && $filledQty >= $minFillShares) {
        $filled = 2; // partial-accepted
        break;
    }
    $i = $i + 1;
}

// throttle between orders
$elapsed = $i * $pollMs;
if ($elapsed < $minDelayMs) {
    Wait($minDelayMs - $elapsed);
}

// === 5) If no acceptable fill, cancel and exit (do not touch existing stops) ===
if ($filled == 0) {
    $order.Cancel();
    return;
}

// Optional: if we accepted a partial and want to freeze size before arming stop
if ($filled == 2 && $cancelRemainderOnPartial == 1) {
    $order.Cancel();
    // brief wait to let the residual cancel
    Wait(200);
}

// === 6) Arm unified 1R stop via reusable “Set Auto Stop” script ===
if ($useAutoStop == "Yes") {
    ExecHotKey("Set Auto Stop");   
}

// == 7) Build and set take profit trigger (optional) ==
// Only (re)build TP if we are NOT already profitable on the existing position.
// For longs, "profitable" means: BID > avgBefore on the position that existed
// before this entry. If we're already green, do NOT reset TP.
if ($useTakeProfit == "Yes") {

    // If no position beforehand, always set TP (fresh trade)
    if ($posBefore <= 0) {
        ExecHotKey("Set Take Profit");
    } else {
        // We had a long position before this add. Check profitability.
        $bidNow = BID;

        // If avgBefore is invalid, be conservative and allow TP reset
        if ($avgBefore <= 0) {
            ExecHotKey("Set Take Profit");
        } else {
            // Only reset TP if NOT yet profitable (bid <= avgBefore)
            if ($bidNow <= $avgBefore) {
                ExecHotKey("Set Take Profit");
            }
            // else: already profitable → do nothing, keep existing TP
        }
    }
}

// --- End ---