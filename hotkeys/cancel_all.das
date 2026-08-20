// ======================
// CANCEL ALL ORDERS + DELETE TP ALERTS (CURRENT SYMBOL)
// Group: Global controls & config
// ======================
// Cancels all working orders for the current symbol, then clears TP alerts.

// ---- Step 1: Focus Primary_OE and cancel all orders ----
FocusWindow Primary_OE;
CXL ALLSYMB;

// ---- Step 2: Read montage context ----
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    // If we can't access Primary_OE, we can't safely infer symbol/position
    return;
}

// Snapshot symbol and signed position after cancels. GetCurrPos() preserves
// direction, while montage .Pos and built-in Pos are absolute quantities.
$mySym = $M.Symb;
$posNow = GetCurrPos();
$i = 0;
while ($posNow == 0 && $M.Pos != 0 && $i < 10) {
    Wait(50);
    $posNow = GetCurrPos();
    $i = $i + 1;
}

// ---- Step 3: Re-arm stop if long (optional) ----
if ($posNow > 0 && $useAutoStop == "Yes" && $resetStopOnCancel == "Yes") {
    ExecHotkey("Set Auto Stop");
}
if ($posNow < 0) {
    MsgLog("Cancel All: short position detected for " + $mySym + "; long stop was not re-armed.");
}
if ($posNow == 0 && $M.Pos != 0) {
    MsgLog("Cancel All: unable to resolve signed position for " + $mySym + "; stop was not re-armed.");
}

// ---- Step 4: Delete TP alerts for this symbol ----
// This matches how the TP Alert Builder names them:
// "TP " + <factor> + "R Partial " + <symbol>

$i = 1;
// i=1..20  -> factors: 0.5, 1.0, 1.5, ..., 10.0
while ($i <= 20) {
    $f = ($i * 0.5);   // 0.5, 1, 1.5, 2, ...

    $name = "TP " + $f + "R Partial " + $mySym;

    $al = GetAlertObj($name);
    if (IsObj($al)) {
        $al.Delete();
    }

    $i = $i + 1;
}

return;
