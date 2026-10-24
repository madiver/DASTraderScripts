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
// Initialize short protection for new and retained contexts.
if ($trade.Get("shortProtectionStateVersion") != 1) {
    $trade.shortWatch = 0;
    $trade.shortEntryPending = 0;
    $trade.shortEntryOrder = 0;
    $trade.shortEntryTicks = 0;
    $trade.shortEntryPosBefore = 0;
    $trade.shortCoverPending = 0;
    $trade.shortStopQty = 0;
    $trade.shortStopAvg = 0;
    $trade.shortBuyScanRef = 0;
    $trade.Set("shortProtectionStateVersion", 1);
}
if ($trade.Get("directionalTpStateVersion") != 1) {
    $trade.tpDirection = 1;
    $trade.tpRevision = 0;
    $trade.deferredTpDirection = 1;
    $trade.deferredTpRevision = 0;
    $trade.tpCancelPending = 0;
    $trade.shortTpQty = 0;
    $trade.shortTpAvg = 0;
    $trade.shortTpDone = 0;
    $trade.shortTpInvalidLogged = 0;
    $trade.shortStopBE = 0;
    $trade.Set("directionalTpStateVersion", 1);
}
// Reuse inactive slots; DAS limits each while loop to 200 iterations.
if ($trade.listed != 1) {
    $tcSlot = 0;
    $tcFound = 0;
    while ($tcSlot < $tradeSlotCount && $tcFound == 0) {
        $tcOld = $tradeSlots.Get($tcSlot);
        if (IsObj($tcOld) && $tcOld.active == 0 && $tcOld.entryPending == 0) {
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
