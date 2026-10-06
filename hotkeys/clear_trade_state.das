// Group: Utilities & toggles
// Only call for a confirmed flat/short context with no pending long entry.
if ($tradeContextValid != 1 || $tradePositionValid != 1 || $posNow > 0) { return; }
if ($trade.entryPending == 1 && $posNow == 0) { return; }
if ($trade.tpName != "") {
    $cleanupAlert = GetAlertObj($trade.tpName);
    if (IsObj($cleanupAlert)) { $cleanupAlert.Delete(); }
}
$cleanupAlert = GetAlertObj("Backstop " + $trade.account + " " + $trade.symbol);
if (IsObj($cleanupAlert)) { $cleanupAlert.Delete(); }
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
$trade.backstopArmed = 0;
$trade.backstopRetries = 0;
$trade.backstopStop = 0;

$trade.deferredTp = 0;
$trade.deferredBackstop = 0;
