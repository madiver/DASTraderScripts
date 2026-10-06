// Group: Utilities & toggles
// Signed account position, including shares reserved by working orders.
// Output is invalid when DAS cannot provide position data; callers must fail closed.
$tradePositionValid = 0;
$posNow = 0;
$avgNow = 0;
$tradeBid = 0;
$tradeAsk = 0;
$tradeLast = 0;
if ($tradeContextValid != 1 || !IsObj($trade)) { return; }
$myAcc = $trade.account;
$mySym = $trade.symbol;
$tradeAccountObj = GetAccountObj($myAcc);
if (!IsObj($tradeAccountObj)) { return; }
$tradePositionObj = $tradeAccountObj.GetPosition($mySym);
if (IsObj($tradePositionObj)) {
    $posNow = $tradePositionObj.Share;
    $avgNow = $tradePositionObj.AvgCost;
    $tradePositionValid = 1;
}
$tradeQuoteObj = GetQuoteObj($mySym);
if (IsObj($tradeQuoteObj)) {
    $tradeBid = $tradeQuoteObj.Bid;
    $tradeAsk = $tradeQuoteObj.Ask;
    $tradeLast = $tradeQuoteObj.Last;
}
// A flat symbol may have no AccountObj position record. Confirm it only on
// a matching montage; zero available shares alone does not mean flat.
$rpIndex = 0;
while ($rpIndex < 2) {
    $rpWindow = "Primary_OE";
    if ($rpIndex == 1) { $rpWindow = "Secondary_OE"; }
    $rpMontage = GetWindowObj($rpWindow);
    if (IsObj($rpMontage)) {
        if ($rpMontage.Account == $myAcc && $rpMontage.Symb == $mySym) {
            if ($avgNow <= 0) { $avgNow = $rpMontage.AvgCost; }
            if ($tradeBid <= 0) { $tradeBid = $rpMontage.Bid; }
            if ($tradeAsk <= 0) { $tradeAsk = $rpMontage.Ask; }
            if ($tradeLast <= 0) { $tradeLast = $rpMontage.Last; }
            if ($tradePositionValid != 1) {
                $rpSigned = $rpMontage.GetCurrPos();
                if ($rpSigned != 0 || $rpMontage.Pos == 0) {
                    $posNow = $rpSigned;
                    $tradePositionValid = 1;
                }
            }
        }
    }
    $rpIndex = $rpIndex + 1;
}
