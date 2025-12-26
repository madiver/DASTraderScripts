// =====================
// GLOBAL VARIABLES
// Group: Global controls & config
// =====================
//
// IMPORTANT:
// - Do NOT change this script's name.
// - If you update any global variables, re-run this script
//   or restart DAS Trader so all globals refresh.
// - Most hotkeys assume these globals exist.
//

// Counter for the 1-second timer script (see other scripts/timer.das)
$oneSecondScriptCnt = 0;

// Rehab mode: limit entries to ice-breaker size (1/4 normal size)
$rehab = 0;

// ---- Feature Toggles ----
$useSlippageMargin         = 1;     // 1=guard stop vs bid with margin
$slipTicksMin              = 2;     // minimum ticks to add as slippage margin
$slipSpreadFrac            = 0.25;  // additional margin = spread * this fraction
$acceptPartial             = 1;     // 1=accept partial fill within window; 0=require full fill
$minFillShares             = 1;     // minimum shares to accept when $acceptPartial=1
$cancelRemainderOnPartial  = 1;     // 1=cancel remainder before arming stop on partial
$usePerTradeRiskCap        = 1;     // 1=abort if projected risk exceeds cap
$useSpreadCheck            = 1;

// ======================================================
//  1) Risk & Execution Variables
// ======================================================

// Entry offset above/below bid/ask (depending on strategy)
// Example: 0.01 = enter 1 cent(s) above BID (or below ASK)
$entryOffset = 0.03;

// Exit offset above/below bid/ask (depending on strategy)
// Example: 0.01 = exit 1 cent(s) below BID (or above ASK)
$exitOffset = 0.10;

// Stop distance from entry, per share, in dollars (your "1R")
// Example: 0.10 = 10 cents risk per share
$stopLossTrigger = 0.10;

// How many Rs ahead to place the take-profit alert
// Example: 1.0 = take profit at +1R
$takeProfitFactor = 1.0;

// Portion of your position to sell/cover when the TP alert hits
// Example: 0.50 = sell half at TP
$takeProfitSize = 0.50;

// ======================================================
//  2) Feature Toggles (Enable/Disable Components)
// ======================================================

$useAutoStop = "Yes";
$useTakeProfit = "Yes";
$resetStopOnCancel = "Yes";

// ======================================================
//  3) Account State (Simulation / Live Modes)
// ======================================================
//
// You can toggle between sim/live elsewhere using ACCOUNT_STATE.
// These vars store your SIM and LIVE account identifiers.
// If ACCOUNT_STATE is blank, we default to live here.

if ($ACCOUNT_STATE == "") {
    $ACCOUNT_STATE = "live";   // default to live if unset
    $TRSIM  = "%%SIMULATED%%"; // your SIM trading account
    $TRLIVE = "%%LIVE%%";      // your LIVE trading account
}

// ======================================================
//  4) Sizing & Risk Limits
// ======================================================

// Multiplier for position sizing
// Example: if base clip is 50 shares, qtyMult=4 -> 200 shares per entry
$qtyMult = 4;

// Maximum allowed position size (shares)
$maxPositionSize = $qtyMult * 150;

// Maximum allowed $ risk *per trade*
// Useful for guarding against oversized positions or bad spreads
$riskCapDollars = 100.00;

// Maximum allowed daily loss tracked by comparing
// start-of-session equity vs current equity
$maxDailyLoss = 100.00;

// Order entry fill wait parameters
$pollMs           = 100;             // polling cadence (ms)
$maxPolls       = 20;              // 20*100ms ~= 2s

// Initialize session equity baseline for daily-loss guard
ExecHotKey("Initialize Session Equity");
