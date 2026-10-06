// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// =====================
// DISPLAY CONFIGURATION
// Group: Global controls & config
// =====================
// Shows the current global configuration in a popup.

// ---- Account Mode (derived from Primary_OE) ----
$acct = "";
$acctMode = "UNKNOWN";
$diagSym = "";
$diagMontagePos = "UNAVAILABLE";
$diagBuiltInPos = "UNAVAILABLE";
$diagCurrPos = "UNAVAILABLE";
$M = GetWindowObj("Primary_OE");
if (IsObj($M)) {
    FocusWindow Primary_OE;
    $acct = StrTrim("" + $M.Account);
    $diagSym = StrTrim("" + $M.Symb);
    $diagMontagePos = $M.Pos;
    $diagBuiltInPos = Pos;
    $diagCurrPos = $M.GetCurrPos();
    if (StrLen($acct) > 0) {
        if (StrFind($acct, "TR") == 0) { $acctMode = "SIM"; } else { $acctMode = "LIVE"; }
    }
    MsgLog("Position Diagnostics: account=" + $acct + " sym=" + $diagSym + " montagePos=" + $diagMontagePos + " builtInPos=" + $diagBuiltInPos + " currPos=" + $diagCurrPos + ".");
}

ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
$diagAccountPos = "UNAVAILABLE";
if ($tradePositionValid == 1) { $diagAccountPos = $posNow; }

// ---- Test guard status ----
$testHijackActive = GetVar("TEST_HIJACK_ACTIVE") * 1;
$testSingleActive = GetVar("TEST_SINGLE_POSITION_ACTIVE") * 1;
$testPendingActive = GetVar("TEST_PENDING_ENTRY_ACTIVE") * 1;
$testMaxPosActive = GetVar("TEST_MAX_POSITION_ACTIVE") * 1;

// ---- Config Output ----
$msg =
"RUNTIME (selected account/symbol)\n" +
"-----------------\n" +
"rehab: " + $rehab + "\n" +
"HIJACKED_LOCKED: " + $HIJACKED_LOCKED + "\n" +
"trade_ok: " + $trade_ok + "\n" +
"testMode: " + $testMode + "\n" +
"oneSecondScriptCnt: " + $oneSecondScriptCnt + "\n" +
"timerMode: " + $timerMode + "\n" +
"useTimerArming: " + $useTimerArming + "\n" +
"entryPending: " + $trade.entryPending + "\n" +
"entryStage: " + $trade.entryStage + "\n" +
"entryTicks: " + $trade.entryTicks + "\n" +
"entryMaxTicks: " + $entryMaxTicks + "\n" +
"entryPosBefore: " + $trade.entryPosBefore + "\n" +
"entryAvgBefore: " + $trade.entryAvgBefore + "\n" +
"entryScaleIn: " + $trade.entryScaleIn + "\n" +
"entryWatch: " + $trade.entryWatch + "\n" +
"entryLastPos: " + $trade.entryLastPos + "\n\n" +

"TOGGLES\n" +
"-----------------\n" +
"useSlippageMargin: " + $useSlippageMargin + "\n" +
"slipTicksMin: " + $slipTicksMin + "\n" +
"slipSpreadFrac: " + $slipSpreadFrac + "\n" +
"acceptPartial: " + $acceptPartial + "\n" +
"minFillShares: " + $minFillShares + "\n" +
"cancelRemainderOnPartial: " + $cancelRemainderOnPartial + "\n" +
"useSpreadCheck:" + $useSpreadCheck + "\n" +
"pegToBid: " + $pegToBid + "\n" +
"usePerTradeRiskCap: " + $usePerTradeRiskCap + "\n" +
"hijackProtection: " + $hijackProtection + "\n" +
"applyLiveGuardsToSim: " + $applyLiveGuardsToSim + "\n" +
"singlePositionGuard: " + $singlePositionGuard + "\n" +
"useAutoStop: " + $useAutoStop + "\n" +
"useTakeProfit: " + $useTakeProfit + "\n" +
"resetStopOnCancel: " + $resetStopOnCancel + "\n\n" +

"RISK\n" +
"-----------------\n" +
"entryBidOffset: $" + $entryBidOffset + "\n" +
"entryAskOffset: $" + $entryAskOffset + "\n" +
"exitOffset: $" + $exitOffset + "\n" +
"orderRoute: " + $orderRoute + "\n" +
"gtfoRoute: " + $gtfoRoute + "\n" +
"stopLossTrigger (1R): $" + $stopLossTrigger + "\n" +
"takeProfitFactor: " + $takeProfitFactor + "R\n" +
"takeProfitSize: " + ($takeProfitSize * 100) + "% (rehab: " + ($takeProfitSizeRehab * 100) + "%)\n\n" +

"BACKSTOP\n" +
"-----------------\n" +
"backstopBuffer: $" + $backstopBuffer + "\n" +
"backstopBidOffset: $" + $backstopBidOffset + "\n" +
"backstopMaxRetries: " + $backstopMaxRetries + "\n" +
"backstopArmed: " + $trade.backstopArmed + "\n" +
"backstopRetries: " + $trade.backstopRetries + "\n" +
"backstopStop: $" + $trade.backstopStop + "\n" +
"lastStop: $" + $trade.lastStop + "\n" +

"POSITION DIAGNOSTICS\n" +
"-----------------\n" +
"Symbol: " + $diagSym + "\n" +
"Montage .Pos: " + $diagMontagePos + "\n" +
"Built-in Pos: " + $diagBuiltInPos + "\n" +
"Montage GetCurrPos(): " + $diagCurrPos + "\n" +
"Account signed shares: " + $diagAccountPos + "\n\n" +

"ACCOUNTS\n" +
"-----------------\n" +
"Account: " + $acct + "\n" +
"Mode: " + $acctMode + "\n" +
"SIM Account: " + $TRSIM + "\n" +
"LIVE Account: " + $LIVEACT + "\n\n" +

"SIZING\n" +
"-----------------\n" +
"qtyMult: " + $qtyMult + "x\n" +
"tier1ShareSize (MIB base): " + $tier1ShareSize + " shares\n" +
"tier2ShareSize (IB base): " + $tier2ShareSize + " shares\n" +
"tier3ShareSize (buy_25 base): " + $tier3ShareSize + " shares\n" +
"tier4ShareSize (buy_50 base): " + $tier4ShareSize + " shares\n" +
"maxPositionSize: " + $maxPositionSize + " shares\n\n" +

"LIMITS\n" +
"-----------------\n" +
"maxRisk (per trade): $" + $riskCapDollars + "\n\n" +

"POLLING\n" +
"-----------------\n" +
"pollMs: " + $pollMs + "\n" +
"maxPolls: " + $maxPolls + "\n\n" +

"GUARD / TEST\n" +
"-----------------\n" +
"TEST_HIJACK_OVERRIDE: " + $testHijackActive + "\n" +
"TEST_SINGLE_POSITION_OVERRIDE: " + $testSingleActive + "\n" +
"TEST_PENDING_ENTRY_OVERRIDE: " + $testPendingActive + "\n" +
"TEST_MAX_POSITION_OVERRIDE: " + $testMaxPosActive + "\n";

MsgBox($msg);

ExecHotkey("End Trade Action");
