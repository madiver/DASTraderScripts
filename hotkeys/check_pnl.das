// =====================
// SHOW CURRENT TRACKED PNL + LOCK STATE
// Group: Session equity & PnL
// =====================
// Assumes $accName, $eqStart, $eqNow, and $lockKey are already set.

// Compute PnL
$netPnL = $eqNow - $eqStart;

// Sign for display
$sign = "";
if ($netPnL > 0) { $sign = "+"; }

// Reload lock state
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
