// ======================
// CANCEL ALL ORDERS + DELETE TP ALERTS (NO STOP RE-ARM)
// Group: Global controls & config
// ======================
// Cancels all orders for the current symbol and clears TP alerts without re-arming stops.

// ---- Step 1: Focus Primary_OE and read montage context ----
FocusWindow Primary_OE;
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    // If we can't access Primary_OE, we can't safely infer symbol/position
    return;
}

// ---- Step 2: Snapshot symbol and position ----
$mySym   = $M.Symb;
$posNow  = $M.Pos;

// ---- Step 3: Cancel all orders for current symbol ----
CXL ALLSYMB;

// ---- Step 4: Delete TP alerts for this symbol ----
//    This matches how the TP Alert Builder names them:
//    "TP " + <factor> + "R Partial " + <symbol>

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

// Optional: confirm
// MsgBox("Cancelled all non-stop orders and TP alerts for " + $mySym + ".");

return;
