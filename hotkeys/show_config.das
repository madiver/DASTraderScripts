// =====================
// DISPLAY CONFIGURATION
// Group: Global controls & config
// =====================
// Shows the current global configuration in a popup.

// ---- Account Mode (derived from Primary_OE) ----
$acct = "";
$acctMode = "UNKNOWN";
$M = GetWindowObj("Primary_OE");
if (IsObj($M)) {
    $acct = StrTrim("" + $M.Account);
    if (StrLen($acct) > 0) {
        if (StrFind($acct, "TR") == 0) { $acctMode = "SIM"; } else { $acctMode = "LIVE"; }
    }
}

// ---- Config Output ----
$msg =
"RUNTIME\n" +
"-----------------\n" +
"rehab: " + $rehab + "\n" +
"HIJACKED_LOCKED: " + $HIJACKED_LOCKED + "\n" +
"singlePositionSymbol: " + $singlePositionSymbol + "\n" +
"oneSecondScriptCnt: " + $oneSecondScriptCnt + "\n" +
"timerMode: " + $timerMode + "\n" +
"useTimerArming: " + $useTimerArming + "\n" +
"entryPending: " + $entryPending + "\n" +
"entryStage: " + $entryStage + "\n" +
"entryTicks: " + $entryTicks + "\n" +
"entryMaxTicks: " + $entryMaxTicks + "\n" +
"entryPosBefore: " + $entryPosBefore + "\n" +
"entryAvgBefore: " + $entryAvgBefore + "\n" +
"entryScaleIn: " + $entryScaleIn + "\n" +
"entryDynR: $" + $entryDynR + "\n" +
"entrySymbol: " + $entrySymbol + "\n" +
"tpSymbol: " + $tpSymbol + "\n" +
"entryWatch: " + $entryWatch + "\n" +
"entryLastPos: " + $entryLastPos + "\n\n" +

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
"entryOffset: $" + $entryOffset + "\n" +
"exitOffset: $" + $exitOffset + "\n" +
"stopLossTrigger (1R): $" + $stopLossTrigger + "\n" +
"takeProfitFactor: " + $takeProfitFactor + "R\n" +
"takeProfitSize: " + ($takeProfitSize * 100) + "%\n\n" +

"DYNAMIC STOP\n" +
"-----------------\n" +
"dynamicStop: " + $dynamicStop + "\n" +
"dynamicStopMult: " + $dynamicStopMult + "\n" +
"dynamicStopActive: " + $dynamicStopActive + "\n" +
"dynamicStopR: $" + $dynamicStopR + "\n\n" +

"ACCOUNTS\n" +
"-----------------\n" +
"Account: " + $acct + "\n" +
"Mode: " + $acctMode + "\n" +
"SIM Account: " + $TRSIM + "\n" +
"LIVE Account: " + $LIVEACT + "\n\n" +

"SIZING\n" +
"-----------------\n" +
"qtyMult: " + $qtyMult + "\n" +
"maxPositionSize: " + $maxPositionSize + " shares\n\n" +

"LIMITS\n" +
"-----------------\n" +
"maxRisk (per trade): $" + $riskCapDollars + "\n" +
"maxDailyLoss: $" + $maxDailyLoss + "\n\n" +

"POLLING\n" +
"-----------------\n" +
"pollMs: " + $pollMs + "\n" +
"maxPolls: " + $maxPolls + "\n\n" +

"GUARD / SESSION\n" +
"-----------------\n" +
"DAY_ACC: " + $DAY_ACC + "\n" +
"DAY_EQUITY_START: $" + GetVar("DAY_EQUITY_START") + "\n" +
"TRADING_LOCKED: " + GetVar("TRADING_LOCKED") + "\n" +
"DAY_GUARD_OK: " + $DAY_GUARD_OK + "\n";

MsgBox($msg);
