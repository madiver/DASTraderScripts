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

// ---- Feature Toggles ----
$msg =
"FEATURE TOGGLES\n" +
"-----------------\n" +
"useSlippageMargin: " + $useSlippageMargin + "\n" +
"slipTicksMin: " + $slipTicksMin + "\n" +
"slipSpreadFrac: " + $slipSpreadFrac + "\n" +
"acceptPartial: " + $acceptPartial + "\n" +
"minFillShares: " + $minFillShares + "\n" +
"cancelRemainderOnPartial: " + $cancelRemainderOnPartial + "\n" +
"useSpreadCheck:" + $useSpreadCheck + "\n" +
"usePerTradeRiskCap: " + $usePerTradeRiskCap + "\n\n" +

// ---- Risk & Execution ----
"RISK & EXECUTION\n" +
"-----------------\n" +
"entryOffset: $" + $entryOffset + "\n" +
"exitOffset: $" + $exitOffset + "\n" +
"stopLossTrigger (1R): $" + $stopLossTrigger + "\n" +
"dynamicStop: " + $dynamicStop + "\n" +
"dynamicStopMult: " + $dynamicStopMult + "\n" +
"dynamicStopActive: " + $dynamicStopActive + "\n" +
"dynamicStopR: $" + $dynamicStopR + "\n" +
"takeProfitFactor: " + $takeProfitFactor + "R\n" +
"takeProfitSize: " + ($takeProfitSize * 100) + "%\n\n" +

// ---- Feature Enablement ----
"FEATURE ENABLEMENT\n" +
"-----------------\n" +
"useAutoStop: " + $useAutoStop + "\n" +
"useTakeProfit: " + $useTakeProfit + "\n" +
"resetStopOnCancel: " + $resetStopOnCancel + "\n\n" +

// ---- Runtime & Timing ----
"RUNTIME & TIMING\n" +
"-----------------\n" +
"rehab: " + $rehab + "\n" +
"oneSecondScriptCnt: " + $oneSecondScriptCnt + "\n" +
"pollMs: " + $pollMs + "\n" +
"maxPolls: " + $maxPolls + "\n\n" +

// ---- Timer Arming ----
"TIMER ARMING\n" +
"-----------------\n" +
"useTimerArming: " + $useTimerArming + "\n" +
"entryPending: " + $entryPending + "\n" +
"entryStage: " + $entryStage + "\n" +
"entryTicks: " + $entryTicks + "\n" +
"entryMaxTicks: " + $entryMaxTicks + "\n" +
"entrySymbol: " + $entrySymbol + "\n" +
"entryPosBefore: " + $entryPosBefore + "\n" +
"entryAvgBefore: " + $entryAvgBefore + "\n" +
"entryScaleIn: " + $entryScaleIn + "\n" +
"entryDynR: $" + $entryDynR + "\n\n" +

// ---- Account Mode ----
"ACCOUNT MODE\n" +
"-----------------\n" +
"Account: " + $acct + "\n" +
"Mode: " + $acctMode + "\n" +
"SIM Account: " + $TRSIM + "\n" +
"LIVE Account: " + $LIVEACT + "\n\n" +

// ---- Session State ----
"SESSION STATE\n" +
"-----------------\n" +
"DAY_ACC: " + GetVar("DAY_ACC") + "\n" +
"DAY_EQUITY_START: $" + GetVar("DAY_EQUITY_START") + "\n" +
"TRADING_LOCKED: " + GetVar("TRADING_LOCKED") + "\n\n" +

// ---- Sizing & Risk Limits ----
"SIZING & RISK LIMITS\n" +
"-----------------\n" +
"qtyMult: " + $qtyMult + "\n" +
"maxPositionSize: " + $maxPositionSize + " shares\n" +
"maxRisk (per trade): $" + $riskCapDollars + "\n" +
"maxDailyLoss: $" + $maxDailyLoss + "\n";

MsgBox($msg);
