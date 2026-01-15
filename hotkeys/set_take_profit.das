// =====================
// TAKE-PROFIT ALERT BUILDER (R MULTIPLE, SIZE-AWARE)
// Group: Take profit
// =====================
// Builds a TP alert from effective R, $takeProfitFactor, and $takeProfitSize.

// ---- Timer context ----
$timerActive = 0;
if ($timerMode == 1) { $timerActive = 1; $timerMode = 0; }

// ---- Step 1: Focus Primary_OE ----
FocusWindow Primary_OE;

// ---- Step 2: Load profit factor (R multiple) ----

// Effective TP distance in dollars per share
$effR = $stopLossTrigger;
if ($dynamicStop == 1 && $dynamicStopActive == 1) {
    $effR = $dynamicStopR;
}
$tpDist = $effR * $takeProfitFactor;

// ---- Step 3: Load montage context ----
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Set Take Profit: montage 'Primary_OE' not found. Aborting.");
    return;
}

$mySym = $M.Symb;
$posNow = $M.Pos;
$avgNow = $M.AvgCost;

// No position: nothing to alert.
if ($posNow == 0) { return; }

// If AvgCost still initializing, fall back to last sale
if ($avgNow <= 0) { $avgNow = $M.Last; }

// ---- Step 4: Compute the target price ----
$tpPx = $avgNow;
if ($posNow > 0) {
    // Long: take partial when price goes up by TP distance.
    $tpPx = $avgNow + $tpDist;
} else {
    // Short: take partial when price goes down by TP distance.
    $tpPx = $avgNow - $tpDist;
}

// ---- Step 5: Tick-size resolution and snapping ----
$inc = 0.01;
if ($tpPx < 1 || $avgNow < 1)       { $inc = 0.001; }
if ($tpPx < 0.25 || $avgNow < 0.25) { $inc = 0.0005; }
$tpPx = Round($tpPx, 102, $inc);

// ---- Step 6: Remove existing TP alert for this symbol/factor ----
$alertName = "TP " + $takeProfitFactor + "R Partial " + $mySym;

$toDel = GetAlertObj($alertName);
if (IsObj($toDel)) { $toDel.Delete(); }

// ---- Step 7: Build the new alert ----
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

// ---- Step 8: Script executed when the alert triggers ----
// This calls the executor hotkey that uses $takeProfitSize.
if ($timerActive != 1) { Wait(2000); }
$al.Script =
    "SetVar(\"TP_SYMBOL\",\"" + $mySym + "\");" +
    "FocusWindow Primary_OE;" +
    "ExecHotkey(\"Take Profit Executor\");";

$al.Speak       = 0;
$al.PlaySound   = 0;
$al.AutoDelete  = 1;
$al.Loop        = 0;
$al.PopupWindow = 0;

// ---- Step 9: Save and activate alert ----
$al.Save();
$takeProfitSymbol = $mySym;
