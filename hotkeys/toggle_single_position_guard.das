// =====================
// TOGGLE SINGLE-POSITION GUARD
// Group: Utilities & toggles
// =====================
// Toggles $singlePositionGuard (one automated long per account).

if ($singlePositionGuard == 1) {
   $singlePositionGuard = 0;
   MsgLog("Single-long guard disabled. Trade state remains isolated by account/symbol.");
} else {
   $singlePositionGuard = 1;
   MsgLog("Single-long guard enabled per account. Manual shorts are independent.");
}
