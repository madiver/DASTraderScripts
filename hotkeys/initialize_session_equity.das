// ==============================
// RISK INIT / ACCOUNT BINDING
// Group: Session equity & PnL
// ==============================

// Ensure ACCOUNT_STATE is set (sim/live)
if ($ACCOUNT_STATE == "") {
    // Default to sim if somehow unset
    $ACCOUNT_STATE = "sim";
}

// Resolve current account based on ACCOUNT_STATE
if ($ACCOUNT_STATE == "sim") {
    $AccName = "%%SIMULATED%%";   // SIM
} else {
    $AccName = "%%LIVE%%";     // LIVE
}

// Get current account object
$acc = GetAccountObj($AccName);

// Key names for this account-specific snapshot / lock
$eqKey   = "DAY_EQUITY_START_" + $AccName;
$lockKey = "TRADING_LOCKED_"   + $AccName;

// Try to load existing starting equity for this account
$eqStartStr = GetVar($eqKey);
$eqStart    = $eqStartStr * 1;

// If no saved equity or invalid, snapshot from current Equity
if ($eqStartStr == "" || $eqStart <= 0) {
    $eqStart = $acc.Equity;
    SetVar($eqKey, $eqStart);
}

// Set "current" globals used by Timer Event and entry guards
SetVar("DAY_ACC",          $AccName);
SetVar("DAY_EQUITY_START", $eqStart);

// Load this account's lock state (default 0 if unset)
$lockStr = GetVar($lockKey);
if ($lockStr == "") {
    $lockStr = 0;
    SetVar($lockKey, 0);
}
SetVar("TRADING_LOCKED", $lockStr);

// Optional: show info
//MsgBox("Risk init for " + $AccName +
//       "\nStart equity: " + $eqStart +
//       "\nLocked: " + $lockStr);