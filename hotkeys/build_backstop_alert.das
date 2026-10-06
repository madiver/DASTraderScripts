// Group: Stops
// Internal: retain per-trade retry count when re-arming.
if ($tradeContextValid != 1 || $trade.backstopStop <= 0 || $trade.backstopRetries <= 0) { return; }
ExecHotkey("Read Trade Position");
if ($tradePositionValid != 1 || $posNow <= 0) { return; }
$inc = 0.01;
if ($trade.backstopStop < 1) { $inc = 0.001; }
if ($trade.backstopStop < 0.25) { $inc = 0.0005; }
$triggerPx = Round($trade.backstopStop - $backstopBuffer, 102, $inc);
if ($triggerPx >= $trade.backstopStop) { $triggerPx = Round($trade.backstopStop - $inc, 102, $inc); }
if ($triggerPx < $inc) { $triggerPx = $inc; }
$alertName = "Backstop " + $trade.account + " " + $trade.symbol;
$toDel = GetAlertObj($alertName);
if (IsObj($toDel)) { $toDel.Delete(); }
$al = NewAlertObj();
$al.Name = $alertName;
$al.Symb = $trade.symbol;
$al.AddItem("L1 Bid", "<", $triggerPx);
$al.Script =
    "SetVar(\"BACKSTOP_ACCOUNT\",\"" + $trade.account + "\");" +
    "SetVar(\"BACKSTOP_SYMBOL\",\"" + $trade.symbol + "\");" +
    "SetVar(\"BACKSTOP_GENERATION\"," + $trade.generation + ");" +
    "ExecHotkey(\"Backstop Exit Executor\");";
$al.Speak = 0;
$al.PlaySound = 0;
$al.AutoDelete = 1;
$al.Loop = 0;
$al.PopupWindow = 0;
$al.Save();
