// =====================
// SET SHARE SIZE MULTIPLIER TO 1.0X
// Group: Global controls & config
// =====================
// Scales all four configured tier share sizes and the position-size cap.

$qtyMult = 1.0;
$maxPositionSize = Round($tier4ShareSize * $qtyMult, 0);
MsgLog("Share size multiplier set to 1.0x. Max position size set to " + $maxPositionSize + " shares.");
