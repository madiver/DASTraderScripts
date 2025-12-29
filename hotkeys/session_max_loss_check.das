// =====================
// MANUAL STARTING EQUITY INPUT
// Group: Session equity & PnL
// =====================
// Prompts for a manual starting equity baseline.

// ---- Step 1: Prompt for starting equity ----
$val = Input("Enter Starting Equity", "Type your starting equity amount (e.g., 24500.31)");

// ---- Step 2: Validate input ----
if ($val == "" ) {
    MsgBox("Starting equity not set.");
    return;
}

// Convert to number
$eq = $val * 1;

// Validate numeric range
if ($eq <= 0) {
    MsgBox("Invalid equity value: " + $val + ". Must be a positive number.");
    return;
}

// ---- Step 3: Resolve current account ----
if ($ACCOUNT_STATE == "") {
    // Default to sim if somehow unset
    $ACCOUNT_STATE = "sim";
}

if ($ACCOUNT_STATE == "sim") {
    $AccName = "%%SIMULATED%%";   // SIM
} else {
    $AccName = "%%LIVE%%";     // LIVE
}

// ---- Step 4: Store baseline and reset lock ----
$eqKey   = "DAY_EQUITY_START_" + $AccName;
$lockKey = "TRADING_LOCKED_"   + $AccName;

SetVar($eqKey, $eq);
SetVar("DAY_ACC",          $AccName);
SetVar("DAY_EQUITY_START", $eq);
SetVar($lockKey,        0);
SetVar("TRADING_LOCKED", 0);

// ---- Step 5: Inform user ----
MsgBox("Manual starting equity set for " + $AccName +
       "\nStart equity: $" + $eq +
       "\nLock state reset to 0");
