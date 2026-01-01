// =====================
// RESET RISK INIT / ACCOUNT BINDING (WITH CONFIRMATION)
// Group: Session equity & PnL
// =====================
// Resets the starting equity baseline for the active account and clears lock state.

// ---- Step 1: Resolve active account ----
$M = GetWindowObj("Primary_OE");
$acct = "";
if (IsObj($M)) { $acct = StrTrim("" + $M.Account); }

// Default to SIM if account is unknown
if (StrLen($acct) == 0 || StrFind($acct, "TR") == 0) {
    $AccName = "%%SIMULATED%%";   // SIM
} else {
    $AccName = "%%LIVE%%";        // LIVE
}

// ---- Step 2: Confirm reset ----
$answer = Input("Confirm Reset", 
                "Type YES to reset PnL baseline for account " + $AccName + ":");

if ($answer != "YES") {
    MsgBox("Reset aborted. (You typed: '" + $answer + "')");
    return;
}

// ---- Step 4: Get account object and keys ----
$acc = GetAccountObj($AccName);

// Build per-account keys
$eqKey   = "DAY_EQUITY_START_" + $AccName;
$lockKey = "TRADING_LOCKED_"   + $AccName;

// ---- Step 5: Record new starting equity baseline ----
$eqStart = $acc.Equity;
SetVar($eqKey, $eqStart);

// ---- Step 6: Update current-session globals ----
SetVar("DAY_ACC",          $AccName);
SetVar("DAY_EQUITY_START", $eqStart);

// ---- Step 7: Reset lock state ----
SetVar($lockKey,        0);
SetVar("TRADING_LOCKED", 0);

// ---- Step 8: Show result ----
MsgBox("Risk baseline RESET for " + $AccName +
       "\nStart equity is now: $" + $eqStart +
       "\nLock state reset to 0");
