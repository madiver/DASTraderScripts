// Group: Utilities & toggles
// Internal: suspend entry staging and invalidate alerts for a manual cancel/exit.
if ($tradeContextValid != 1 || !IsObj($trade)) { return; }
if ($trade.tpName != "") {
    $invalidateAlert = GetAlertObj($trade.tpName);
    if (IsObj($invalidateAlert)) { $invalidateAlert.Delete(); }
}
$invalidateAlert = GetAlertObj("Backstop " + $trade.account + " " + $trade.symbol);
if (IsObj($invalidateAlert)) { $invalidateAlert.Delete(); }
$trade.generation = $trade.generation + 1;
$trade.tpName = "";
$trade.backstopArmed = 0;
$trade.backstopRetries = 0;
$trade.backstopStop = 0;
$trade.deferredTp = 0;
$trade.deferredBackstop = 0;

$trade.entryPending = 0;
$trade.entryStage = 0;
$trade.entryTicks = 0;
$trade.entryWatch = 0;
$trade.stopArmed = 0;
