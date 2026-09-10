// =====================
// SET SHARE SIZE MULTIPLIER TO 0.5X
// Group: Global controls & config
// =====================
// Scales all four configured tier share sizes and the position-size cap.

$qtyMult = 0.5;
$maxPositionSize = Round($tier4ShareSize * $qtyMult, 0);
MsgLog("Share size multiplier set to 0.5x. Max position size set to " + $maxPositionSize + " shares.");
