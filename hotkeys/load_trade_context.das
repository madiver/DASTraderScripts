// Group: Utilities & toggles
// Internal context selector. Overrides are consumed once; never changes a montage.
$tradeContextValid = 0;
$tcPositionOnly = GetVar("TRADE_POSITION_ONLY") * 1;
SetVar("TRADE_POSITION_ONLY", 0);
$tcAccount = StrTrim("" + GetVar("TRADE_CONTEXT_ACCOUNT"));
$tcSymbol = StrTrim("" + GetVar("TRADE_CONTEXT_SYMBOL"));
SetVar("TRADE_CONTEXT_ACCOUNT", "");
SetVar("TRADE_CONTEXT_SYMBOL", "");
if ($tcAccount == "" && $tcSymbol == "") {
    $M = GetWindowObj("Primary_OE");
    if (!IsObj($M)) { return; }
    $tcAccount = StrTrim("" + $M.Account);
    $tcSymbol = StrTrim("" + $M.Symb);
}
if ($tcAccount == "" || $tcSymbol == "") { return; }
if (!IsObj(GetVar("tradeStates")) || !IsObj(GetVar("tradeSlots"))) {
    MsgLog("Trade context unavailable: run Set Global Variables first.");
    return;
}
$tcKey = $tcAccount + "|" + $tcSymbol;
$trade = $tradeStates.Get($tcKey);
if (!IsObj($trade)) {
    $trade = NewUserObj();
    $trade.account = $tcAccount;
    $trade.symbol = $tcSymbol;
    $trade.key = $tcKey;
    $trade.listed = 0;
    $trade.active = 0;
    $trade.generation = 1;
    $trade.deferredTp = 0;
    $trade.deferredBackstop = 0;
    $trade.entryPending = 0;
    $trade.entryStage = 0;
    $trade.entryTicks = 0;
    $trade.entryPosBefore = 0;
    $trade.entryAvgBefore = 0;
    $trade.entryScaleIn = 0;
    $trade.entryRefPx = 0;
    $trade.entryWatch = 0;
    $trade.entryLastPos = 0;
    $trade.lastStop = 0;
    $trade.stopArmed = 0;
    $trade.tpName = "";
    $trade.backstopArmed = 0;
    $trade.backstopRetries = 0;
    $trade.backstopStop = 0;
    $tradeStates.Set($tcKey, $trade);
}
// Initialize new fields once, including contexts retained by LOAD CFG.
if ($trade.Get("performanceStateVersion") != 1) {
    $trade.exitPending = 0;
    $trade.exitStage = 0;
    $trade.exitOrder = 0;
    $trade.exitGeneration = 0;
    $trade.exitStartPos = 0;
    $trade.exitQty = 0;
    $trade.exitStarted = 0;
    $trade.exitTimeout = 0;
    $trade.exitIsTp = 0;
    $trade.exitFullFill = 0;
    $trade.exitCancelWarned = 0;
    $trade.lastEntrySecond = 0;
    $trade.Set("performanceStateVersion", 1);
}
// Preserve live orders across LOAD CFG and coordinator upgrades.
if ($trade.Get("exitCoordinatorVersion") != 1) {
    $trade.closeManaged = 0;
    $trade.entryOrder = 0;
    $trade.protectionOrder = 0;
    $trade.closeRequest = 0;
    $trade.closePriority = 0;
    $trade.closeStage = 0;
    $trade.closeScanRef = 0;
    $trade.closeTargetSet = 0;
    $trade.closeTargetAbs = 0;
    $trade.closeWarned = 0;
    // Upgrade a retained legacy partial without dropping its working order.
    if ($trade.exitPending == 1 && IsObj($trade.exitOrder) && $trade.exitStartPos > 0 && $trade.exitQty > 0) {
        $migrateExit = NewUserObj();
        $migrateExit.account = $trade.account;
        $migrateExit.symbol = $trade.symbol;
        $migrateExit.kind = "ASK";
        $migrateExit.priority = 20;
        if ($trade.exitIsTp == 1) { $migrateExit.kind = "TP"; $migrateExit.priority = 10; }
        $migrateExit.direction = 1;
        $migrateExit.fraction = $trade.exitQty / $trade.exitStartPos;
        $migrateExit.route = $trade.exitOrder.Route;
        $migrateExit.offset = 0;
        $migrateExit.generation = $trade.generation;
        $trade.closeRequest = $migrateExit;
        $trade.closePriority = $migrateExit.priority;
        $trade.closeManaged = 1;
        $trade.closeStage = 2;
        if ($trade.exitStage >= 2) { $trade.closeStage = 3; }
        $trade.closeTargetAbs = $trade.exitStartPos - $trade.exitQty;
        $trade.closeTargetSet = 1;
        $trade.active = 1;
    }
    $trade.Set("exitCoordinatorVersion", 1);
}
// Reuse inactive slots; DAS limits each while loop to 200 iterations.
if ($trade.listed != 1) {
    $tcSlot = 0;
    $tcFound = 0;
    while ($tcSlot < $tradeSlotCount && $tcFound == 0) {
        $tcOld = $tradeSlots.Get($tcSlot);
        $tcReusable = 0;
        if (IsObj($tcOld)) {
            if ($tcOld.active == 0 && $tcOld.entryPending == 0) { $tcReusable = 1; }
        }
        if ($tcReusable == 1) {
            $tcOld.listed = 0;
            $tcFound = 1;
        } else { $tcSlot = $tcSlot + 1; }
    }
    if ($tcFound == 0) {
        if ($tradeSlotCount >= 200) {
            MsgLog("Trade context capacity reached; no order sent.");
            return;
        }
        $tradeSlotCount = $tradeSlotCount + 1;
    }
    $tradeSlots.Set($tcSlot, $trade);
    $trade.listed = 1;
}
$myAcc = $trade.account;
$mySym = $trade.symbol;
$tradeContextValid = 1;
SetVar("TRADE_POSITION_ONLY", $tcPositionOnly);
ExecHotkey("Read Trade Position");
