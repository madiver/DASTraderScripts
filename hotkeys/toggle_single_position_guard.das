// =====================
// TOGGLE SINGLE-POSITION GUARD
// Group: Utilities & toggles
// =====================
// Toggles $singlePositionGuard (block multi-symbol entries).

if ($singlePositionGuard == 1) {
   $singlePositionGuard = 0;
   MsgBox("WARNING: single-position guard disabled.\nMulti-symbol trading will likely break stop/TP handling.");
} else {
   $singlePositionGuard = 1;
   MsgBox("Single-position guard enabled.");
}
