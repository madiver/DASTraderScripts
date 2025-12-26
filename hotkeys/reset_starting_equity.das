// ==============================
// RESET RISK INIT / ACCOUNT BINDING  (with confirmation)
// Group: Session equity & PnL
// ==============================

// Ensure ACCOUNT_STATE is set (sim/live)
if ($ACCOUNT_STATE == "") {
    // Default to sim if somehow unset
    $ACCOUNT_STATE = "sim";
}

// Determine active account
if ($ACCOUNT_STATE == "sim") {
    $AccName = "%%SIMULATED%%";   // SIM
} else {
    $AccName = "%%LIVE%%";     // LIVE
}

// --- Confirmation Prompt ---
$answer = Input("Confirm Reset", 
                "Type YES to reset PnL baseline for account " + $AccName + ":");

if ($answer != "YES") {
    MsgBox("Reset aborted. (You typed: '" + $answer + "')");
    return;
}

// --- Get account info ---
$acc = GetAccountObj($AccName);

// Build per-account keys
$eqKey   = "DAY_EQUITY_START_" + $AccName;
$lockKey = "TRADING_LOCKED_"   + $AccName;

// Record new starting equity baseline
$eqStart = $acc.Equity;
SetVar($eqKey, $eqStart);

// Update "current" globals used by guard + PnL display
SetVar("DAY_ACC",          $AccName);
SetVar("DAY_EQUITY_START", $eqStart);

// Reset lock state
SetVar($lockKey,        0);
SetVar("TRADING_LOCKED", 0);

// Show result
MsgBox("Risk baseline RESET for " + $AccName +
       "\nStart equity is now: $" + $eqStart +
       "\nLock state reset to 0");