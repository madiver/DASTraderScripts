// Group: Utilities & toggles
// Caller owns the action lease and explicitly binds $trade. Timer calls never wait.
if ($tradeContextValid != 1) { return; }
ExecHotkey("Read Position Only");
if (!IsObj($tradeAccountObj)) { return; }
$cxLimit = $exitPollCount;
if ($cxLimit < 0) { $cxLimit = 0; }
if ($cxLimit > 8) { $cxLimit = 8; }
if (GetVar("EXIT_FROM_TIMER") * 1 == 1) { $cxLimit = 0; }
SetVar("EXIT_FROM_TIMER", 0);
$cxPoll = 0;
while ($cxPoll <= $cxLimit) {
    // A press during a short poll replaces only the request, never live orders.
    $cxQueued = $exitRequests.Get($trade.key);
    if (IsObj($cxQueued)) {
        $exitRequests.Del($trade.key);
        $cxAccept = 1;
        if ($cxQueued.generation > 0 && $cxQueued.generation != $trade.generation) { $cxAccept = 0; }
        $cxPrevious = $trade.closeRequest;
        // The previous request is 0 while idle; logical operands are not guards.
        if (IsObj($cxPrevious)) {
            if ($trade.closeManaged == 1 && $trade.exitPending == 1 && $trade.closePriority > $cxQueued.priority && $cxPrevious.kind != "CANCEL" && $cxPrevious.kind != "CANCEL_NO_STOPS") { $cxAccept = 0; }
        }
        if ($cxAccept == 1) {
            // Preserve the original partial target when repricing the same fraction.
            $cxKeepTarget = 0;
            if (IsObj($cxPrevious)) {
                if ($trade.closeManaged == 1 && $trade.exitPending == 1) {
                    if ($cxPrevious.direction == $cxQueued.direction && $cxPrevious.fraction == $cxQueued.fraction && $cxQueued.priority == $trade.closePriority) {
                        $cxKeepTarget = $trade.closeTargetSet;
                    }
                }
            }
            $trade.closeTargetSet = $cxKeepTarget;
            $trade.closeRequest = $cxQueued;
            $trade.closePriority = $cxQueued.priority;
            $trade.closeManaged = 1;
            $trade.closeStage = 1;
            $trade.closeScanRef = $trade.Get("closedOrderRef");
            $trade.closeWarned = 0;
            $trade.exitPending = 1;
            $trade.exitIsTp = 0;
            if ($cxQueued.kind == "TP") { $trade.exitIsTp = 1; }
            $trade.exitStarted = GetSecond();
            $trade.active = 1;
            if ($cxQueued.generation == 0) { ExecHotkey("Invalidate Trade Alerts"); }
            $trade.Set("stopRetry", "");
            $trade.entryPending = 0;
            $trade.entryWatch = 0;
            $trade.stopArmed = 0;
            $tradeAccountObj.CancelOrder("BUY|SELL", $trade.symbol, 0);
            if (IsObj($trade.exitOrder)) { $trade.exitOrder.Cancel(); }
        }
    }
    if ($trade.closeManaged != 1 || $trade.exitPending != 1) { return; }
    $cxRequest = $trade.closeRequest;
    if (!IsObj($cxRequest)) { return; }
    if ($trade.closeStage == 1) {
        ExecHotkey("Check Exit Orders");
        if ($exitOrdersClear == 1) {
            ExecHotkey("Read Trade Position");
            if ($tradePositionValid == 1) {
                $cxAbs = $posNow * $cxRequest.direction;
                if ($cxAbs <= 0 || $cxRequest.kind == "CANCEL" || $cxRequest.kind == "CANCEL_NO_STOPS") {
                    $trade.closeStage = 3;
                } else {
                    if ($trade.closeTargetSet != 1) {
                        $cxQty = $cxAbs * $cxRequest.fraction;
                        $cxQty = $cxQty - ($cxQty % 1);
                        if ($cxQty < 1) { $cxQty = 1; }
                        if ($cxQty > $cxAbs) { $cxQty = $cxAbs; }
                        $trade.closeTargetAbs = $cxAbs - $cxQty;
                        $trade.closeTargetSet = 1;
                    }
                    $cxQty = $cxAbs - $trade.closeTargetAbs;
                    $cxQty = $cxQty - ($cxQty % 1);
                    if ($cxQty <= 0) { $trade.closeStage = 3; }
                    else {
                        $cxPx = 0;
                        if ($cxRequest.kind == "ASK") { $cxPx = $tradeAsk; }
                        if ($cxRequest.kind == "BID" || $cxRequest.kind == "TP") { $cxPx = $tradeBid; }
                        if ($cxRequest.kind == "BID_MINUS") { if ($tradeBid > 0) { $cxPx = $tradeBid - $cxRequest.offset; } }
                        if ($cxRequest.kind == "ASK_PLUS") { if ($tradeAsk > 0) { $cxPx = $tradeAsk + $cxRequest.offset; } }
                        if ($cxRequest.kind == "EMERGENCY" || $cxRequest.kind == "BACKSTOP" || $cxRequest.kind == "HIJACK") {
                            $cxRef = $tradeBid;
                            if ($cxRequest.direction < 0) { $cxRef = $tradeAsk; }
                            if ($cxRef <= 0) { $cxRef = $tradeLast; }
                            if ($cxRef > 0) { $cxPx = $cxRef - $cxRequest.direction * $cxRequest.offset; }
                        }
                        if ($cxPx <= 0 && $tradeBid > 0 && ($cxRequest.kind == "BID_MINUS" || $cxRequest.kind == "BACKSTOP")) { $cxPx = 0.0005; }
                        if ($cxPx <= 0) { MsgLog("Exit awaits a valid quote for " + $trade.key + "."); return; }
                        $cxInc = 0.01;
                        if ($cxPx < 1) { $cxInc = 0.001; }
                        if ($cxPx < 0.25) {
                            $cxInc = 0.0001;
                            if ($cxRequest.direction == 1 && $cxRequest.priority < 50 && $cxRequest.kind != "HIJACK") { $cxInc = 0.0005; }
                        }
                        $cxTicks = ($cxPx / $cxInc) + 0.5;
                        $cxTicks = $cxTicks - ($cxTicks % 1);
                        $cxPx = $cxTicks * $cxInc;
                        if ($cxPx <= 0) { return; }
                        // Last signed-position read immediately before constructing the order.
                        ExecHotkey("Read Position Only");
                        if ($tradePositionValid != 1) { return; }
                        $cxAbs = $posNow * $cxRequest.direction;
                        $cxQty = $cxAbs - $trade.closeTargetAbs;
                        $cxQty = $cxQty - ($cxQty % 1);
                        if ($cxAbs <= 0 || $cxQty <= 0) { $trade.closeStage = 3; }
                        else {
                            $trade.exitOrder = NewOrderObj();
                            $trade.exitOrder.Account = $trade.account;
                            $trade.exitOrder.Symbol = $trade.symbol;
                            $trade.exitOrder.Route = $cxRequest.route;
                            $trade.exitOrder.Tif = "DAY+";
                            $trade.exitOrder.Side = "S";
                            if ($cxRequest.direction < 0) { $trade.exitOrder.Side = "B"; }
                            $trade.exitOrder.Type = "L";
                            $trade.exitOrder.Price = $cxPx;
                            $trade.exitOrder.Share = $cxQty;
                            $trade.exitStartPos = $cxAbs;
                            $trade.exitQty = $cxQty;
                            $trade.exitStarted = GetSecond();
                            $trade.exitTimeout = 0;
                            if ($cxRequest.fraction < 1) { $trade.exitTimeout = ($maxPolls * $pollMs) / 1000; }
                            if ($cxRequest.kind == "TP") { $trade.exitTimeout = 3; }
                            $trade.exitIsTp = 0;
                            if ($cxRequest.kind == "TP") { $trade.exitIsTp = 1; }
                            $trade.exitFullFill = 0;
                            $trade.closeStage = 2;
                            $trade.exitOrder.Send();
                            MsgLog("Exit " + $cxRequest.kind + ": " + $cxQty + " " + $trade.key + " at " + $cxPx + ".");
                            if ($cxRequest.kind == "BACKSTOP" && $trade.backstopRetries > 0) { ExecHotkey("Build Backstop Alert"); }
                            return;
                        }
                    }
                }
            }
        }
    }
    if ($trade.closeStage == 2) {
        if (!IsObj($trade.exitOrder)) { return; }
        $trade.exitOrder.GetInfo();
        ExecHotkey("Read Position Only");
        $cxFinish = 0;
        if ($tradePositionValid == 1) {
            if ($posNow * $cxRequest.direction <= $trade.closeTargetAbs) { $cxFinish = 1; }
        }
        $closingOrder = $trade.exitOrder;
        ExecHotkey("Check Order Closed");
        if ($orderClosed == 1) { $cxFinish = 1; }
        $cxElapsed = GetSecond() - $trade.exitStarted;
        if ($cxElapsed < 0) { $cxElapsed = $cxElapsed + 86400; }
        if ($trade.exitTimeout > 0 && $cxElapsed >= $trade.exitTimeout) { $cxFinish = 1; }
        if ($cxFinish != 1) { return; }
        $trade.exitOrder.Cancel();
        $trade.closeScanRef = $trade.Get("closedOrderRef");
        $trade.closeStage = 3;
    }
    if ($trade.closeStage == 3) {
        ExecHotkey("Check Exit Orders");
        if ($exitOrdersClear == 1) {
            ExecHotkey("Read Position Only");
            if ($tradePositionValid == 1) {
                $trade.exitFullFill = 0;
                if ($trade.closeTargetSet == 1 && $posNow * $cxRequest.direction <= $trade.closeTargetAbs) { $trade.exitFullFill = 1; }
                $trade.closeStage = 6;
                // Only long exits restore long protection. Covers never arm SELLs.
                if ($posNow > 0 && $cxRequest.direction == 1 && ($cxRequest.priority < 30 || $cxRequest.kind == "CANCEL")) {
                    if ($cxRequest.kind != "CANCEL" || $resetStopOnCancel == "Yes") { $trade.closeStage = 4; }
                }
            }
        }
    }
    if ($trade.closeStage == 4) {
        ExecHotkey("Read Position Only");
        if ($tradePositionValid != 1) { return; }
        if ($posNow <= 0) { $trade.closeStage = 6; }
        else {
            if ($useAutoStop == "Yes") {
                $timerMode = 1;
                SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
                SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
                if ($trade.exitIsTp == 1 && $trade.exitFullFill == 1) { ExecHotkey("Set Auto Stop BE 1/1"); }
                else { ExecHotkey("Set Auto Stop"); }
                if ($stopSubmitted != 1) { return; }
            }
            $trade.entryLastPos = $posNow;
            $trade.closeStage = 5;
        }
    }
    if ($trade.closeStage == 5) {
        if ($useTakeProfit == "Yes" && $cxRequest.kind != "CANCEL" && ($trade.exitIsTp != 1 || $trade.exitFullFill != 1)) {
            $timerMode = 1;
            SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
            SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
            ExecHotkey("Set Take Profit");
            if ($tpCreated != 1) { return; }
        }
        $trade.closeStage = 6;
    }
    if ($trade.closeStage == 6) {
        $trade.closeManaged = 0;
        $trade.closeRequest = 0;
        $trade.closePriority = 0;
        $trade.closeTargetSet = 0;
        $trade.closeScanRef = $trade.Get("closedOrderRef");
        $trade.exitPending = 0;
        $trade.exitStage = 0;
        $trade.exitOrder = 0;
        if ($posNow <= 0) { ExecHotkey("Clear Trade State"); }
        else {
            $trade.entryWatch = 0;
            if ($cxRequest.direction == 1 && ($cxRequest.priority < 30 || ($cxRequest.kind == "CANCEL" && $resetStopOnCancel == "Yes"))) { $trade.entryWatch = 1; }
        }
        return;
    }
    // Short inline checks improve responsiveness; the timer handles slow acknowledgments.
    $cxElapsed = GetSecond() - $trade.exitStarted;
    if ($cxElapsed < 0) { $cxElapsed = $cxElapsed + 86400; }
    if ($cxElapsed >= 30 && $trade.closeWarned != 1) {
        MsgLog("Exit cancellation still pending for " + $trade.key + "; no overlapping order sent.");
        $trade.closeWarned = 1;
    }
    if ($cxPoll >= $cxLimit) { return; }
    Wait($exitPollMs);
    $cxPoll = $cxPoll + 1;
}
