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
// Legacy diagnostic counter; the timer now processes each trade every tick.
$oneSecondScriptCnt = 0;

// Rehab mode: limit entries to MIB/IB size
$rehab = 0;

// Timer-based arming (entry hotkeys return early; timer places stop/TP)
$useTimerArming = 1;
$tradeActionDepth = 0; // recover any interrupted action when configuration is loaded
$tradeActionUntil = 0;
$timerMode = 0;         // internal flag for timer-triggered hotkeys
$entryMaxTicks = 10;    // timeout while waiting for a fill
$HIJACKED_LOCKED = 0;
$trade_ok = 1;
$testMode = 0;
// Keep open trades when LOAD CFG is pressed. New DAS sessions start empty.
if (!IsObj(GetVar("tradeStates"))) {
    $tradeStates = NewUserObj();
    $tradeSlots = NewUserObj();
    $tradeSlotCount = 0;
}
SetVar("TRADE_CONTEXT_ACCOUNT", "");
SetVar("TRADE_CONTEXT_SYMBOL", "");

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
$hijackProtection         = 0;     // 0=disabled by default; 1=enable position-size hijack protection
$applyLiveGuardsToSim     = 0;     // 1=apply live-only guards (hijack, rehab) in SIM
$singlePositionGuard      = 1;     // 1=one automated long per account; manual shorts are independent

$useAutoStop = "Yes";
$useTakeProfit = "Yes";
$resetStopOnCancel = "Yes";

// ---- 2) Risk & Execution Variables ----

// Independent signed offsets added to BID or ASK by the "plus" buy scripts.
// Presets: -0.03, -0.02, -0.01, +0.01, +0.03; defaults BID +0.01, ASK -0.01.
$entryBidOffset = 0.01;
$entryAskOffset = -0.01;

// Exit offset above/below bid/ask (depending on strategy)
// Example: 0.01 = exit 1 cent(s) below BID (or above ASK)
$exitOffset = 0.10;

// Limit order route for entries/exits (buys/sells/TP/BE). Default: ARCA1L.
$orderRoute = "ARCA1L";
// Emergency exit route (GTFO/backstop). Default: FLSH1L.
$gtfoRoute = "FLSH1L";

// Stop distance from entry, per share, in dollars (your "1R")
// Example: 0.10 = 10 cents risk per share
$stopLossTrigger = 0.20;

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

// ---- 3) Account Tokens (Simulation / Live) ----
//
// These vars store your SIM and LIVE account identifiers.
$TRSIM  = "%%SIMULATED%%"; // your SIM trading account
$LIVEACT = "%%LIVE%%";      // your LIVE trading account

// ---- 4) Sizing & Risk Limits ----

// Shared multiplier and base share sizes for each buy tier.
$qtyMult = 1.0;
$tier1ShareSize = 100;  // MIB script family
$tier2ShareSize = 200;  // IB script family
$tier3ShareSize = 300;  // Legacy buy_25_* script family
$tier4ShareSize = 500;  // Legacy buy_50_* script family

// Maximum allowed position size: one scaled Tier 4 order.
$maxPositionSize = Round($tier4ShareSize * $qtyMult, 0);

// Maximum allowed $ risk *per trade*
// Useful for guarding against oversized positions or bad spreads
$riskCapDollars = 2000.00;

// Order entry fill wait parameters
$pollMs           = 100;             // polling cadence (ms)
$maxPolls       = 20;              // 20*100ms ~= 2s
