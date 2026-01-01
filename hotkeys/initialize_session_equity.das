// =====================
// RISK INIT / ACCOUNT BINDING
// Group: Session equity & PnL
// =====================
// Initializes per-account equity baseline and lock state for daily loss guard.

// ---- Step 1: Resolve current account ----
$M = GetWindowObj("Primary_OE");
$acct = "";
if (IsObj($M)) { $acct = StrTrim("" + $M.Account); }

// Default to SIM if account is unknown
if (StrLen($acct) == 0 || StrFind($acct, "TR") == 0) {
    $AccName = "%%SIMULATED%%";   // SIM
} else {
    $AccName = "%%LIVE%%";        // LIVE
}

// ---- Step 2: Get account object and keys ----
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
