// =====================
//  TAKE-PROFIT ALERT BUILDER (FACTOR * R, SIZE-AWARE)
// Group: Take profit
//   Uses:
//     STOPLOSS_TRIGGER     -> per-share risk (1R)
//     TAKE_PROFIT_FACTOR   -> multiplier on R (e.g., 1.0 = 1R | 2.0 = 2R)
//     TAKE_PROFIT_SIZE     -> portion to take at TP (0.25, 0.50, 0.75, etc.)
// =====================

FocusWindow Primary_OE;

// -------------------------------------------------------
// 2) Load profit factor (R multiple)
// -------------------------------------------------------

// Effective TP distance in dollars per share
$tpDist = $stopLossTrigger * $takeProfitFactor;

// -------------------------------------------------------
// 3) Load current montage context (Primary_OE)
// -------------------------------------------------------
$mySym = Symbol;
$myAcc = Account;

$accObj = GetAccountObj($myAcc);
$posNow = $accObj.GetPosition($mySym).Share;
$avgNow = AvgCost;

// No position → nothing to alert
if ($posNow == 0) { return; }

// If AvgCost still initializing, fall back to last sale
if ($avgNow <= 0) { $avgNow = Last; }

// -------------------------------------------------------
// 4) Compute the target price
// -------------------------------------------------------
$tpPx = $avgNow;
if ($posNow > 0) {
    // Long → take partial when price goes UP by TP distance
    $tpPx = $avgNow + $tpDist;
} else {
    // Short → take partial when price goes DOWN by TP distance
    $tpPx = $avgNow - $tpDist;
}

// -------------------------------------------------------
// 5) Tick-size resolution + snapping
// -------------------------------------------------------
$inc = 0.01;
if ($tpPx < 1 || $avgNow < 1)       { $inc = 0.001; }
if ($tpPx < 0.25 || $avgNow < 0.25) { $inc = 0.0005; }
$tpPx = Round($tpPx, 102, $inc);

// -------------------------------------------------------
// 6) Remove existing TP alert for this symbol/factor
// -------------------------------------------------------
$alertName = "TP " + $takeProfitFactor + "R Partial " + $mySym;

$toDel = GetAlertObj($alertName);
if (IsObj($toDel)) { $toDel.Delete(); }

// -------------------------------------------------------
// 7) Build the new alert
// -------------------------------------------------------
$al = NewAlertObj();
$al.Name = $alertName;
$al.Symb = $mySym;

// Longs: wait for price to go ABOVE TP
// Shorts: wait for price to go BELOW TP
if ($posNow > 0) {
    $al.AddItem("Last Sale", ">", $tpPx);
} else {
    $al.AddItem("Last Sale", "<", $tpPx);
}

// -------------------------------------------------------
// 8) Script executed when the alert triggers
// -------------------------------------------------------
// This calls the executor hotkey that uses TAKE_PROFIT_SIZE.
wait(2000);
$al.Script =
    "SetVar(\"TP_SYMBOL\",\"" + $mySym + "\");" +
    "FocusWindow Primary_OE;" +
    "ExecHotkey(\"Take Profit Executor\");";

$al.Speak       = 0;
$al.PlaySound   = 0;
$al.AutoDelete  = 1;
$al.Loop        = 0;
$al.PopupWindow = 0;

// -------------------------------------------------------
// 9) Save / activate alert
// -------------------------------------------------------
$al.Save();
$takeProfitSymbol = $mySym;