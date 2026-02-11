// =====================
// SET BACKSTOP TRIGGER (BID < STOP - BUFFER)
// Group: Stops
// =====================
// Creates a backstop alert that fires when L1 Bid < stop - buffer, then
// executes Backstop Exit Executor for an aggressive limit sell.

// ---- Timer context ----
$timerActive = 0;
if ($timerMode == 1) { $timerActive = 1; $timerMode = 0; }

// ---- Step 1: Focus Primary_OE and load montage ----
FocusWindow Primary_OE;
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Set Backstop Trigger: montage 'Primary_OE' not found.");
    return;
}

$mySym = StrTrim("" + $M.Symb);
$posNow = $M.Pos;

if ($posNow <= 0) {
    MsgLog("Set Backstop Trigger: no long position. Aborting.");
    return;
}

// ---- Step 2: Resolve stop reference ----
$stop = 0;
$lastSym = StrTrim("" + $lastStopSymbol);
if ($lastStop > 0 && $lastSym != "" && $lastSym == $mySym) {
    $stop = $lastStop;
}

if ($stop <= 0) {
    MsgLog("Set Backstop Trigger: lastStop missing or symbol mismatch. Run Set Auto Stop first.");
    return;
}

// ---- Step 3: Compute trigger price ----
$inc = 0.01;
if ($stop < 1)    { $inc = 0.001; }
if ($stop < 0.25) { $inc = 0.0005; }

$triggerPx = $stop - $backstopBuffer;
$triggerPx = Round($triggerPx, 102, $inc);
if ($triggerPx >= $stop) {
    $triggerPx = Round($stop - $inc, 102, $inc);
}
if ($triggerPx < $inc) { $triggerPx = $inc; }

// ---- Step 4: Remove existing backstop alert(s) ----
$prevSym = StrTrim("" + $backstopSymbol);
if ($prevSym != "" && $prevSym != $mySym) {
    $oldName = "Backstop " + $prevSym;
    $oldAlert = GetAlertObj($oldName);
    if (IsObj($oldAlert)) { $oldAlert.Delete(); }
}

$alertName = "Backstop " + $mySym;
$toDel = GetAlertObj($alertName);
if (IsObj($toDel)) { $toDel.Delete(); }

// ---- Step 5: Build alert ----
$al = NewAlertObj();
$al.Name = $alertName;
$al.Symb = $mySym;
$al.AddItem("L1 Bid", "<", $triggerPx);

if ($timerActive != 1) { Wait(2000); }
$al.Script =
    "SetVar(\"BACKSTOP_SYMBOL\",\"" + $mySym + "\");" +
    "FocusWindow Primary_OE;" +
    "ExecHotkey(\"Backstop Exit Executor\");";

$al.Speak       = 0;
$al.PlaySound   = 0;
$al.AutoDelete  = 1;
$al.Loop        = 0;
$al.PopupWindow = 0;

$al.Save();

// ---- Step 6: Persist backstop state ----
$backstopArmed = 1;
$backstopSymbol = $mySym;
$backstopStop = $stop;
$backstopRetries = $backstopMaxRetries;

MsgLog("Backstop armed: sym=" + $mySym + " stop=" + $stop + " trigger=" + $triggerPx +
       " bidOffset=" + $backstopBidOffset + " retries=" + $backstopRetries);
