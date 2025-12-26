// ======================
//  CANCEL ALL NON-STOP ORDERS + DELETE TP ALERTS (CURRENT SYMBOL)
// Group: Global controls & config
// ======================

// 0) Make sure we're on Primary_OE and can read it
FocusWindow Primary_OE;
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    // If we can't access Primary_OE, we can't safely infer symbol/position
    return;
}

// Snapshot symbol and position BEFORE we cancel orders
$mySym   = $M.Symb;
$posNow  = $M.Pos;

// 1) Cancel all orders for current montage symbol (this will include stops)
CXL ALLSYMB;

// 2) Delete all TP alerts for this symbol over a reasonable R range
//    This matches how the TP Alert Builder names them:
//    "TP " + <factor> + "R Partial " + <symbol>

$i = 1;
// i=1..20  → factors: 0.5, 1.0, 1.5, ..., 10.0
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