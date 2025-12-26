// =====================
// DISPLAY CONFIGURATION
// Group: Global controls & config
// =====================

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
"takeProfitFactor: " + $takeProfitFactor + "R\n" +
"takeProfitSize: " + ($takeProfitSize * 100) + "%\n\n" +

// ---- Feature Enablement ----
"FEATURE ENABLEMENT\n" +
"-----------------\n" +
"useAutoStop: " + $useAutoStop + "\n" +
"useTakeProfit: " + $useTakeProfit + "\n" +
"resetStopOnCancel: " + $resetStopOnCancel + "\n\n" +

// ---- Account State ----
"ACCOUNT STATE\n" +
"-----------------\n" +
"ACCOUNT_STATE: " + $ACCOUNT_STATE + "\n" +
"SIM Account: " + $TRSIM + "\n" +
"LIVE Account: " + $TRLIVE + "\n\n" +

// ---- Sizing & Risk Limits ----
"SIZING & RISK LIMITS\n" +
"-----------------\n" +
"qtyMult: " + $qtyMult + "\n" +
"maxPositionSize: " + $maxPositionSize + " shares\n" +
"maxRisk (per trade): $" + $riskCapDollars + "\n" +
"maxDailyLoss: $" + $maxDailyLoss + "\n";

MsgBox($msg);