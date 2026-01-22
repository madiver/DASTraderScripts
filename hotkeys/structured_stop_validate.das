// =====================
// STRUCTURED STOP VALIDATE (1m)
// Group: Stops
// =====================
// Validates impulse/pullback structure on Chart_1m and sets structured globals.
// Result codes:
//  0 = PASS
//  1..11 = FAIL (see $structuredReason for code)

// ---- Reset outputs ----
$structuredOk = 0;
$structuredReason = 1;
$structuredType = "";
$structuredStop = 0;
$structuredR = 0;
$structuredSymbol = "";

// ---- Load chart ----
$chart = GetWindowObj("Chart_1m");
if (!IsObj($chart)) {
    MsgLog("Structured stop failed: Chart_1m not found.");
    return;
}

$symbol = $chart.Symbol;
$structuredSymbol = $symbol;

// ---- Load quote ----
$quote = GetQuoteObj($symbol);
if (!IsObj($quote)) {
    MsgLog("Structured stop failed: quote missing for " + $symbol + ".");
    return;
}
$bid = $quote.BID;

// ---- Live candle globals (from chart_1m.das) ----
if ($CURR_LAST <= 0 || $CURR_LOW <= 0) {
    MsgLog("Structured stop failed: live chart values missing for " + $symbol + ".");
    return;
}

// ============================================================
// Branch A: MICRO PULLBACK (bar -1 impulse + live rejection)
// ============================================================
$impBar = $chart.GetBar(-1);
$impOpen  = $impBar.OPEN;
$impClose = $impBar.CLOSE;
$impHi    = $impBar.HI;

$microOk = 0;
if ($impClose > $impOpen) {
    $impBody = $impClose - $impOpen;
    if ($impBody >= $structuredMinImpulse) {
        $prevBar = $chart.GetBar(-2);
        $prevBody = Abs($prevBar.CLOSE - $prevBar.OPEN);
        if ($impBody > $prevBody) {
            $microOk = 1;
            $impulseHigh = $impHi;
        }
    }
}

if ($microOk == 1) {
    // Tolerance: proportional with cap
    $microTol = $impBody * $structuredMicroTolPct;
    if ($microTol > $structuredMicroTolMax) { $microTol = $structuredMicroTolMax; }

    if ($CURR_LOW < ($impulseHigh - $microTol)) {
        $structuredReason = 10;
        // soft fail: allow pause-based pullback to evaluate
        $microOk = 0;
    }

    if ($microOk == 1 && $CURR_LAST > ($impulseHigh + $structuredMicroExt)) {
        $structuredReason = 11;
        MsgLog("Structured stop failed (11): micro price moved too far above impulse high [" + $symbol + "].");
        return;
    }

    if ($microOk == 1) {
        $rejectionLow = $CURR_LOW;
        $stop = $rejectionLow - $structuredBuffer;

        $inc = 0.01;
        if ($stop < 1 || $CURR_LAST < 1)       { $inc = 0.001; }
        if ($stop < 0.25 || $CURR_LAST < 0.25) { $inc = 0.0005; }
        $stop = Round($stop, 102, $inc);

        $dist = $CURR_LAST - $stop;

        if ($CURR_LAST <= $stop) {
            $structuredReason = 7;
            MsgLog("Structured stop failed (7): price already below stop [" + $symbol + "].");
            return;
        }
        if ($dist < $structuredMinClearance) {
            $structuredReason = 8;
            MsgLog("Structured stop failed (8): insufficient clearance above stop [" + $symbol + "].");
            return;
        }
        if ($dist > $structuredMaxStop) {
            $structuredReason = 6;
            MsgLog("Structured stop failed (6): stop distance too large [" + $symbol + "].");
            return;
        }

        $structuredOk = 1;
        $structuredReason = 0;
        $structuredType = "MICROPB";
        $structuredStop = $stop;
        $structuredR = $dist;
        MsgLog("Structured stop OK (MICROPB): stop $" + $structuredStop + " R $" + $structuredR + " [" + $symbol + "].");
        return;
    }
}

if ($structuredReason == 1) {
    $structuredReason = 9;
}

// ============================================================
// Branch B: FIXED PULLBACK (completed bars)
// ============================================================
$reason = 9;
$impulseIndex = 0;
$impulseLow = 0;

$i = 2;
while ($i <= $structuredMaxLookback) {
    $bar = $chart.GetBar(-$i);
    $open  = $bar.OPEN;
    $close = $bar.CLOSE;
    $low   = $bar.LO;

    if ($close > $open) {
        $body = $close - $open;
        if ($body >= $structuredMinImpulse) {
            $dominates = 1;
            $j = $i - 1;
            $checked = 0;
            while ($j >= 1 && $checked < $structuredMaxPullback) {
                $next = $chart.GetBar(-$j);
                $nextBody = Abs($next.CLOSE - $next.OPEN);
                if ($body <= $nextBody) { $dominates = 0; }
                $checked = $checked + 1;
                $j = $j - 1;
            }
            if ($dominates == 1) {
                $impulseIndex = $i;
                $impulseLow = $low;
                break;
            } else {
                $reason = 3;
            }
        } else {
            $reason = 2;
        }
    }
    $i = $i + 1;
}

if ($impulseIndex == 0) {
    if ($reason == 9) { $reason = 1; }
    $structuredReason = $reason;
    $reasonText = "no impulse found";
    if ($structuredReason == 2) { $reasonText = "impulse too small"; }
    if ($structuredReason == 3) { $reasonText = "impulse not dominant"; }
    if ($structuredReason == 9) { $reasonText = "micro impulse not valid (not bar -1)"; }
    MsgLog("Structured stop failed (" + $structuredReason + "): " + $reasonText + " [" + $symbol + "].");
    return;
}

// Pullback scan
$pullbackCount = 0;
$minPullbackLow = 999999;
$pullbackValid = 1;

$j = $impulseIndex - 1;
while ($j >= 1 && $pullbackCount < $structuredMaxPullback) {
    $bar = $chart.GetBar(-$j);
    $low = $bar.LO;

    if ($low <= $impulseLow) { $pullbackValid = 0; }
    if ($low < $minPullbackLow) { $minPullbackLow = $low; }

    $pullbackCount = $pullbackCount + 1;
    $j = $j - 1;
}

if ($pullbackCount == 0) {
    $structuredReason = 4;
    MsgLog("Structured stop failed (4): impulse found but no pullback yet [" + $symbol + "].");
    return;
}
if ($pullbackValid == 0) {
    $structuredReason = 5;
    MsgLog("Structured stop failed (5): pullback broke impulse low [" + $symbol + "].");
    return;
}

$stop = $minPullbackLow - $structuredBuffer;
$inc = 0.01;
if ($stop < 1 || $bid < 1)       { $inc = 0.001; }
if ($stop < 0.25 || $bid < 0.25) { $inc = 0.0005; }
$stop = Round($stop, 102, $inc);

$dist = $bid - $stop;

if ($bid <= $stop) {
    $structuredReason = 7;
    MsgLog("Structured stop failed (7): price already below stop [" + $symbol + "].");
    return;
}
if ($dist < $structuredMinClearance) {
    $structuredReason = 8;
    MsgLog("Structured stop failed (8): insufficient clearance above stop [" + $symbol + "].");
    return;
}
if ($dist > $structuredMaxStop) {
    $structuredReason = 6;
    MsgLog("Structured stop failed (6): stop distance too large [" + $symbol + "].");
    return;
}

$structuredOk = 1;
$structuredReason = 0;
$structuredType = "STDPB";
$structuredStop = $stop;
$structuredR = $dist;
MsgLog("Structured stop OK (STDPB): stop $" + $structuredStop + " R $" + $structuredR + " [" + $symbol + "].");
