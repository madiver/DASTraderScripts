// =====================
// GTFO (EMERGENCY EXIT)
// Group: Global controls & config
// =====================
// Cancels all orders and sends a direction-aware aggressive limit order to flatten.
// Long: Bid - 0.50. Short: Ask + 0.50. Route: $gtfoRoute.
FocusWindow Primary_OE;
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) { return; }

$mySym = StrTrim("" + $M.Symb);
if ($mySym == "") { return; }

$route = $gtfoRoute;
if ($route == "") { $route = $orderRoute; }
if ($route == "") {
    MsgLog("GTFO: no route configured for " + $mySym + ". Aborting.");
    return;
}

// Avoid canceling unrelated working orders when GTFO is pressed while flat.
// Montage .Pos is reliable for flat/non-flat; GetCurrPos() supplies direction.
$displayPos = $M.Pos;
$prePos = GetCurrPos();
if ($displayPos == 0 && $prePos == 0) { return; }

CXL ALL;
Wait(100);

// GetCurrPos() is signed; montage .Pos and built-in Pos are absolute quantities.
// Poll briefly after cancels so working protection does not hide the position.
$posNow = GetCurrPos();
$i = 0;
while ($posNow == 0 && $M.Pos != 0 && $i < 10) {
    Wait(50);
    $posNow = GetCurrPos();
    $i = $i + 1;
}
if ($posNow == 0) {
    if ($M.Pos != 0) {
        MsgLog("GTFO: unable to resolve signed position after cancels for " + $mySym + ". Aborting.");
    }
    return;
}
ROUTE=$route;
TIF=DAY+;

$direction = "LONG";
$refPx = $M.Bid;
if ($posNow < 0) {
    $direction = "SHORT";
    $refPx = $M.Ask;
}
if ($refPx <= 0) { $refPx = $M.Last; }
if ($refPx <= 0) {
    MsgLog("GTFO: no valid quote for " + $mySym + ". Aborting.");
    return;
}

$gtfoOffset = 0.50;
$px = $refPx - $gtfoOffset;
if ($posNow < 0) { $px = $refPx + $gtfoOffset; }

if ($px <= 0) {
    MsgLog("GTFO: calculated price is invalid for " + $mySym + ". Aborting.");
    return;
}

// Abort if the position changed sides while the emergency order was prepared.
$posCheck = GetCurrPos();
if ($posCheck == 0 || ($posNow > 0 && $posCheck < 0) || ($posNow < 0 && $posCheck > 0)) {
    MsgLog("GTFO: position changed while preparing exit for " + $mySym + ". Aborting.");
    return;
}

Price=$px;
// Use DAS's montage-native price rounding. Function-based Round() did not
// alter calculated prices reliably in the Open Ocean DAS build.
if ($px >= 1) { Price=Round2; }
if ($px < 1)  { Price=Round3; }
if ($px < 0.25) { Price=Round4; }
Share=Pos;
SEND=Reverse;
MsgLog("GTFO: submitted " + $direction + " full-position Reverse for " + $mySym + " at " + $px + " via " + $route + ".");

