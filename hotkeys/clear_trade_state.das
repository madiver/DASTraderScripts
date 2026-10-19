// Group: Utilities & toggles
// Only call for a confirmed flat/short context with no pending long entry.
if ($tradeContextValid != 1 || $tradePositionValid != 1 || $posNow > 0) { return; }
if ($trade.entryPending == 1 && $posNow == 0) { return; }
// Do not discard an outstanding coordinated exit, even when position reads flat.
if ($trade.closeManaged == 1 && $trade.exitPending == 1) {
    if (IsObj($trade.exitOrder)) { $trade.exitOrder.Cancel(); }
    $trade.active = 1;
    $trade.closeStage = 3;
    $trade.closeScanRef = 0;
    return;
}
// Stop legacy timer-owned partial exits before a manual action.
if ($trade.exitPending == 1 && IsObj($trade.exitOrder)) { $trade.exitOrder.Cancel(); }
$trade.exitPending = 0;
$trade.exitStage = 0;
$trade.exitOrder = 0;
if ($trade.tpName != "") {
    $cleanupAlert = GetAlertObj($trade.tpName);
    if (IsObj($cleanupAlert)) { $cleanupAlert.Delete(); }
}
$cleanupAlert = GetAlertObj("Backstop " + $trade.account + " " + $trade.symbol);
if (IsObj($cleanupAlert)) { $cleanupAlert.Delete(); }
if ($trade.active == 1) { $trade.generation = $trade.generation + 1; }
$trade.Set("stopRetry", "");
$trade.active = 0;
$trade.entryPending = 0;
$trade.entryStage = 0;
$trade.entryTicks = 0;
$trade.entryWatch = 0;
$trade.entryLastPos = 0;
$trade.entryScaleIn = 0;
$trade.entryRefPx = 0;
$trade.entryPosBefore = 0;
$trade.entryAvgBefore = 0;
$trade.lastStop = 0;
$trade.stopArmed = 0;
$trade.tpName = "";
$trade.backstopArmed = 0;
$trade.backstopRetries = 0;
$trade.backstopStop = 0;

$trade.deferredTp = 0;
$trade.deferredBackstop = 0;
