// Group: Utilities & toggles
// Internal: resolve a single submission without changing the selected mode.
// Inputs (set every call): routeRequest, routeSide (B/S/SS), routeLimit,
// routeBid, routeAsk, routeUrgent. Output: resolvedOrderRoute (empty = abort).
// Supported route availability: 04:00-20:00 ET, monitored by the operator.
// No clock conversion, retry, or automatic rerouting is performed here.
$resolvedOrderRoute = $routeRequest;
if ($orderRoute != "AUTOL") { return; }
$resolvedOrderRoute = "";
if ($routeUrgent == 1) {
    $resolvedOrderRoute = "BESTL";
    MsgLog("AUTOL -> BESTL: urgent exit.");
    return;
}
if ($routeLimit <= 0 || $routeBid <= 0 || $routeAsk <= 0) {
    MsgLog("AUTOL: invalid limit or quotes; no order submitted.");
    return;
}
// Classify the final limit against the opposite quote, not the hotkey label.
// This predicts adding/taking; actual fills and liquidity fees may differ.
$autoRoutePrice = $routeLimit;
$autoRouteAdding = 0;
if ($routeSide == "B") {
    if ($routeLimit < $routeAsk) {
        $autoRouteAdding = 1;
    } else {
        $autoRoutePrice = $routeAsk;
    }
} else {
    if ($routeSide != "S" && $routeSide != "SS") {
        MsgLog("AUTOL: unsupported order side; no order submitted.");
        return;
    }
    if ($routeLimit > $routeBid) {
        $autoRouteAdding = 1;
    } else {
        $autoRoutePrice = $routeBid;
    }
}
if ($autoRouteAdding == 1) {
    $resolvedOrderRoute = "ARCA1L";
    MsgLog("AUTOL -> ARCA1L: expected adding liquidity at limit " + $routeLimit + ".");
    return;
}
// SMRT is flat $0.0015/share at all prices (broker confirmation).
// Compare costs directly so equality selects BEST without a rounded threshold.
if ($autoRoutePrice >= 1) {
    // FREE1L remains a manual preset; AUTOL uses BESTL at $1 and above.
    $resolvedOrderRoute = "BESTL";
} else {
    if ($autoRoutePrice * 0.0036 <= 0.0015) {
        $resolvedOrderRoute = "BESTL";
    } else {
        $resolvedOrderRoute = "SMRTL";
    }
}
MsgLog("AUTOL -> " + $resolvedOrderRoute + " at expected price " + $autoRoutePrice + ".");
