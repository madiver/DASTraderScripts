// =====================
// SHOW CURRENT TRACKED PNL + LOCK STATE
// Group: Session equity & PnL
// =====================
// Resolves session account/baseline and reads current equity.

// ---- Step 1: Resolve session account ----
$accName = $DAY_ACC;
if ($accName == "") {
    MsgBox("No session account set. Use Switch to SIM/LIVE first.");
    return;
}

// ---- Step 2: Load starting equity ----
$eqKey = "DAY_EQUITY_START_" + $accName;
$eqStartStr = GetVar($eqKey);
if ($eqStartStr == "") {
    $eqStartStr = GetVar("DAY_EQUITY_START");
}
if ($eqStartStr == "") {
    MsgBox("Starting equity not set. Use Reset Starting Equity or Set Start Equity.");
    return;
}

$eqStart = $eqStartStr * 1;
if ($eqStart <= 0) {
    MsgBox("Invalid starting equity value. Reset starting equity and try again.");
    return;
}

// ---- Step 3: Read current equity ----
$acc = GetAccountObj($accName);
$eqNow = $acc.Equity;
if ($eqNow <= 0) {
    MsgBox("Current equity unavailable for " + $accName + ".");
    return;
}

// ---- Step 4: Lock state ----
$lockKey = "TRADING_LOCKED_" + $accName;

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
