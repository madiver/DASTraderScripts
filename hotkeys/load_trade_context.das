// Group: Utilities & toggles
// Internal context selector. Overrides are consumed once; never changes a montage.
$tradeContextValid = 0;
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
ExecHotkey("Read Trade Position");
