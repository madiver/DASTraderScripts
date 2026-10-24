// Group: Utilities & toggles
// Only call for a confirmed flat/short context with no pending long entry.
if ($tradeContextValid != 1 || $tradePositionValid != 1 || $posNow > 0) { return; }
if ($trade.entryPending == 1 && $posNow == 0) { return; }
// Cancel only this RESET-owned short stop before discarding its identity.
$cleanupShortStop = $trade.Get("shortStopOrder");
if (IsObj($cleanupShortStop)) { $cleanupShortStop.Cancel(); }
$trade.Set("shortStopOrder", 0);
$trade.shortWatch = 0;
$trade.shortEntryPending = 0;
$trade.shortEntryOrder = 0;
$trade.shortEntryTicks = 0;
$trade.shortCoverPending = 0;
$trade.shortStopQty = 0;
$trade.shortStopAvg = 0;
$trade.shortBuyScanRef = 0;
$trade.tpCancelPending = 0;
$trade.shortTpQty = 0;
$trade.shortTpAvg = 0;
$trade.shortTpDone = 0;
$trade.shortTpInvalidLogged = 0;
$trade.shortStopBE = 0;
// Stop timer-owned partial exits before a manual cancel/emergency action.
if ($trade.exitPending == 1 && IsObj($trade.exitOrder)) { $trade.exitOrder.Cancel(); }
$trade.exitPending = 0;
$trade.exitStage = 0;
$trade.exitOrder = 0;
if ($trade.tpName != "") {
    $cleanupAlert = GetAlertObj($trade.tpName);
    if (IsObj($cleanupAlert)) { $cleanupAlert.Delete(); }
}
if ($trade.active == 1) { $trade.generation = $trade.generation + 1; }
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

$trade.deferredTp = 0;
