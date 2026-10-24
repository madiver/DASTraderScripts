// Group: Utilities & toggles
// Internal: suspend entry staging and invalidate alerts for a manual cancel/exit.
if ($tradeContextValid != 1 || !IsObj($trade)) { return; }
// Manual actions cancel/replace protection; retain no short re-arm intent.
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
    $invalidateAlert = GetAlertObj($trade.tpName);
    if (IsObj($invalidateAlert)) { $invalidateAlert.Delete(); }
}
$trade.generation = $trade.generation + 1;
$trade.tpName = "";
$trade.deferredTp = 0;

$trade.entryPending = 0;
$trade.entryStage = 0;
$trade.entryTicks = 0;
$trade.entryWatch = 0;
$trade.stopArmed = 0;
