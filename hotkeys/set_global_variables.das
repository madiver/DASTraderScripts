// =====================
// GLOBAL VARIABLES
// Group: Global controls & config
// =====================
//
// Notes:
// - Do NOT change this script's name.
// - If you update any global variables, re-run this script
//   or restart DAS Trader so all globals refresh.
// - Most hotkeys assume these globals exist.
//

// ---- 0) Runtime Counters & Modes ----
// Counter for the 1-second timer script (see other scripts/timer.das)
$oneSecondScriptCnt = 0;

// Rehab mode: limit entries to MIB/IB size
$rehab = 0;

// Timer-based arming (entry hotkeys return early; timer places stop/TP)
$useTimerArming = 1;
$timerMode = 1;         // internal flag for timer-triggered hotkeys
$entryPending = 0;
$entryStage = 0;        // 0=wait fill, 1=cancel sells, 2=send stop, 3=set TP
$entryTicks = 0;
$entryMaxTicks = 10;    // timeout in timer ticks while waiting for fill
$entryPosBefore = 0;
$entryAvgBefore = 0;
$entryScaleIn = 0;
$entryDynR = 0;
$entrySymbol = "";
$tpSymbol = "";
$entryRefPx = 0;
$lastStop = 0;
$lastStopSymbol = "";
$HIJACKED_LOCKED = 0;
$singlePositionSymbol = "";  // runtime symbol for single-position guard
$trade_ok = 1;               // runtime flag set by Check Global Guards
$testMode = 0;               // 1=skip market-dependent checks and order send
$entryWatch = 0;
$entryLastPos = 0;
$backstopArmed = 0;
$backstopRetries = 0;
$backstopStop = 0;
$backstopSymbol = "";

// ---- 1) Feature Toggles ----
$useSlippageMargin        = 1;     // 1=guard stop vs bid with margin
$slipTicksMin             = 2;     // minimum ticks to add as slippage margin
$slipSpreadFrac           = 0.25;  // additional margin = spread * this fraction
$acceptPartial            = 1;     // 1=accept partial fill within window; 0=require full fill
$minFillShares            = 1;     // minimum shares to accept when $acceptPartial=1
$cancelRemainderOnPartial = 1;     // 1=cancel remainder before arming stop on partial
$usePerTradeRiskCap       = 1;     // 1=abort if projected risk exceeds cap
$useSpreadCheck           = 1;     // 1=check spreads before allowing buy order
$pegToBid                 = 0;     // 1=use bid for BE limit sells when applicable
$hijackProtection       = 1;     // 1=enable position-size hijack protection
$applyLiveGuardsToSim     = 1;     // 1=apply live-only guards (hijack, rehab) in SIM
$singlePositionGuard      = 1;     // 1=block new entries on a different symbol (script-tracked)

$useAutoStop = "Yes";
$useTakeProfit = "Yes";
$resetStopOnCancel = "Yes";

// ---- 2) Risk & Execution Variables ----

// Entry offset above/below bid/ask (depending on strategy)
// Example: 0.01 = enter 1 cent(s) above BID (or below ASK)
$entryOffset = 0.03;

// Exit offset above/below bid/ask (depending on strategy)
// Example: 0.01 = exit 1 cent(s) below BID (or above ASK)
$exitOffset = 0.10;

// Limit order route for entries/exits (buys/sells/TP/BE). Default: ARCAL.
$orderRoute = "ARCAL";
// Emergency exit route (GTFO/backstop). Default: FLASHL.
$gtfoRoute = "FLASHL";

// Stop distance from entry, per share, in dollars (your "1R")
// Example: 0.10 = 10 cents risk per share
$stopLossTrigger = 0.10;

// Backstop trigger settings (manual catastrophic exit helper)
$backstopBuffer = 0.03;      // trigger when Bid < stop - buffer
$backstopBidOffset = 0.10;   // limit price at Bid - offset
$backstopMaxRetries = 3;     // retries if still not flat

// How many Rs ahead to place the take-profit alert
// Example: 1.0 = take profit at +1R
$takeProfitFactor = 1.0;

// Portion of your position to sell/cover when the TP alert hits
// Example: 0.50 = sell half at TP
$takeProfitSize = 0.50;
// Portion to sell/cover when rehab mode is active (LIVE; SIM if $applyLiveGuardsToSim = 1)
$takeProfitSizeRehab = 0.50;

// ---- 2b) Dynamic Stop Settings (buy_ib only) ----
// 1 = enable dynamic spread-based R for buy_ib entries, else fixed R.
$dynamicStop = 0;
// Stop mode selector: FIXED, DYNAMIC, or STRUCTURED.
$stopMode = "FIXED";
// Multiplier for spread-based R when dynamicStop is enabled.
$dynamicStopMult = 2;
// Runtime state for active dynamic trades (do not edit manually).
$dynamicStopActive = 0;
$dynamicStopR = 0;

// ---- 2c) Structured Stop Settings (1-minute, buy_ib only) ----
$structuredMaxLookback = 5;
$structuredMaxPullback = 3;
$structuredBuffer = 0.01;
$structuredMaxStop = 0.40;
$structuredMinImpulse = 0.15;
$structuredMinClearance = 0.05;
$structuredMicroTolPct = 0.25;
$structuredMicroTolMax = 0.10;
$structuredMicroExt = 0.10;

// Runtime state for structured stops (do not edit manually).
$structuredOk = 0;
$structuredReason = 0;
$structuredReasonText = "";
$structuredType = "";
$structuredStop = 0;
$structuredR = 0;
$structuredSymbol = "";

// ---- 3) Account Tokens (Simulation / Live) ----
//
// These vars store your SIM and LIVE account identifiers.
$TRSIM  = "%%SIMULATED%%"; // your SIM trading account
$LIVEACT = "%%LIVE%%";      // your LIVE trading account

// ---- 4) Sizing & Risk Limits ----

// Shared multiplier and base share sizes for each buy tier.
$qtyMult = 1.0;
$tier1ShareSize = 50;   // MIB script family
$tier2ShareSize = 100;  // IB script family
$tier3ShareSize = 200;  // Legacy buy_25_* script family
$tier4ShareSize = 300;  // Legacy buy_50_* script family

// Maximum allowed position size (shares)
$maxPositionSize = 500;

// Maximum allowed $ risk *per trade*
// Useful for guarding against oversized positions or bad spreads
$riskCapDollars = 100.00;

// Order entry fill wait parameters
$pollMs           = 100;             // polling cadence (ms)
$maxPolls       = 20;              // 20*100ms ~= 2s
