// =====================
// TOGGLE SINGLE-POSITION GUARD
// Group: Utilities & toggles
// =====================
// Toggles $singlePositionGuard (block multi-symbol entries).

if ($singlePositionGuard == 1) {
   $singlePositionGuard = 0;
   MsgLog("WARNING: single-position guard disabled.\nMulti-symbol trading will likely break stop/TP handling.");
} else {
   $singlePositionGuard = 1;
   MsgLog("Single-position guard enabled.");
}
