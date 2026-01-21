// =====================
// TOGGLE SPREAD CHECK
// Group: Utilities & toggles
// =====================
// Toggles the $useSpreadCheck safety guard.

if ($useSpreadCheck == 1) {
   $useSpreadCheck = 0;
   MsgLog("WARNING: spread check disabled.");
} else {
   $useSpreadCheck = 1;
   MsgLog("Spread check enabled.");
}
