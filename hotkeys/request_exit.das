// Group: Utilities & toggles
// Queue without touching the running action's trade/scratch context. No waits here.
$erKind = GetVar("EXIT_REQUEST_KIND");
$erDirection = GetVar("EXIT_REQUEST_DIRECTION") * 1;
$erFraction = GetVar("EXIT_REQUEST_FRACTION") * 1;
$erPriority = GetVar("EXIT_REQUEST_PRIORITY") * 1;
$erAccount = StrTrim("" + GetVar("EXIT_REQUEST_ACCOUNT"));
$erSymbol = StrTrim("" + GetVar("EXIT_REQUEST_SYMBOL"));
$erGeneration = GetVar("EXIT_REQUEST_GENERATION") * 1;
SetVar("EXIT_REQUEST_KIND", "");
SetVar("EXIT_REQUEST_DIRECTION", 0);
SetVar("EXIT_REQUEST_FRACTION", 0);
SetVar("EXIT_REQUEST_PRIORITY", 0);
SetVar("EXIT_REQUEST_ACCOUNT", "");
SetVar("EXIT_REQUEST_SYMBOL", "");
SetVar("EXIT_REQUEST_GENERATION", 0);
if ($erAccount == "" && $erSymbol == "") {
    $erMontage = GetWindowObj("Primary_OE");
    if (!IsObj($erMontage)) { return; }
    $erAccount = StrTrim("" + $erMontage.Account);
    $erSymbol = StrTrim("" + $erMontage.Symb);
}
if ($erAccount == "" || $erSymbol == "" || $erKind == "") { return; }
if (!IsObj(GetVar("exitRequests"))) { MsgLog("Run Set Global Variables before exiting."); return; }
if ($erFraction <= 0 || $erFraction > 1) { return; }
$erKey = $erAccount + "|" + $erSymbol;
$erExisting = $tradeStates.Get($erKey);
// DAS may evaluate every logical operand. Guard object reads in separate blocks.
$erPending = 0;
$erManaged = 0;
$erClosePriority = 0;
$erClose = 0;
if (IsObj($erExisting)) {
    if ($erExisting.Get("performanceStateVersion") == 1) { $erPending = $erExisting.exitPending; }
    if ($erExisting.Get("exitCoordinatorVersion") == 1) {
        $erManaged = $erExisting.closeManaged;
        $erClosePriority = $erExisting.closePriority;
        $erClose = $erExisting.closeRequest;
    }
}
$erIsCancel = 0;
if ($erKind == "CANCEL" || $erKind == "CANCEL_NO_STOPS") { $erIsCancel = 1; }
$erAccountObj = GetAccountObj($erAccount);
$erPosition = 0;
if (IsObj($erAccountObj)) { $erPosition = $erAccountObj.GetPosition($erSymbol); }
$erValid = 0;
$erPos = 0;
if (IsObj($erPosition)) { $erPos = $erPosition.Share; $erValid = 1; }
if ($erValid != 1) {
    $erMontage = GetWindowObj("Primary_OE");
    if (IsObj($erMontage)) {
        if ($erMontage.Account == $erAccount && $erMontage.Symb == $erSymbol) {
            $erPos = $erMontage.GetCurrPos();
            if ($erPos != 0 || $erMontage.Pos == 0) { $erValid = 1; }
        }
    }
}
if ($erValid != 1 && $erIsCancel != 1) {
    if ($erPending != 1) { MsgLog("Exit awaits reliable position data; no request sent."); return; }
    // An existing exit can accept repricing/priority changes while data recovers.
    if (IsObj($erClose)) {
        if ($erDirection == 0) { $erDirection = $erClose.direction; }
    }
}
if ($erDirection != 0 && $erPos * $erDirection < 0) {
    if ($erPending != 1) { return; }
    // Position changed sides: cancel residual orders instead of closing the new side.
    $erKind = "CANCEL_NO_STOPS";
    $erDirection = 0;
    $erFraction = 1;
    $erPriority = 60;
    $erIsCancel = 1;
}
if ($erIsCancel != 1 && $erValid == 1) {
    if ($erPos == 0 && $erPending != 1) { return; }
}
if (IsObj($erClose)) {
    if ($erManaged == 1 && $erPending == 1 && $erClosePriority > $erPriority) {
        if ($erClose.kind != "CANCEL" && $erClose.kind != "CANCEL_NO_STOPS") {
            MsgLog("Higher-priority exit remains pending for " + $erKey + "."); return;
        }
    }
}
$erQueued = $exitRequests.Get($erKey);
if (IsObj($erQueued)) {
    if ($erQueued.priority > $erPriority && $erQueued.kind != "CANCEL" && $erQueued.kind != "CANCEL_NO_STOPS") { return; }
}
$erRequest = NewUserObj();
$erRequest.account = $erAccount;
$erRequest.symbol = $erSymbol;
$erRequest.kind = $erKind;
$erRequest.direction = $erDirection;
if ($erDirection == 0) {
    $erRequest.direction = 1;
    if ($erPos < 0) { $erRequest.direction = -1; }
}
$erRequest.fraction = $erFraction;
$erRequest.priority = $erPriority;
$erRequest.generation = $erGeneration;
$erRequest.route = $orderRoute;
$erRequest.offset = $exitOffset;
if ($erKind == "EMERGENCY" || $erKind == "BACKSTOP" || $erKind == "HIJACK") {
    if ($gtfoRoute != "") { $erRequest.route = $gtfoRoute; }
}
if ($erKind == "EMERGENCY") { $erRequest.offset = 0.50; }
if ($erKind == "BACKSTOP") { $erRequest.offset = $backstopBidOffset; }
if ($erRequest.route == "" && $erIsCancel != 1) { return; }
if (!IsObj($erQueued)) {
    $erSlot = 0;
    while ($erSlot < $exitRequestCount && $exitRequestKeys.Get($erSlot) != "") { $erSlot = $erSlot + 1; }
    if ($erSlot >= 200) { MsgLog("Exit queue full; no order sent."); return; }
    if ($erSlot == $exitRequestCount) { $exitRequestCount = $exitRequestCount + 1; }
    $exitRequestKeys.Set($erSlot, $erKey);
}
$exitRequests.Set($erKey, $erRequest);
if (GetVar("tradeActionDepth") * 1 == 0) { ExecHotkey("Drain Exit Requests"); }
