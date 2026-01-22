// =====================
// RISK INIT / ACCOUNT BINDING
// Group: Session equity & PnL
// =====================
// Initializes per-account equity baseline and lock state for daily loss guard.

// ---- Step 1: Resolve current account ----
// Prefer explicit account set by SIM/LIVE switch hotkeys.
$AccName = $DAY_ACC;
if ($AccName == "") {
    $M = GetWindowObj("Primary_OE");
    if (IsObj($M)) {
        $AccName = StrTrim("" + $M.Account);
    }
}
if ($AccName == "") {
    $DAY_GUARD_OK = 0;
    MsgLog("Session equity init failed: no account found.");
    return;
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
    if ($eqStart <= 0) {
        $DAY_GUARD_OK = 0;
        MsgLog("Session equity init deferred: equity not ready for " + $AccName + ".");
        return;
    }
    SetVar($eqKey, $eqStart);
}

// ---- Step 5: Set current-session globals ----
$DAY_ACC = $AccName;
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
