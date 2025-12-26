// =====================
// RISK INIT / ACCOUNT BINDING
// Group: Session equity & PnL
// =====================
// Initializes per-account equity baseline and lock state for daily loss guard.

// ---- Step 1: Ensure ACCOUNT_STATE is set ----
if ($ACCOUNT_STATE == "") {
    // Default to sim if somehow unset
    $ACCOUNT_STATE = "sim";
}

// ---- Step 2: Resolve current account ----
if ($ACCOUNT_STATE == "sim") {
    $AccName = "%%SIMULATED%%";   // SIM
} else {
    $AccName = "%%LIVE%%";     // LIVE
}

// ---- Step 3: Get account object and keys ----
$acc = GetAccountObj($AccName);

// Key names for this account-specific snapshot / lock
$eqKey   = "DAY_EQUITY_START_" + $AccName;
$lockKey = "TRADING_LOCKED_"   + $AccName;

// ---- Step 4: Load or snapshot starting equity ----
$eqStartStr = GetVar($eqKey);
$eqStart    = $eqStartStr * 1;

// If no saved equity or invalid, snapshot from current Equity
if ($eqStartStr == "" || $eqStart <= 0) {
    $eqStart = $acc.Equity;
    SetVar($eqKey, $eqStart);
}

// ---- Step 5: Set current-session globals ----
SetVar("DAY_ACC",          $AccName);
SetVar("DAY_EQUITY_START", $eqStart);

// ---- Step 6: Load lock state ----
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
