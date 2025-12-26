// ==============================
// SHOW CURRENT TRACKED PnL + LOCK STATE
// Group: Session equity & PnL
// ==============================


// ==============================
// DISPLAY PnL + LOCK STATE
// ==============================

// We already have $accName, $eqStart, $eqNow, $limit from above,
// so no need to re-read DAY_ACC/DAY_EQUITY_START a second time.

// Compute PnL
$netPnL = $eqNow - $eqStart;

// Sign for display
$sign = "";
if ($netPnL > 0) { $sign = "+"; }

// Reload lock state (in case it just changed above)
$lockedStr = GetVar($lockKey);
$locked    = ($lockedStr * 1);

// Human-readable lock state
$lockMsg = "Unlocked";
if ($locked == 1) { $lockMsg = "LOCKED (daily loss limit hit)"; }

// Display popup
MsgBox(
    "Account: "      + $accName + "\n" +
    "Start Equity: $" + $eqStart + "\n" +
    "Current Equity: $" + $eqNow + "\n" +
    "Status: "       + $lockMsg + "\n\n" +
    "PnL: "          + $sign + "$" + $netPnL + "\n" +
    "Max Loss: $"    + $maxDailyLoss
);